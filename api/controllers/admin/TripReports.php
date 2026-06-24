<?php
require_once ROOT . 'functions/BaseController.php';

class TripReports extends BaseController
{
    // ── GET /admin/trip-reports ────────────────────────────────────────────
    public function index(): void
    {
        error_log("DEBUG: Admin TripReports::index called");

        $me = BaseController::$authAdmin;

        error_log("DEBUG: authAdmin = " . json_encode($me));

        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $filters = $_GET;
            error_log("DEBUG: filters = " . json_encode($filters));

            $where = '1=1';
            $params = [];

            // Filter by status
            if (!empty($filters['status'])) {
                $where .= ' AND tr.report_status = ?';
                $params[] = $filters['status'];
            }

            // Filter by cancellation status
            if (!empty($filters['cancellation_status'])) {
                $where .= ' AND COALESCE(tc.cancellation_status, "none") = ?';
                $params[] = $filters['cancellation_status'];
            }

            // Search by booking ID or customer name
            if (!empty($filters['search'])) {
                $search = '%' . $filters['search'] . '%';
                $where .= ' AND (b.id LIKE ? OR u.name LIKE ?)';
                $params[] = $search;
                $params[] = $search;
            }

            $query = "
                SELECT
                    tr.id, tr.booking_id, tr.report_reason, tr.report_status, tr.created_at,
                    b.id as booking_id_full, b.status as booking_status, b.final_fare, b.pickup_address, b.destination_address,
                    u.id as customer_id, u.name as customer_name, u.phone as customer_phone, u.email as customer_email,
                    d.id as driver_id, d.name as driver_name, d.phone as driver_phone,
                    tc.id as cancellation_id, tc.cancellation_status, tc.cancellation_reason
                FROM trip_reports tr
                LEFT JOIN bookings b ON tr.booking_id = b.id
                LEFT JOIN users u ON tr.customer_id = u.id
                LEFT JOIN drivers d ON b.driver_id = d.id
                LEFT JOIN trip_cancellations tc ON tr.id = tc.trip_report_id
                WHERE $where
                ORDER BY tr.created_at DESC
                LIMIT 50
            ";

            error_log("DEBUG: query = $query");
            error_log("DEBUG: params = " . json_encode($params));

            $stmt = $this->db->prepare($query);
            $stmt->execute($params);
            $reports = $stmt->fetchAll(PDO::FETCH_ASSOC);

            error_log("DEBUG: reports count = " . count($reports));

            echo utilities::apiMessage('Trip reports retrieved', 200, $reports);
        } catch (Exception $e) {
            error_log("EXCEPTION: " . $e->getMessage() . "\n" . $e->getTraceAsString());
            echo utilities::apiMessage('Error fetching reports: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /admin/trip-reports/:id ────────────────────────────────────────
    public function show($reportId): void
    {
        $me = BaseController::$authAdmin;

        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $query = "
                SELECT
                    tr.id, tr.booking_id, tr.customer_id, tr.report_reason, tr.description,
                    tr.report_status, tr.created_at, tr.updated_at,
                    b.booking_code, b.status, b.final_fare, b.pickup_address, b.destination_address,
                    b.vehicle_type_id, b.driver_id, b.distance_km, b.duration_minutes,
                    u.name as customer_name, u.phone as customer_phone, u.email as customer_email,
                    d.name as driver_name, d.phone as driver_phone, d.email as driver_email,
                    tc.id as cancellation_id, tc.cancellation_status, tc.admin_notes, tc.cancellation_reason
                FROM trip_reports tr
                LEFT JOIN bookings b ON tr.booking_id = b.id
                LEFT JOIN users u ON tr.customer_id = u.id
                LEFT JOIN drivers d ON b.driver_id = d.id
                LEFT JOIN trip_cancellations tc ON tr.id = tc.trip_report_id
                WHERE tr.id = ?
            ";

            $stmt = $this->db->prepare($query);
            $stmt->execute([$reportId]);
            $report = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$report) {
                echo utilities::apiMessage('Report not found', 404);
                return;
            }

            echo utilities::apiMessage('Report details retrieved', 200, $report);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error fetching report: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/trip-reports/:id/approve-cancellation ────────────────────
    public function approveCancellation($reportId): void
    {
        $me = BaseController::$authAdmin;

        // Read JSON body
        $raw = file_get_contents('php://input');
        $body = json_decode($raw, true) ?? [];

        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            // Get the report
            $report = $this->getall('trip_reports', 'id = ?', [$reportId]);
            if (!is_array($report)) {
                echo utilities::apiMessage('Report not found', 404);
                return;
            }

            // Get the cancellation request
            $cancellation = $this->getall('trip_cancellations', 'trip_report_id = ?', [$reportId]);
            if (!is_array($cancellation)) {
                echo utilities::apiMessage('No cancellation request found', 404);
                return;
            }

            if ($cancellation['cancellation_status'] !== 'pending') {
                echo utilities::apiMessage('Cancellation already reviewed', 400);
                return;
            }

            // Update cancellation status
            $stmt = $this->db->prepare("UPDATE trip_cancellations SET cancellation_status = ?, admin_notes = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?");
            $stmt->execute(['approved', $body['notes'] ?? null, $me['id'], date('Y-m-d H:i:s'), $cancellation['id']]);

            // Cancel the booking
            $stmt = $this->db->prepare("UPDATE bookings SET status = ? WHERE id = ?");
            $stmt->execute(['cancelled', $cancellation['booking_id']]);

            // Update report status
            $stmt = $this->db->prepare("UPDATE trip_reports SET report_status = ? WHERE id = ?");
            $stmt->execute(['resolved', $reportId]);

            // Log activity
            $this->logActivity('admin', $me['id'], 'cancellation_approved', [
                'booking_id' => $cancellation['booking_id'],
                'cancellation_id' => $cancellation['id'],
            ]);

            echo utilities::apiMessage('Cancellation approved', 200, [
                'cancellation_id' => $cancellation['id'],
                'status' => 'approved',
            ]);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error approving cancellation: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/trip-reports/:id/reject-cancellation ─────────────────────
    public function rejectCancellation($reportId): void
    {
        $me = BaseController::$authAdmin;

        // Read JSON body
        $raw = file_get_contents('php://input');
        $body = json_decode($raw, true) ?? [];

        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            // Get the report
            $report = $this->getOne('trip_reports', 'id = ?', [$reportId]);
            if (!$report) {
                echo utilities::apiMessage('Report not found', 404);
                return;
            }

            // Get the cancellation request
            $cancellation = $this->getOne('trip_cancellations', 'trip_report_id = ?', [$reportId]);
            if (!$cancellation) {
                echo utilities::apiMessage('No cancellation request found', 404);
                return;
            }

            if ($cancellation['cancellation_status'] !== 'pending') {
                echo utilities::apiMessage('Cancellation already reviewed', 400);
                return;
            }

            // Update cancellation status
            $stmt = $this->db->prepare("UPDATE trip_cancellations SET cancellation_status = ?, admin_notes = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?");
            $stmt->execute(['rejected', $body['notes'] ?? null, $me['id'], date('Y-m-d H:i:s'), $cancellation['id']]);

            // Log activity
            $this->logActivity('admin', $me['id'], 'cancellation_rejected', [
                'booking_id' => $cancellation['booking_id'],
                'cancellation_id' => $cancellation['id'],
            ]);

            echo utilities::apiMessage('Cancellation rejected', 200, [
                'cancellation_id' => $cancellation['id'],
                'status' => 'rejected',
            ]);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error rejecting cancellation: ' . $e->getMessage(), 500);
        }
    }
}
