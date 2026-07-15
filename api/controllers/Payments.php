<?php
require_once ROOT . 'functions/BaseController.php';

class Payments extends BaseController
{
    private function normalizeId(string $id): string
    {
        return strlen($id) > 20 ? substr($id, 0, 20) : $id;
    }

    // ── POST /bookings/:id/pay ────────────────────────────────────────────────
    public function initiate(string $bookingId): void
    {
        $me      = BaseController::$authUser;
        $bookingId = $this->normalizeId($bookingId);
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$bookingId, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if ($booking['payment_status'] === 'paid') {
            echo utilities::apiMessage('This booking is already paid.', 200, ['already_paid' => true]);
            return;
        }

        // Check for an existing pending payment — avoid double-charging.
        $existing = $this->getall('payments', "booking_id = ? AND status = 'pending' ORDER BY created_at DESC LIMIT 1", [$bookingId]);
        if (is_array($existing)) {
            // Verify live with the provider to see if payment actually went through.
            $verified = $this->verifyWithProvider($existing['provider'], $existing['reference']);
            if ($verified['paid']) {
                // Provider confirms paid but webhook hadn't updated us yet — do it now.
                require_once ROOT . 'api/controllers/payments/Webhook.php';
                (new Webhook())->processPaymentPublic($existing['reference'], true, $verified['provider_ref'], $verified['raw'], $existing['provider']);
                echo utilities::apiMessage('Payment already confirmed.', 200, ['already_paid' => true]);
                return;
            }
            // Still genuinely pending — return the original checkout URL so the user
            // can resume the same payment session without being charged again.
            echo utilities::apiMessage('Payment already initiated.', 200, [
                'already_paid'    => false,
                'resume_pending'  => true,
                'payment_id'      => $existing['id'],
                'reference'       => $existing['reference'],
                'provider'        => $existing['provider'],
                'payment_link'    => $existing['checkout_url'] ?? null,
                'amount'          => (float) $existing['amount'],
                'currency'        => $this->setting('currency', 'NGN'),
            ]);
            return;
        }

        // delivery non-cash: driver arrives → status stays 'arrived' until our
        // backend fix propagates; also allow 'arrived' for delivery bookings.
        $isDelivery = ($booking['booking_type'] ?? '') === 'delivery';
        $allowedStatuses = ['accepted', 'payment_pending'];
        if ($isDelivery) {
            $allowedStatuses[] = 'arrived'; // pre-pickup payment for delivery
        }
        if ($booking['pay_mode_snapshot'] === 'pay_on_completion') {
            $allowedStatuses = $isDelivery ? ['payment_pending', 'arrived'] : ['payment_pending'];
        }

        if (!in_array($booking['status'], $allowedStatuses)) {
            echo utilities::apiMessage(
                "Payment cannot be initiated in '{$booking['status']}' status.",
                409
            );
            return;
        }

        $amount   = (float) ($booking['final_fare'] ?? $booking['estimated_fare']);
        // Allow customer to specify provider, otherwise use default
        $provider = $this->str('provider') ?: $this->setting('payment_provider', 'flutterwave');
        $ref      = 'ETCRIDE_' . strtoupper(utilities::genID('', 10)) . '_' . time();

        // Validate provider is enabled
        $gatewayConfig = $this->getall('payment_gateways', 'name = ? AND is_enabled = 1', [$provider]);
        if (!is_array($gatewayConfig)) {
            echo utilities::apiMessage('Selected payment gateway is not available.', 422);
            return;
        }

        // Validate amount is within gateway limits
        if ($amount < $gatewayConfig['min_amount'] || $amount > $gatewayConfig['max_amount']) {
            echo utilities::apiMessage(
                "Amount must be between {$gatewayConfig['min_amount']} and {$gatewayConfig['max_amount']} for this gateway.",
                422
            );
            return;
        }

        // Save pending payment record (checkout_url filled in after link is obtained below)
        $payId = utilities::genID('PAY_', 10);
        $this->quick_insert('payments', [
            'id'          => $payId,
            'booking_id'  => $bookingId,
            'provider'    => $provider,
            'amount'      => $amount,
            'currency'    => $this->setting('currency', 'NGN'),
            'status'      => 'pending',
            'reference'   => $ref,
            'checkout_url'=> null,
        ]);

        // Update booking payment status
        $this->update('bookings', ['payment_status' => 'pending'], "id = '$bookingId'");

        // Build provider payload and get payment link
        $payload     = $this->buildProviderPayload($provider, $me, $amount, $ref, $booking);
        $paymentLink = null;
        $linkError   = null;

        if ($provider === 'flutterwave') {
            $result = $this->callFlutterwaveApi($payload);
            if ($result['ok']) {
                $paymentLink = $result['link'];
            } else {
                $linkError = $result['error'];
            }
        } elseif ($provider === 'korapay') {
            $result = $this->callKorapayApi($payload);
            if ($result['ok']) {
                $paymentLink = $result['link'];
            } else {
                $linkError = $result['error'];
            }
        }

        // Persist checkout URL so pending-payment resumption can return it without re-charging.
        if ($paymentLink) {
            $this->update('payments', ['checkout_url' => $paymentLink], "id = '$payId'");
        }

        $this->logActivity('customer', $me['id'], 'payment_initiated', [
            'booking_id' => $bookingId,
            'reference'  => $ref,
            'provider'   => $provider,
        ]);

        echo utilities::apiMessage('Payment initiated.', 200, [
            'payment_id'   => $payId,
            'reference'    => $ref,
            'amount'       => $amount,
            'currency'     => $this->setting('currency', 'NGN'),
            'provider'     => $provider,
            'payment_link' => $paymentLink,
            'link_error'   => $linkError,
            'payload'      => $payload,
        ]);
    }

