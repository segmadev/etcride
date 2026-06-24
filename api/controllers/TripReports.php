<?php
require_once ROOT . 'functions/BaseController.php';

class TripReports extends BaseController
{
    // ── POST /bookings/:id/report ─────────────────────────────────────────
    public function reportTrip($bookingId): void
    {
        error_log("DEBUG: TripReports::reportTrip called with bookingId=$bookingId");

        $me = BaseController::$authUser;

        // Read JSON body
        $raw = file_get_contents('php://input');
        $body = json_decode($raw, true) ?? [];

        error_log("DEBUG: authUser=" . json_encode($me));
        error_log("DEBUG: body=" . json_encode($body));

        if (!$me || !$me['id']) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        // Validate required fields
        if (empty($body['reason']) || empty($body['description'])) {
            echo utilities::apiMessage('Missing required fields: reason, description', 400);
            return;
        }

        try {
            // Check if booking exists and belongs to user
            error_log("DEBUG: Checking booking...");
            $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$bookingId, $me['id']]);
            error_log("DEBUG: booking result=" . json_encode($booking));

            if (!is_array($booking)) {
                echo utilities::apiMessage('Booking not found or unauthorized', 404);
                return;
            }

            // Allow reporting any trip status (active, completed, cancelled, etc.)
            // No status validation needed - users can report any trip

            // Create trip report
            error_log("DEBUG: Creating trip report...");
            $reportData = [
                'booking_id'   => $bookingId,
                'customer_id'  => $me['id'],
                'report_reason'=> $body['reason'],
                'description'  => $body['description'],
                'report_status'=> 'pending',
            ];

            $reportId = $this->quick_insert('trip_reports', $reportData);
            error_log("DEBUG: quick_insert result=" . $reportId);

            if (!$reportId) {
                echo utilities::apiMessage('Failed to create report', 500);
                return;
            }

            // Log activity
            $this->logActivity('customer', $me['id'], 'trip_reported', [
                'booking_id' => $bookingId,
                'report_id'  => $reportId,
                'reason'     => $body['reason'],
            ]);

            echo utilities::apiMessage('Trip reported successfully', 201, [
                'report_id' => $reportId,
                'booking_id' => $bookingId,
            ]);
        } catch (Exception $e) {
            error_log("EXCEPTION: " . $e->getMessage() . "\n" . $e->getTraceAsString());
            echo utilities::apiMessage('Error reporting trip: ' . $e->getMessage(), 500);
        }
    }

    // ── POST /bookings/:id/request-cancellation ────────────────────────────
    public function requestCancellation($bookingId): void
    {
        $me = BaseController::$authUser;

        // Read JSON body
        $raw = file_get_contents('php://input');
        $body = json_decode($raw, true) ?? [];

        if (!$me || !$me['id']) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        // Validate required fields
        if (empty($body['reason']) || empty($body['description'])) {
            echo utilities::apiMessage('Missing required fields: reason, description', 400);
            return;
        }

        try {
            // Check if booking exists and belongs to user
            $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$bookingId, $me['id']]);
            if (!is_array($booking)) {
                echo utilities::apiMessage('Booking not found or unauthorized', 404);
                return;
            }

            // Check if booking is active
            $activeStatuses = ['accepted', 'started', 'in_progress'];
            if (!in_array($booking['status'], $activeStatuses)) {
                echo utilities::apiMessage('Can only request cancellation for active trips', 400);
                return;
            }

            // Check if there's already a report for this booking
            $existingReport = $this->getall('trip_reports', 'booking_id = ? AND customer_id = ?', [$bookingId, $me['id']]);
            if (!is_array($existingReport)) {
                echo utilities::apiMessage('Must report trip before requesting cancellation', 400);
                return;
            }

            // Check if cancellation request already exists
            $existingCancellation = $this->getall('trip_cancellations', 'trip_report_id = ?', [$existingReport['id']]);
            if (is_array($existingCancellation)) {
                echo utilities::apiMessage('Cancellation request already submitted for this report', 400);
                return;
            }

            // Create cancellation request
            $cancellationData = [
                'trip_report_id'      => $existingReport['id'],
                'booking_id'          => $bookingId,
                'customer_id'         => $me['id'],
                'cancellation_reason' => $body['reason'],
                'description'         => $body['description'],
                'cancellation_status' => 'pending',
            ];

            $cancellationId = $this->quick_insert('trip_cancellations', $cancellationData);
            if (!$cancellationId) {
                echo utilities::apiMessage('Failed to request cancellation', 500);
                return;
            }

            // Log activity
            $this->logActivity('customer', $me['id'], 'cancellation_requested', [
                'booking_id' => $bookingId,
                'cancellation_id' => $cancellationId,
            ]);

            echo utilities::apiMessage('Cancellation request submitted', 201, [
                'cancellation_id' => $cancellationId,
                'status' => 'pending',
            ]);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error requesting cancellation: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /reports ──────────────────────────────────────────────────────────
    public function index(): void
    {
        $me = BaseController::$authUser;

        if (!$me || !$me['id']) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $query = "
                SELECT
                    tr.id, tr.booking_id, tr.report_reason, tr.description,
                    tr.report_status, tr.created_at, tr.updated_at,
                    tc.id as cancellation_id, tc.cancellation_status,
                    tc.admin_notes
                FROM trip_reports tr
                LEFT JOIN trip_cancellations tc ON tr.id = tc.trip_report_id
                WHERE tr.customer_id = ?
                ORDER BY tr.created_at DESC
                LIMIT 100
            ";

            $stmt = $this->db->prepare($query);
            $stmt->execute([$me['id']]);
            $reports = $stmt->fetchAll(PDO::FETCH_ASSOC);

            echo utilities::apiMessage('Reports retrieved', 200, $reports);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error fetching reports: ' . $e->getMessage(), 500);
        }
    }

    // ── GET /bookings/:id/report-status ────────────────────────────────────
    public function getReportStatus($bookingId): void
    {
        $me = BaseController::$authUser;

        if (!$me || !$me['id']) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $report = $this->getall('trip_reports', 'booking_id = ? AND customer_id = ?', [$bookingId, $me['id']]);

            if (!is_array($report)) {
                echo utilities::apiMessage('No report found', 404);
                return;
            }

            $cancellation = $this->getall('trip_cancellations', 'trip_report_id = ?', [$report['id']]);
            $cancellation = is_array($cancellation) ? $cancellation : null;

            echo utilities::apiMessage('Report status retrieved', 200, [
                'report' => $report,
                'cancellation' => $cancellation,
            ]);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error fetching report: ' . $e->getMessage(), 500);
        }
    }
}
