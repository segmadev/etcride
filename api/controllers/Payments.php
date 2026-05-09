<?php
require_once ROOT . 'functions/BaseController.php';

class Payments extends BaseController
{
    // ── POST /bookings/:id/pay ────────────────────────────────────────────────
    public function initiate(string $bookingId): void
    {
        $me      = BaseController::$authUser;
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
        $provider = $this->setting('payment_provider', 'flutterwave');
        $ref      = 'ETCRIDE_' . strtoupper(utilities::genID('', 10)) . '_' . time();

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

        // Build provider payload
        $payload = $this->buildProviderPayload($provider, $me, $amount, $ref, $booking);

        $this->logActivity('customer', $me['id'], 'payment_initiated', [
            'booking_id' => $bookingId,
            'reference'  => $ref,
            'provider'   => $provider,
        ]);

        echo utilities::apiMessage('Payment initiated.', 200, [
            'payment_id' => $payId,
            'reference'  => $ref,
            'amount'     => $amount,
            'currency'   => $this->setting('currency', 'NGN'),
            'provider'   => $provider,
            'payload'    => $payload,
        ]);
    }

    // ── GET /bookings/:id/payment-status ──────────────────────────────────────
    public function status(string $bookingId): void
    {
        $me      = BaseController::$authUser;
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
        $callbackUrl = rtrim($_ENV['APP_URL'] ?? '', '/') . '/api/payments/webhook/' . $provider;

        if ($provider === 'flutterwave') {
            return [
                'tx_ref'          => $ref,
                'amount'          => $amount,
                'currency'        => $this->setting('currency', 'NGN'),
                'redirect_url'    => $callbackUrl,
                'customer'        => [
                    'email'       => $me['email'] ?? '',
                    'phonenumber' => $me['phone'],
                    'name'        => $me['name'],
                ],
                'customizations'  => [
                    'title' => $this->setting('app_name', 'EtcRide') . ' Booking Payment',
                ],
                'meta'            => ['booking_id' => $booking['id']],
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
                'redirectUrl'         => $callbackUrl,
                'paymentMethods'      => ['CARD', 'ACCOUNT_TRANSFER'],
            ];
        }

        return [];
    }
}
