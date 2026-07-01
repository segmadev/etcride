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
            echo utilities::apiMessage('This booking is already paid.', 409);
            return;
        }

        $allowedStatuses = ['accepted', 'payment_pending'];
        if ($booking['pay_mode_snapshot'] === 'pay_on_completion') {
            $allowedStatuses = ['payment_pending'];
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

        // Save pending payment record
        $payId = utilities::genID('PAY_', 10);
        $this->quick_insert('payments', [
            'id'         => $payId,
            'booking_id' => $bookingId,
            'provider'   => $provider,
            'amount'     => $amount,
            'currency'   => $this->setting('currency', 'NGN'),
            'status'     => 'pending',
            'reference'  => $ref,
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

    // ── Call Flutterwave API to generate a hosted payment link ────────────────
    private function callFlutterwaveApi(array $payload): array
    {
        $secretKey = $_ENV['FLUTTERWAVE_SECRET_KEY'] ?? $this->setting('flutterwave_secret_key', '');

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
            CURLOPT_TIMEOUT        => 15,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if (!$response) {
            return ['ok' => false, 'error' => 'Network error reaching Flutterwave.'];
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
        $secretKey = $_ENV['KORAPAY_SECRET_KEY'] ?? $this->setting('korapay_secret_key', '');

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
            CURLOPT_TIMEOUT        => 15,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if (!$response) {
            return ['ok' => false, 'error' => 'Network error reaching Korapay.'];
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

    // ── Private: build provider-specific payload ──────────────────────────────
    private function buildProviderPayload(string $provider, array $me, float $amount, string $ref, array $booking): array
    {
        $appUrl      = rtrim($_ENV['APP_URL'] ?? '', '/');
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
            return [
                'reference'       => $ref,
                'amount'          => (int)($amount * 100), // Korapay expects amount in kobo
                'currency'        => $this->setting('currency', 'NGN'),
                'description'     => 'EtcRide Trip ' . ($booking['booking_code'] ?? $booking['id']),
                'notification_url' => $webhookUrl,
                'redirect_url'    => $redirectUrl,
                'customer'        => [
                    'email' => $me['email'] ?? ($me['phone'] . '@etcride.app'),
                    'name'  => $me['name'] ?? 'Customer',
                    'phone' => $me['phone'],
                ],
                'metadata'        => [
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
