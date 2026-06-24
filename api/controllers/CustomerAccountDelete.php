<?php
require_once ROOT . 'functions/BaseController.php';

class CustomerAccountDelete extends BaseController
{
    // ── POST /account/delete-request (customer) ────────────────────────────────
    public function requestDeletion(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $user = $this->getall('users', 'token = ? AND status = 1', [$token]);
        if (!is_array($user)) {
            echo utilities::apiMessage('User not found or inactive.', 401);
            return;
        }

        try {
            // Check for existing active deletion request
            $existingRequest = $this->getall(
                'customer_account_delete_requests',
                'customer_id = ? AND request_status IN ("pending", "approved")',
                [$user['id']]
            );

            if (is_array($existingRequest)) {
                echo utilities::apiMessage(
                    'You already have an active deletion request. Status: ' . $existingRequest['request_status'],
                    409
                );
                return;
            }

            // Check for pending/active bookings
            $pendingBookings = $this->db->prepare(
                'SELECT COUNT(*) as count FROM bookings
                 WHERE customer_id = ? AND status NOT IN ("completed", "cancelled", "rejected")'
            );
            $pendingBookings->execute([$user['id']]);
            $bookingCount = (int) $pendingBookings->fetch(PDO::FETCH_ASSOC)['count'];

            if ($bookingCount > 0) {
                echo utilities::apiMessage(
                    "You have $bookingCount pending or active booking(s). Please complete or cancel all bookings before requesting account deletion.",
                    409
                );
                return;
            }

            // Check for pending payments (unpaid bookings)
            $pendingPayments = $this->db->prepare(
                'SELECT COUNT(*) as count FROM bookings
                 WHERE customer_id = ? AND status = "completed" AND payment_status NOT IN ("paid", "refunded")'
            );
            $pendingPayments->execute([$user['id']]);
            $paymentCount = (int) $pendingPayments->fetch(PDO::FETCH_ASSOC)['count'];

            if ($paymentCount > 0) {
                echo utilities::apiMessage(
                    "You have $paymentCount unpaid booking(s). Please settle all payments before requesting account deletion.",
                    409
                );
                return;
            }

            // Create deletion request
            $requestId = $this->generateId();
            $reason = $this->str('deletion_reason', '');

            $stmt = $this->db->prepare(
                'INSERT INTO customer_account_delete_requests (id, customer_id, deletion_reason, request_status, created_at)
                 VALUES (?, ?, ?, "pending", NOW())'
            );
            $stmt->execute([$requestId, $user['id'], $reason]);

            $this->logActivity('customer', $user['id'], 'delete_request_created', ['request_id' => $requestId]);

            echo utilities::apiMessage('Account deletion request submitted. Admin will review within 24-48 hours.', 201, [
                'request_id' => $requestId,
                'status'     => 'pending',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: CustomerAccountDelete::requestDeletion - " . $e->getMessage());
            echo utilities::apiMessage('Error creating deletion request: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /account/delete-request (customer) ─────────────────────────────────
    public function getRequestStatus(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $user = $this->getall('users', 'token = ? AND status = 1', [$token]);
        if (!is_array($user)) {
            echo utilities::apiMessage('User not found or inactive.', 401);
            return;
        }

        try {
            $request = $this->getall(
                'customer_account_delete_requests',
                'customer_id = ?',
                [$user['id']]
            );

            if (!is_array($request)) {
                echo utilities::apiMessage('No deletion request found.', 404);
                return;
            }

            echo utilities::apiMessage('Deletion request retrieved', 200, [
                'id'              => $request['id'],
                'status'          => $request['request_status'],
                'reason'          => $request['deletion_reason'],
                'created_at'      => $request['created_at'],
                'reviewed_at'     => $request['reviewed_at'],
                'admin_notes'     => $request['admin_notes'],
                'deleted_at'      => $request['deleted_at'],
            ]);
        } catch (Exception $e) {
            error_log("ERROR: CustomerAccountDelete::getRequestStatus - " . $e->getMessage());
            echo utilities::apiMessage('Error fetching request status: ' . $e->getMessage(), 500);
        }
    }

    // ── DELETE /account/delete-request (customer) ──────────────────────────────
    public function cancelRequest(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $user = $this->getall('users', 'token = ? AND status = 1', [$token]);
        if (!is_array($user)) {
            echo utilities::apiMessage('User not found or inactive.', 401);
            return;
        }

        try {
            $request = $this->getall(
                'customer_account_delete_requests',
                'customer_id = ?',
                [$user['id']]
            );

            if (!is_array($request)) {
                echo utilities::apiMessage('No deletion request found.', 404);
                return;
            }

            if ($request['request_status'] !== 'pending') {
                echo utilities::apiMessage(
                    'Cannot cancel a ' . $request['request_status'] . ' deletion request.',
                    409
                );
                return;
            }

            // Delete the request
            $stmt = $this->db->prepare('DELETE FROM customer_account_delete_requests WHERE id = ?');
            $stmt->execute([$request['id']]);

            $this->logActivity('customer', $user['id'], 'delete_request_cancelled', ['request_id' => $request['id']]);

            echo utilities::apiMessage('Deletion request cancelled.', 200);
        } catch (Exception $e) {
            error_log("ERROR: CustomerAccountDelete::cancelRequest - " . $e->getMessage());
            echo utilities::apiMessage('Error cancelling deletion request: ' . $e->getMessage(), 500);
        }
    }
}
