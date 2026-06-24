<?php
require_once ROOT . 'functions/BaseController.php';

class AccountDelete extends BaseController
{
    // ── POST /driver/account/delete-request ────────────────────────────────────
    public function requestDeletion(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $driver = $this->getall('drivers', 'token = ? AND status = 1', [$token]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 401);
            return;
        }

        try {
            // Check for existing active deletion request
            $existingRequest = $this->getall(
                'driver_account_delete_requests',
                'driver_id = ? AND request_status IN ("pending", "approved")',
                [$driver['id']]
            );

            if (is_array($existingRequest)) {
                echo utilities::apiMessage(
                    'You already have an active deletion request. Status: ' . $existingRequest['request_status'],
                    409
                );
                return;
            }

            // Check for pending/active jobs/bookings
            $pendingJobs = $this->db->prepare(
                'SELECT COUNT(*) as count FROM bookings
                 WHERE driver_id = ? AND status NOT IN ("completed", "cancelled", "rejected")'
            );
            $pendingJobs->execute([$driver['id']]);
            $jobCount = (int) $pendingJobs->fetch(PDO::FETCH_ASSOC)['count'];

            if ($jobCount > 0) {
                echo utilities::apiMessage(
                    "You have $jobCount pending or active job(s). Please complete or cancel all jobs before requesting account deletion.",
                    409
                );
                return;
            }

            // Check for pending earnings/payments (unpaid completed trips)
            $pendingEarnings = $this->db->prepare(
                'SELECT COUNT(*) as count FROM bookings
                 WHERE driver_id = ? AND status = "completed" AND payment_status NOT IN ("paid", "refunded")'
            );
            $pendingEarnings->execute([$driver['id']]);
            $earningCount = (int) $pendingEarnings->fetch(PDO::FETCH_ASSOC)['count'];

            if ($earningCount > 0) {
                echo utilities::apiMessage(
                    "You have $earningCount unpaid trip(s). Please settle all pending earnings before requesting account deletion.",
                    409
                );
                return;
            }

            // Check for wallet balance/outstanding amounts
            $walletStmt = $this->db->prepare(
                'SELECT balance FROM driver_wallets WHERE driver_id = ?'
            );
            $walletStmt->execute([$driver['id']]);
            $wallet = $walletStmt->fetch(PDO::FETCH_ASSOC);

            if (is_array($wallet) && $wallet['balance'] < 0) {
                echo utilities::apiMessage(
                    'You have an outstanding balance of ₦' . abs($wallet['balance']) . '. Please settle before requesting account deletion.',
                    409
                );
                return;
            }

            // Create deletion request
            $requestId = $this->generateId();
            $reason = $this->str('deletion_reason', '');

            $stmt = $this->db->prepare(
                'INSERT INTO driver_account_delete_requests (id, driver_id, deletion_reason, request_status, created_at)
                 VALUES (?, ?, ?, "pending", NOW())'
            );
            $stmt->execute([$requestId, $driver['id'], $reason]);

            $this->logActivity('driver', $driver['id'], 'delete_request_created', ['request_id' => $requestId]);

            echo utilities::apiMessage('Account deletion request submitted. Admin will review within 24-48 hours.', 201, [
                'request_id' => $requestId,
                'status'     => 'pending',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDelete::requestDeletion - " . $e->getMessage());
            echo utilities::apiMessage('Error creating deletion request: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /driver/account/delete-request ──────────────────────────────────────
    public function getRequestStatus(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $driver = $this->getall('drivers', 'token = ? AND status = 1', [$token]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 401);
            return;
        }

        try {
            $request = $this->getall(
                'driver_account_delete_requests',
                'driver_id = ?',
                [$driver['id']]
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
            error_log("ERROR: AccountDelete::getRequestStatus - " . $e->getMessage());
            echo utilities::apiMessage('Error fetching request status: ' . $e->getMessage(), 500);
        }
    }

    // ── DELETE /driver/account/delete-request ───────────────────────────────────
    public function cancelRequest(): void
    {
        $token = $this->extractBearerToken();
        if (empty($token)) {
            echo utilities::apiMessage('Authentication required.', 401);
            return;
        }

        $driver = $this->getall('drivers', 'token = ? AND status = 1', [$token]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 401);
            return;
        }

        try {
            $request = $this->getall(
                'driver_account_delete_requests',
                'driver_id = ?',
                [$driver['id']]
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
            $stmt = $this->db->prepare('DELETE FROM driver_account_delete_requests WHERE id = ?');
            $stmt->execute([$request['id']]);

            $this->logActivity('driver', $driver['id'], 'delete_request_cancelled', ['request_id' => $request['id']]);

            echo utilities::apiMessage('Deletion request cancelled.', 200);
        } catch (Exception $e) {
            error_log("ERROR: AccountDelete::cancelRequest - " . $e->getMessage());
            echo utilities::apiMessage('Error cancelling deletion request: ' . $e->getMessage(), 500);
        }
    }
}
