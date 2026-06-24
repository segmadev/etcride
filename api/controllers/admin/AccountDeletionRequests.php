<?php
require_once ROOT . 'functions/BaseController.php';

class AccountDeletionRequests extends BaseController
{
    // ── GET /admin/account-deletion-requests ───────────────────────────────────
    public function index(): void
    {
        $me = BaseController::$authAdmin;
        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $type = $this->str('type', 'customer'); // customer or driver
            $status = $this->str('status', ''); // pending, approved, rejected, or empty for all
            $search = $this->str('search', ''); // search by name or email

            if ($type === 'customer') {
                $where = '1=1';
                $params = [];

                if (!empty($status)) {
                    $where .= ' AND cadr.request_status = ?';
                    $params[] = $status;
                } else {
                    // By default, show pending first
                    $where .= ' AND cadr.request_status = "pending"';
                }

                if (!empty($search)) {
                    $search = '%' . $search . '%';
                    $where .= ' AND (u.name LIKE ? OR u.email LIKE ?)';
                    $params[] = $search;
                    $params[] = $search;
                }

                $query = "
                    SELECT
                        cadr.id, cadr.customer_id, cadr.deletion_reason, cadr.request_status,
                        cadr.reviewed_by, cadr.admin_notes, cadr.reviewed_at, cadr.deleted_at, cadr.created_at,
                        u.name, u.email, u.phone
                    FROM customer_account_delete_requests cadr
                    LEFT JOIN users u ON cadr.customer_id = u.id
                    WHERE $where
                    ORDER BY cadr.created_at DESC
                    LIMIT 100
                ";
            } else {
                $where = '1=1';
                $params = [];

                if (!empty($status)) {
                    $where .= ' AND dadr.request_status = ?';
                    $params[] = $status;
                } else {
                    // By default, show pending first
                    $where .= ' AND dadr.request_status = "pending"';
                }

                if (!empty($search)) {
                    $search = '%' . $search . '%';
                    $where .= ' AND (d.name LIKE ? OR d.phone LIKE ?)';
                    $params[] = $search;
                    $params[] = $search;
                }

                $query = "
                    SELECT
                        dadr.id, dadr.driver_id, dadr.deletion_reason, dadr.request_status,
                        dadr.reviewed_by, dadr.admin_notes, dadr.reviewed_at, dadr.deleted_at, dadr.created_at,
                        d.name, d.phone, d.email
                    FROM driver_account_delete_requests dadr
                    LEFT JOIN drivers d ON dadr.driver_id = d.id
                    WHERE $where
                    ORDER BY dadr.created_at DESC
                    LIMIT 100
                ";
            }

            $stmt = $this->db->prepare($query);
            $stmt->execute($params);
            $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);

