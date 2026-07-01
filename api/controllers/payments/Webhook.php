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

    // ── POST /payments/webhook/korapay ────────────────────────────────────────
    public function korapay(): void
    {
        // Verify Korapay signature
        $webhookSecret = $_ENV['KORAPAY_WEBHOOK_SECRET'] ?? $this->setting('korapay_webhook_secret', '');
        $signature = $_SERVER['HTTP_X_KORAPAY_SIGNATURE'] ?? '';

        $body = file_get_contents('php://input');
        if (!$body) {
            echo utilities::apiMessage('Invalid payload.', 400);
            return;
        }

        // Verify signature if configured
        if (!empty($webhookSecret)) {
            $hash = hash_hmac('sha256', $body, $webhookSecret);
            if ($hash !== $signature) {
                echo utilities::apiMessage('Invalid signature.', 401);
                return;
            }
        }

        $bodyData = json_decode($body, true);
        if (!$bodyData) {
            echo utilities::apiMessage('Invalid JSON payload.', 400);
            return;
        }

        $data       = $bodyData['data'] ?? [];
        $ref        = $data['reference'] ?? '';
        $status     = strtolower($data['status'] ?? '');
        $provRef    = $data['id'] ?? '';

        if ($ref === '') {
            echo utilities::apiMessage('Event ignored.', 200);
            return;
        }

        $this->processPayment($ref, $status === 'success', (string)$provRef, $bodyData, 'korapay');
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

    // ── GET /payments/callback — Flutterwave redirect after hosted checkout ──────
    // Flutterwave sends: ?status=successful|cancelled|failed&tx_ref=...&transaction_id=...
    public function callback(): void
    {
        $status        = $_GET['status']         ?? 'unknown';
        $txRef         = htmlspecialchars($_GET['tx_ref']         ?? '', ENT_QUOTES, 'UTF-8');
        $transactionId = htmlspecialchars($_GET['transaction_id'] ?? '', ENT_QUOTES, 'UTF-8');
        $bookingId     = htmlspecialchars($_GET['booking_id']     ?? '', ENT_QUOTES, 'UTF-8');

        $success = $status === 'successful';
        $icon    = $success ? '✅' : '❌';
        $heading = $success ? 'Payment Successful' : 'Payment ' . ucfirst($status);
        $msg     = $success
            ? 'Your payment has been confirmed. Please return to the app.'
            : 'Your payment was not completed. Please return to the app and try again.';

        header('Content-Type: text/html; charset=UTF-8');
        echo <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment {$heading}</title>
  <style>
    body { font-family: -apple-system, sans-serif; display: flex; align-items: center;
           justify-content: center; min-height: 100vh; margin: 0; background: #f5f5f5; }
    .card { background: #fff; border-radius: 20px; padding: 40px 32px; text-align: center;
            max-width: 380px; box-shadow: 0 4px 24px rgba(0,0,0,.10); }
    .icon { font-size: 56px; margin-bottom: 16px; }
    h1   { font-size: 22px; margin: 0 0 8px; color: #1a1a1a; }
    p    { color: #666; font-size: 15px; line-height: 1.5; margin: 0 0 24px; }
    .ref { font-size: 12px; color: #999; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">{$icon}</div>
    <h1>{$heading}</h1>
    <p>{$msg}</p>
    <div class="ref">Ref: {$txRef}</div>
  </div>
</body>
</html>
HTML;
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
