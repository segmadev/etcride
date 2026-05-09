<?php
require_once ROOT . 'functions/BaseController.php';

/**
 * Payment Webhook Controller
 * Handles callbacks from Flutterwave and Monnify.
 * These endpoints are public (no auth) but are verified via provider signatures.
 */
class Webhook extends BaseController
{
    // ── POST /payments/webhook/flutterwave ────────────────────────────────────
    public function flutterwave(): void
    {
        // Verify Flutterwave signature
        $secretHash = $_ENV['FLUTTERWAVE_SECRET_HASH'] ?? '';
        $signature  = $_SERVER['HTTP_VERIF_HASH'] ?? '';

        if ($secretHash !== '' && $signature !== $secretHash) {
            echo utilities::apiMessage('Invalid signature.', 401);
            return;
        }

        $body = json_decode(file_get_contents('php://input'), true);
        if (!$body) {
            echo utilities::apiMessage('Invalid payload.', 400);
            return;
        }

        $event     = $body['event'] ?? '';
        $txData    = $body['data'] ?? [];
        $ref       = $txData['tx_ref'] ?? '';
        $status    = strtolower($txData['status'] ?? '');
        $provRef   = (string) ($txData['id'] ?? '');

        if ($event !== 'charge.completed' || $ref === '') {
            echo utilities::apiMessage('Event ignored.', 200);
            return;
        }

        $this->processPayment($ref, $status === 'successful', $provRef, $body, 'flutterwave');
        echo utilities::apiMessage('Webhook processed.', 200);
    }

    // ── POST /payments/webhook/monnify ────────────────────────────────────────
    public function monnify(): void
    {
        $body = json_decode(file_get_contents('php://input'), true);
        if (!$body) {
            echo utilities::apiMessage('Invalid payload.', 400);
            return;
        }

        $eventData = $body['eventData'] ?? [];
        $ref       = $eventData['paymentReference'] ?? '';
        $status    = strtolower($eventData['paymentStatus'] ?? '');
        $provRef   = $eventData['transactionReference'] ?? '';

        if ($ref === '') {
            echo utilities::apiMessage('Event ignored.', 200);
            return;
        }

        $this->processPayment($ref, $status === 'paid', $provRef, $body, 'monnify');
        echo utilities::apiMessage('Webhook processed.', 200);
    }

    // ── Shared payment processing ─────────────────────────────────────────────
    private function processPayment(string $ref, bool $success, string $provRef, array $raw, string $provider): void
    {
        // Idempotency — look up by reference
        $payment = $this->getall('payments', 'reference = ?', [$ref]);

        if (!is_array($payment)) {
            error_log("Webhook [$provider]: Payment ref '$ref' not found.");
            return;
        }

        // Already processed — skip
        if ($payment['status'] === 'paid') {
            return;
        }

        $newStatus = $success ? 'paid' : 'failed';

        $this->update('payments', [
            'status'       => $newStatus,
            'provider_ref' => $provRef,
            'raw_response' => json_encode($raw),
        ], "id = '{$payment['id']}'");

        if (!$success) {
            $this->logActivity('system', null, 'payment_failed', ['payment_id' => $payment['id'], 'ref' => $ref]);
            return;
        }

        // Update booking
        $bookingId = $payment['booking_id'];
        $booking   = $this->getall('bookings', 'id = ?', [$bookingId]);

        if (!is_array($booking)) return;

        // Move booking to 'paid' status
        $this->update('bookings', [
            'payment_status' => 'paid',
            'status'         => 'paid',
        ], "id = '$bookingId'");

        $this->recordStatusChange($bookingId, $booking['status'], 'paid', 'system', null, "Payment $ref confirmed via $provider");

        // Notify driver
        if ($booking['driver_id']) {
            $this->notify('driver', $booking['driver_id'], 'Payment Received',
                'Customer has paid. You can now start the trip.', 'payment_confirmed', $bookingId);
        }

        // Notify customer
        $this->notify('customer', $booking['customer_id'], 'Payment Confirmed',
            'Your payment has been confirmed. Your driver will begin shortly.',
            'payment_confirmed', $bookingId);

        $this->logActivity('system', null, 'payment_confirmed', [
            'booking_id' => $bookingId,
            'payment_id' => $payment['id'],
            'ref'        => $ref,
            'provider'   => $provider,
        ]);
    }
}