            echo utilities::apiMessage('Account deletion requests retrieved', 200, [
                'type'     => $type,
                'requests' => $requests,
                'count'    => count($requests),
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDeletionRequests::index - " . $e->getMessage());
            echo utilities::apiMessage('Error fetching requests: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/customer-deletion/:id/approve ───────────────────────────────
    public function approveCustomer($requestId): void
    {
        $me = BaseController::$authAdmin;
        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true) ?? [];

            $request = $this->getall('customer_account_delete_requests', 'id = ?', [$requestId]);
            if (!is_array($request)) {
                echo utilities::apiMessage('Request not found', 404);
                return;
            }

            if ($request['request_status'] !== 'pending') {
                echo utilities::apiMessage('Request is already ' . $request['request_status'], 409);
                return;
            }

            // Soft delete the customer
            $stmt = $this->db->prepare(
                'UPDATE users SET status = 0, deleted_at = NOW(), name = NULL, email = NULL, phone = NULL WHERE id = ?'
            );
            $stmt->execute([$request['customer_id']]);

            // Update deletion request
            $stmt = $this->db->prepare(
                'UPDATE customer_account_delete_requests SET request_status = ?, reviewed_by = ?, admin_notes = ?, reviewed_at = NOW(), deleted_at = NOW() WHERE id = ?'
            );
            $stmt->execute(['approved', $me['id'], $body['notes'] ?? null, $requestId]);

            $this->logActivity('admin', $me['id'], 'customer_deletion_approved', [
                'customer_id' => $request['customer_id'],
                'request_id'  => $requestId,
            ]);

            echo utilities::apiMessage('Customer account deletion approved', 200, [
                'request_id' => $requestId,
                'status'     => 'approved',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDeletionRequests::approveCustomer - " . $e->getMessage());
            echo utilities::apiMessage('Error approving deletion: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/customer-deletion/:id/reject ────────────────────────────────
    public function rejectCustomer($requestId): void
    {
        $me = BaseController::$authAdmin;
        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true) ?? [];

            $request = $this->getall('customer_account_delete_requests', 'id = ?', [$requestId]);
            if (!is_array($request)) {
                echo utilities::apiMessage('Request not found', 404);
                return;
            }

            if ($request['request_status'] !== 'pending') {
                echo utilities::apiMessage('Request is already ' . $request['request_status'], 409);
                return;
            }

            // Update deletion request
            $stmt = $this->db->prepare(
                'UPDATE customer_account_delete_requests SET request_status = ?, reviewed_by = ?, admin_notes = ?, reviewed_at = NOW() WHERE id = ?'
            );
            $stmt->execute(['rejected', $me['id'], $body['notes'] ?? null, $requestId]);

            $this->logActivity('admin', $me['id'], 'customer_deletion_rejected', [
                'customer_id' => $request['customer_id'],
                'request_id'  => $requestId,
            ]);

            echo utilities::apiMessage('Customer account deletion rejected', 200, [
                'request_id' => $requestId,
                'status'     => 'rejected',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDeletionRequests::rejectCustomer - " . $e->getMessage());
            echo utilities::apiMessage('Error rejecting deletion: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/driver-deletion/:id/approve ─────────────────────────────────
    public function approveDriver($requestId): void
    {
        $me = BaseController::$authAdmin;
        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true) ?? [];

            $request = $this->getall('driver_account_delete_requests', 'id = ?', [$requestId]);
            if (!is_array($request)) {
                echo utilities::apiMessage('Request not found', 404);
                return;
            }

            if ($request['request_status'] !== 'pending') {
                echo utilities::apiMessage('Request is already ' . $request['request_status'], 409);
                return;
            }

            // Soft delete the driver
            $stmt = $this->db->prepare(
                'UPDATE drivers SET status = 0, deleted_at = NOW(), name = NULL, email = NULL, phone = NULL WHERE id = ?'
            );
            $stmt->execute([$request['driver_id']]);

            // Update deletion request
            $stmt = $this->db->prepare(
                'UPDATE driver_account_delete_requests SET request_status = ?, reviewed_by = ?, admin_notes = ?, reviewed_at = NOW(), deleted_at = NOW() WHERE id = ?'
            );
            $stmt->execute(['approved', $me['id'], $body['notes'] ?? null, $requestId]);

            $this->logActivity('admin', $me['id'], 'driver_deletion_approved', [
                'driver_id'  => $request['driver_id'],
                'request_id' => $requestId,
            ]);

            echo utilities::apiMessage('Driver account deletion approved', 200, [
                'request_id' => $requestId,
                'status'     => 'approved',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDeletionRequests::approveDriver - " . $e->getMessage());
            echo utilities::apiMessage('Error approving deletion: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/driver-deletion/:id/reject ──────────────────────────────────
    public function rejectDriver($requestId): void
    {
        $me = BaseController::$authAdmin;
        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true) ?? [];

            $request = $this->getall('driver_account_delete_requests', 'id = ?', [$requestId]);
            if (!is_array($request)) {
                echo utilities::apiMessage('Request not found', 404);
                return;
            }

            if ($request['request_status'] !== 'pending') {
                echo utilities::apiMessage('Request is already ' . $request['request_status'], 409);
                return;
            }

            // Update deletion request
            $stmt = $this->db->prepare(
                'UPDATE driver_account_delete_requests SET request_status = ?, reviewed_by = ?, admin_notes = ?, reviewed_at = NOW() WHERE id = ?'
            );
            $stmt->execute(['rejected', $me['id'], $body['notes'] ?? null, $requestId]);

            $this->logActivity('admin', $me['id'], 'driver_deletion_rejected', [
                'driver_id'  => $request['driver_id'],
                'request_id' => $requestId,
            ]);

            echo utilities::apiMessage('Driver account deletion rejected', 200, [
                'request_id' => $requestId,
                'status'     => 'rejected',
            ]);
        } catch (Exception $e) {
            error_log("ERROR: AccountDeletionRequests::rejectDriver - " . $e->getMessage());
            echo utilities::apiMessage('Error rejecting deletion: ' . $e->getMessage(), 500);
        }
    }
}