    // ── Resolve secret key: payment_gateways table → .env → settings ────────
    private function gatewaySecretKey(string $name): string
    {
        $row = $this->getall('payment_gateways', 'name = ? AND is_enabled = 1', [$name], 'secret_key');
        if (is_array($row) && !empty($row['secret_key'])) {
            return $row['secret_key'];
        }
        // Fallback to .env / settings table
        $envKey = strtoupper($name) . '_SECRET_KEY';
        return $_ENV[$envKey] ?? $this->setting(strtolower($name) . '_secret_key', '');
    }

    // ── Call Flutterwave API to generate a hosted payment link ────────────────
    private function callFlutterwaveApi(array $payload): array
    {
        $secretKey = $this->gatewaySecretKey('flutterwave');

        if (empty($secretKey)) {
            return ['ok' => false, 'error' => 'Flutterwave secret key not configured.'];
        }

        $ch = curl_init('https://api.flutterwave.com/v3/payments');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $secretKey,
                'Content-Type: application/json',
            ],
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);

        $response = curl_exec($ch);
        $curlErr  = curl_error($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if (!$response) {
            return ['ok' => false, 'error' => 'Network error reaching Flutterwave: ' . $curlErr];
        }

        $data = json_decode($response, true);
        if ($httpCode === 200 && ($data['status'] ?? '') === 'success' && !empty($data['data']['link'])) {
            return ['ok' => true, 'link' => $data['data']['link']];
        }

        $msg = $data['message'] ?? 'Flutterwave error (HTTP ' . $httpCode . ')';
        return ['ok' => false, 'error' => $msg];
    }

    // ── Call Korapay API to generate a hosted payment link ─────────────────────
    private function callKorapayApi(array $payload): array
    {
        $secretKey = $this->gatewaySecretKey('korapay');

        if (empty($secretKey)) {
            return ['ok' => false, 'error' => 'Korapay secret key not configured.'];
        }

        $ch = curl_init('https://api.korapay.com/merchant/api/v1/charges/initialize');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $secretKey,
                'Content-Type: application/json',
            ],
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);

        $response = curl_exec($ch);
        $curlErr  = curl_error($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if (!$response) {
            return ['ok' => false, 'error' => 'Network error reaching Korapay: ' . $curlErr];
        }

        $data = json_decode($response, true);
        if ($httpCode === 200 && ($data['status'] ?? false) === true && !empty($data['data']['checkout_url'])) {
            return ['ok' => true, 'link' => $data['data']['checkout_url']];
        }

        $msg = $data['message'] ?? ($data['data']['message'] ?? 'Korapay error (HTTP ' . $httpCode . ')');
        return ['ok' => false, 'error' => $msg];
    }

    // ── GET /bookings/:id/payment-status ──────────────────────────────────────
    public function status(string $bookingId): void
    {
        $me      = BaseController::$authUser;
        $bookingId = $this->normalizeId($bookingId);
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$bookingId, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        $payment = $this->getall('payments', 'booking_id = ? ORDER BY created_at DESC LIMIT 1', [$bookingId]);

        echo utilities::apiMessage('Payment status retrieved.', 200, [
            'booking_id'     => $bookingId,
            'payment_status' => $booking['payment_status'],
            'payment'        => is_array($payment) ? [
                'id'           => $payment['id'],
                'reference'    => $payment['reference'],
                'provider_ref' => $payment['provider_ref'],
                'status'       => $payment['status'],
                'amount'       => $payment['amount'],
                'provider'     => $payment['provider'],
            ] : null,
        ]);
    }

    // ── POST /bookings/:id/pay/sync — force-check live payment status ─────────
    public function sync(string $bookingId): void
    {
        $me        = BaseController::$authUser;
        $bookingId = $this->normalizeId($bookingId);
        $booking   = $this->getall('bookings', 'id = ? AND customer_id = ?', [$bookingId, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if ($booking['payment_status'] === 'paid') {
            echo utilities::apiMessage('Already paid.', 200, ['payment_status' => 'paid', 'was_updated' => false]);
            return;
        }

        $payment = $this->getall('payments', "booking_id = ? AND status = 'pending' ORDER BY created_at DESC LIMIT 1", [$bookingId]);
        if (!is_array($payment)) {
            echo utilities::apiMessage('No pending payment found.', 404);
            return;
        }

        $verified = $this->verifyWithProvider($payment['provider'], $payment['reference']);

        if ($verified['paid']) {
            require_once ROOT . 'api/controllers/payments/Webhook.php';
            (new Webhook())->processPaymentPublic($payment['reference'], true, $verified['provider_ref'], $verified['raw'], $payment['provider']);
            echo utilities::apiMessage('Payment confirmed.', 200, ['payment_status' => 'paid', 'was_updated' => true]);
            return;
        }

        if ($verified['failed']) {
            $this->update('payments', ['status' => 'failed'], "id = '{$payment['id']}'");
            echo utilities::apiMessage('Payment failed.', 200, ['payment_status' => 'failed', 'was_updated' => true]);
            return;
        }

        echo utilities::apiMessage('Payment still pending.', 200, [
            'payment_status' => 'pending',
            'was_updated'    => false,
            'checkout_url'   => $payment['checkout_url'],
        ]);
    }

    // ── Shared: call provider verify API by reference ─────────────────────────
    // Returns ['paid'=>bool, 'failed'=>bool, 'provider_ref'=>string, 'raw'=>array]
    private function verifyWithProvider(string $provider, string $ref): array
    {
        $default = ['paid' => false, 'failed' => false, 'provider_ref' => '', 'raw' => []];

        if ($provider === 'korapay') {
            $secretKey = $this->gatewaySecretKey('korapay');
            if (empty($secretKey)) return $default;

            $ch = curl_init('https://api.korapay.com/merchant/api/v1/charges/' . urlencode($ref));
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER     => ['Authorization: Bearer ' . $secretKey],
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_SSL_VERIFYHOST => 2,
            ]);
            $resp = curl_exec($ch);
            curl_close($ch);

            if (!$resp) return $default;
            $data   = json_decode($resp, true) ?? [];
            $status = strtolower($data['data']['status'] ?? '');
            return [
                'paid'         => $status === 'success',
                'failed'       => in_array($status, ['failed', 'expired'], true),
                'provider_ref' => (string) ($data['data']['reference'] ?? $ref),
                'raw'          => $data['data'] ?? [],
            ];
        }

        if ($provider === 'flutterwave') {
            $secretKey = $this->gatewaySecretKey('flutterwave');
            if (empty($secretKey)) return $default;

            $ch = curl_init('https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=' . urlencode($ref));
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER     => ['Authorization: Bearer ' . $secretKey],
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_SSL_VERIFYHOST => 2,
            ]);
            $resp = curl_exec($ch);
            curl_close($ch);

            if (!$resp) return $default;
            $data   = json_decode($resp, true) ?? [];
            $status = strtolower($data['data']['status'] ?? '');
            return [
                'paid'         => $status === 'successful',
                'failed'       => in_array($status, ['failed', 'cancelled'], true),
                'provider_ref' => (string) ($data['data']['id'] ?? ''),
                'raw'          => $data['data'] ?? [],
            ];
        }

        return $default;
    }

    // ── Private: build provider-specific payload ──────────────────────────────
    private function buildProviderPayload(string $provider, array $me, float $amount, string $ref, array $booking): array
    {
        // Prefer explicit APP_URL from .env; fall back to the actual request origin
        // so localhost dev and production both produce correct webhook/redirect URLs.
        $envUrl = $_ENV['APP_URL'] ?? '';
        if (empty($envUrl) || str_contains($envUrl, 'localhost')) {
            $scheme  = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $host    = $_SERVER['HTTP_HOST'] ?? 'localhost';
            $envUrl  = $scheme . '://' . $host;
        }
        $appUrl = rtrim($envUrl, '/');
        $webhookUrl  = $appUrl . '/api/payments/webhook/' . $provider;
        // Redirect URL returns user to a payment-callback page that the Flutter web app handles
        $redirectUrl = $appUrl . '/api/payments/callback?tx_ref=' . urlencode($ref) . '&booking_id=' . urlencode($booking['id']);

        if ($provider === 'flutterwave') {
            return [
                'tx_ref'          => $ref,
                'amount'          => $amount,
                'currency'        => $this->setting('currency', 'NGN'),
                'redirect_url'    => $redirectUrl,
                'customer'        => [
                    'email'       => $me['email'] ?? ($me['phone'] . '@etcride.app'),
                    'phonenumber' => $me['phone'],
                    'name'        => $me['name'] ?? 'Customer',
                ],
                'customizations'  => [
                    'title'       => $this->setting('app_name', 'EtcRide') . ' Payment',
                    'description' => 'Trip ' . ($booking['booking_code'] ?? $booking['id']),
                    'logo'        => $appUrl . '/assets/logos/logo.png',
                ],
                'meta'            => ['booking_id' => $booking['id']],
            ];
        }

        if ($provider === 'korapay') {
            // Korapay charges/initialize only accepts email + name in customer object.
            // Amount must be in kobo (naira × 100). Phone field is not accepted.
            $email = !empty($me['email'])
                ? $me['email']
                : preg_replace('/[^0-9]/', '', $me['phone']) . '@etcride.app';
            return [
                'reference'        => $ref,
                'amount'           => round($amount), // naira (Korapay accepts naira, not kobo)
                'currency'         => $this->setting('currency', 'NGN'),
                'notification_url' => $webhookUrl,
                'redirect_url'     => $redirectUrl,
                'customer'         => [
                    'email' => $email,
                    'name'  => $me['name'] ?? 'Customer',
                ],
                'metadata'         => [
                    'booking_id'  => $booking['id'],
                    'customer_id' => $me['id'],
                ],
            ];
        }

        if ($provider === 'monnify') {
            return [
                'amount'              => $amount,
                'customerName'        => $me['name'],
                'customerEmail'       => $me['email'] ?? '',
                'paymentReference'    => $ref,
                'paymentDescription'  => 'EtcRide Booking ' . $booking['booking_code'],
                'currencyCode'        => $this->setting('currency', 'NGN'),
                'contractCode'        => $_ENV['MONNIFY_CONTRACT_CODE'] ?? '',
                'redirectUrl'         => $redirectUrl,
                'paymentMethods'      => ['CARD', 'ACCOUNT_TRANSFER'],
            ];
        }

        return [];
    }
}
