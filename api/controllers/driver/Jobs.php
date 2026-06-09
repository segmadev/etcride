<?php
require_once ROOT . 'functions/BaseController.php';

class Jobs extends BaseController
{
    // ── GET /driver/jobs ──────────────────────────────────────────────────────
    public function index(): void
    {
        $me       = BaseController::$authDriver;
        $status   = $this->query('status', '');
        $page     = max(1, (int) $this->query('page', 1));
        $perPage  = 20;
        $offset   = ($page - 1) * $perPage;

        $activeStatuses = ['assigned', 'accepted', 'arrived', 'in_progress', 'payment_pending'];

        if ($status !== '') {
            // Explicit status filter requested — return exactly that
            $sql = "SELECT b.*, u.name AS customer_name, u.phone AS customer_phone,
                        vt.name AS vehicle_type_name
                    FROM bookings b
                    LEFT JOIN users u  ON u.id  = b.customer_id
                    LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
                    WHERE b.driver_id = ? AND b.status = ?
                    ORDER BY b.created_at DESC LIMIT $perPage OFFSET $offset";
            $params = [$me['id'], $status];
        } else {
            // Return active jobs AND jobs cancelled in the last 10 min so the
            // app can detect a customer-initiated cancellation before the job
            // disappears completely from the list.
            $placeholders = implode(',', array_fill(0, count($activeStatuses), '?'));
            $sql = "SELECT b.*, u.name AS customer_name, u.phone AS customer_phone,
                        vt.name AS vehicle_type_name
                    FROM bookings b
                    LEFT JOIN users u  ON u.id  = b.customer_id
                    LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
                    WHERE b.driver_id = ?
                      AND (
                        b.status IN ($placeholders)
                        OR (b.status = 'cancelled'
                            AND b.updated_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE))
                      )
                    ORDER BY b.created_at DESC LIMIT $perPage OFFSET $offset";
            $params = array_merge([$me['id']], $activeStatuses);
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $jobs = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($jobs as &$job) {
            $job['stops'] = $this->getStops($job['id']);
        }

        echo utilities::apiMessage('Jobs retrieved.', 200, $jobs);
    }

    // ── GET /driver/jobs/:id ──────────────────────────────────────────────────
    public function show(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) {
            echo utilities::apiMessage('Job not found.', 404);
            return;
        }

        $job['stops']    = $this->getStops($id);
        $job['customer'] = $this->getall('users', 'id = ?', [$job['customer_id']], 'id, name, phone');
        $job['free_waiting_minutes']   = (int)   $this->setting('free_waiting_minutes',   '3');
        $job['waiting_charge_per_min'] = (float) $this->setting('waiting_charge_per_min', '0');

        echo utilities::apiMessage('Job retrieved.', 200, $job);
    }

    // ── POST /driver/jobs/:id/accept ─────────────────────────────────────────
    public function accept(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        if ($job['status'] !== 'assigned') {
            echo utilities::apiMessage("Job cannot be accepted in '{$job['status']}' status.", 409);
            return;
        }

        $this->update('bookings', ['status' => 'accepted'], "id = '$id'");
        $this->recordStatusChange($id, 'assigned', 'accepted', 'driver', $me['id']);

        // Notify customer
        $this->notify('customer', $job['customer_id'], 'Driver Accepted',
            'Your driver has accepted the booking and is on the way.',
            'driver_accepted', $id);

        echo utilities::apiMessage('Job accepted.', 200);
    }

    // ── POST /driver/jobs/:id/reject ──────────────────────────────────────────
    public function reject(string $id): void
    {
        $me     = BaseController::$authDriver;
        $job    = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);
        $reason = $this->str('reason', 'Driver rejected');

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        if ($job['status'] !== 'assigned') {
            echo utilities::apiMessage("Job cannot be rejected in '{$job['status']}' status.", 409);
            return;
        }

        // Step 1: unassign — return booking to pending, record the rejection
        $this->update('bookings', ['status' => 'pending', 'driver_id' => null], "id = '$id'");
        $this->recordStatusChange($id, 'assigned', 'rejected', 'driver', $me['id'], $reason);
        $this->logActivity('driver', $me['id'], 'job_rejected', ['booking_id' => $id, 'reason' => $reason]);

        // Step 2: notify customer that the driver declined
        $this->notify(
            'customer',
            $job['customer_id'],
            'Driver Declined',
            'Your assigned driver declined the trip. We\'re finding you another driver.',
            'driver_declined',
            $id
        );

        // Step 3: attempt to auto-reassign to the next closest available driver
        $reassigned = $this->tryReassignBooking($id, $job);

        echo utilities::apiMessage(
            $reassigned
                ? 'Job rejected. Another nearby driver has been assigned.'
                : 'Job rejected. Admin has been notified to reassign.',
            200
        );
    }

    /**
     * After a driver rejection, find the next closest eligible driver and assign them.
     *
     * Reads booking_status_history to collect all previously-tried driver IDs, then
     * calls findNearestDriverExcluding() to skip them.
     *
     * Hard cap: give up after MAX_REASSIGN_RETRIES total rejections and let admin handle it.
     */
    private const MAX_REASSIGN_RETRIES = 5;

    private function tryReassignBooking(string $bookingId, array $job): bool
    {
        // Gather all driver IDs who have already rejected this booking
        $histStmt = $this->db->prepare(
            "SELECT DISTINCT changed_by_id
             FROM booking_status_history
             WHERE booking_id      = ?
               AND to_status       = 'rejected'
               AND changed_by_role = 'driver'
               AND changed_by_id   IS NOT NULL"
        );
        $histStmt->execute([$bookingId]);
        $rejectedIds = $histStmt->fetchAll(PDO::FETCH_COLUMN) ?: [];

        // Hard cap — prevent infinite reassignment loops
        if (count($rejectedIds) >= self::MAX_REASSIGN_RETRIES) {
            $this->logActivity('system', null, 'booking_unassignable', [
                'booking_id' => $bookingId,
                'reason'     => 'Exceeded max driver rejection retries (' . self::MAX_REASSIGN_RETRIES . ')',
            ]);
            return false;
        }

        $pickupLat = (float) ($job['pickup_lat']    ?? 0);
        $pickupLng = (float) ($job['pickup_lng']    ?? 0);
        $vtId      =         ($job['vehicle_type_id'] ?? '');

        // Try to find a new online driver (excluding those who already rejected)
        $nextDriver = $this->findNearestDriverExcluding($pickupLat, $pickupLng, $vtId, $rejectedIds);

        if ($nextDriver) {
            $this->assignDriver($bookingId, $nextDriver['id'], $job);
            return true;
        }

        // No online driver available — soft-notify nearby offline drivers
        // (skip any who already rejected)
        $bookingType  = $job['booking_type'] ?? 'booking';
        $offlineDrivers = $this->findNearbyOfflineDrivers($pickupLat, $pickupLng, $vtId);
        foreach ($offlineDrivers as $od) {
            if (!in_array($od['id'], $rejectedIds, true)) {
                $this->notify(
                    'driver', $od['id'],
                    'New Trip Available — Are You Available?',
                    "A $bookingType trip near you needs a driver. Go online to accept it.",
                    'trip_interest_request', $bookingId
                );
            }
        }

        return false;
    }

    // ── POST /driver/jobs/:id/cancel ─────────────────────────────────────────
    public function cancel(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) {
            echo utilities::apiMessage('Job not found.', 404);
            return;
        }

        // Drivers may only cancel before the trip is in progress
        $cancellable = ['accepted', 'arrived'];
        if (!in_array($job['status'], $cancellable)) {
            echo utilities::apiMessage(
                "Cannot cancel a job in '{$job['status']}' status.", 409);
            return;
        }

        $reason = $this->str('reason', 'Cancelled by driver');

        $this->update('bookings', [
            'status'              => 'cancelled',
            'cancelled_by_role'   => 'driver',
            'cancelled_by_id'     => $me['id'],
            'cancellation_reason' => $reason,
        ], "id = '$id'");

        $this->recordStatusChange($id, $job['status'], 'cancelled', 'driver', $me['id'], $reason);
        $this->logActivity('driver', $me['id'], 'job_cancelled',
            ['booking_id' => $id, 'reason' => $reason]);

        // Notify the customer
        if (!empty($job['customer_id'])) {
            $this->notify('customer', $job['customer_id'],
                'Trip Cancelled by Driver',
                'Your driver has cancelled the trip. We\'re looking for another driver.',
                'booking_cancelled', $id);
        }

        echo utilities::apiMessage('Job cancelled.', 200);
    }

    // ── POST /driver/jobs/:id/arrive ─────────────────────────────────────────
    public function arrive(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        if ($job['status'] !== 'accepted') {
            echo utilities::apiMessage("Can only mark arrival when status is 'accepted' (current: '{$job['status']}').", 409);
            return;
        }

        // ── GPS proximity check ──────────────────────────────────────────────
        $driverLat    = $this->flt('lat');
        $driverLng    = $this->flt('lng');
        $gpsAccuracy  = abs($this->flt('gps_accuracy_m'));   // metres, ≥ 0

        if ($driverLat !== 0.0 && $driverLng !== 0.0) {
            $pickupLat  = (float) ($job['pickup_lat'] ?? 0);
            $pickupLng  = (float) ($job['pickup_lng'] ?? 0);
            $thresholdM = (float) $this->setting('auto_arrive_radius_m', '20');
            $effectiveM = $thresholdM + $gpsAccuracy;

            $distM = $this->haversine($driverLat, $driverLng, $pickupLat, $pickupLng) * 1000;

            if ($distM > $effectiveM) {
                $remaining = round($distM - $thresholdM);
                echo utilities::apiMessage(
                    "You are {$remaining}m away from the pickup point. "
                    . "Get closer to mark your arrival.",
                    422
                );
                return;
            }
        }

        $this->update('bookings', ['status' => 'arrived', 'arrived_at' => date('Y-m-d H:i:s')], "id = '$id'");
        $this->recordStatusChange($id, 'accepted', 'arrived', 'driver', $me['id']);

        $this->notify('customer', $job['customer_id'], 'Driver Arrived',
            'Your driver has arrived at the pickup location!', 'driver_arrived', $id);

        echo utilities::apiMessage('Arrival confirmed.', 200);
    }

    // ── POST /driver/jobs/:id/start ───────────────────────────────────────────
    public function start(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        $startable = ['accepted', 'arrived'];
        if (!in_array($job['status'], $startable)) {
            echo utilities::apiMessage("Trip cannot start in '{$job['status']}' status.", 409);
            return;
        }

        $now = date('Y-m-d H:i:s');

        // ── Waiting time charge ────────────────────────────────────────────────
        $waitingExtraCharge = 0.0;
        $arrivedAt = $job['arrived_at'] ?? null;
        if ($arrivedAt && $job['status'] === 'arrived') {
            $freeMinutes  = (int)   $this->setting('free_waiting_minutes',   '3');
            $chargePerMin = (float) $this->setting('waiting_charge_per_min', '0');
            $elapsedSecs  = max(0, time() - strtotime($arrivedAt));
            $billableMins = max(0.0, ($elapsedSecs / 60) - $freeMinutes);
            $waitingExtraCharge = round($billableMins * $chargePerMin, 2);
        }

        $this->update('bookings', ['status' => 'in_progress', 'waiting_extra_charge' => $waitingExtraCharge], "id = '$id'");
        $this->recordStatusChange($id, $job['status'], 'in_progress', 'driver', $me['id']);

        // Create trip record
        $tripId = utilities::genID('TRP_', 10);
        $this->quick_insert('trips', [
            'id'         => $tripId,
            'booking_id' => $id,
            'driver_id'  => $me['id'],
            'started_at' => $now,
            'status'     => 'active',
        ]);

        // Notify customer
        $this->notify('customer', $job['customer_id'], 'Trip Started',
            'Your driver has started the trip.', 'trip_started', $id);

        $this->logActivity('driver', $me['id'], 'trip_started', ['booking_id' => $id, 'trip_id' => $tripId]);

        echo utilities::apiMessage('Trip started.', 200, ['trip_id' => $tripId, 'started_at' => $now]);
    }

    // ── POST /driver/jobs/:id/stops/:stop_id/reach ────────────────────────────
    public function reachStop(string $id, string $stopId): void
    {
        $me   = BaseController::$authDriver;
        $job  = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);
        $stop = $this->getall('booking_stops', 'id = ? AND booking_id = ?', [$stopId, $id]);

        if (!is_array($job))  { echo utilities::apiMessage('Job not found.', 404); return; }
        if (!is_array($stop)) { echo utilities::apiMessage('Stop not found.', 404); return; }
        if ($job['status'] !== 'in_progress') {
            echo utilities::apiMessage('Trip is not in progress.', 409); return;
        }

        $this->update('booking_stops', ['status' => 'reached', 'reached_at' => date('Y-m-d H:i:s')],
            "id = '$stopId'");

        $this->notify('customer', $job['customer_id'], 'Stop Reached',
            "Driver has reached: {$stop['address']}", 'stop_reached', $id);

        echo utilities::apiMessage('Stop marked as reached.', 200);
    }

    // ── POST /driver/jobs/:id/complete ────────────────────────────────────────
    public function complete(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        if ($job['status'] !== 'in_progress') {
            echo utilities::apiMessage("Trip cannot be completed in '{$job['status']}' status.", 409);
            return;
        }

        $now = date('Y-m-d H:i:s');

        // Determine final status and payment handling
        $newStatus = 'completed';
        $this->update('bookings', ['status' => $newStatus], "id = '$id'");
        $this->recordStatusChange($id, 'in_progress', 'completed', 'driver', $me['id']);

        // Update trip record
        $trip = $this->getall('trips', 'booking_id = ?', [$id]);
        if (is_array($trip)) {
            $this->update('trips', [
                'completed_at' => $now,
                'status'       => 'completed',
            ], "id = '{$trip['id']}'");
        }

        // Always move to payment_pending so the customer settles via app
        if ($job['payment_status'] !== 'paid') {
            $this->update('bookings', ['status' => 'payment_pending'], "id = '$id'");
            $this->notify('customer', $job['customer_id'], 'Trip Completed — Payment Required',
                'Your trip is complete. Please make your payment.',
                'trip_completed', $id);
        } else {
            $this->notify('customer', $job['customer_id'], 'Trip Completed',
                'Your trip has been completed. Thank you for riding with us!',
                'trip_completed', $id);
        }

        $this->logActivity('driver', $me['id'], 'trip_completed', ['booking_id' => $id]);

        echo utilities::apiMessage('Trip completed.', 200, ['completed_at' => $now]);
    }

    // ── POST /driver/jobs/:id/confirm-payment ─────────────────────────────────
    // Called by the driver after physically collecting cash (or confirming
    // receipt). Transitions payment_pending → completed.
    public function confirmPayment(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }
        if ($job['status'] !== 'payment_pending') {
            echo utilities::apiMessage(
                "Payment can only be confirmed for jobs in 'payment_pending' status (current: '{$job['status']}').",
                409
            );
            return;
        }

        $now = date('Y-m-d H:i:s');

        $this->update('bookings', [
            'status'         => 'completed',
            'payment_status' => 'paid',
        ], "id = '$id'");
        $this->recordStatusChange($id, 'payment_pending', 'completed', 'driver', $me['id'], 'Payment confirmed by driver');

        // Update trip record if exists
        $trip = $this->getall('trips', 'booking_id = ?', [$id]);
        if (is_array($trip)) {
            $this->update('trips', ['completed_at' => $now, 'status' => 'completed'], "id = '{$trip['id']}'");
        }

        $this->notify('customer', $job['customer_id'], 'Payment Confirmed',
            'Your payment has been received. Thank you for riding with us!',
            'trip_completed', $id);

        $this->logActivity('driver', $me['id'], 'payment_confirmed', ['booking_id' => $id]);

        echo utilities::apiMessage('Payment confirmed. Trip completed.', 200, ['completed_at' => $now]);
    }

    // ── PUT /driver/jobs/:id/payment-method ──────────────────────────────────
    public function updatePaymentMethod(string $id): void
    {
        $me  = BaseController::$authDriver;
        $job = $this->getall('bookings', 'id = ? AND driver_id = ?', [$id, $me['id']]);

        if (!is_array($job)) { echo utilities::apiMessage('Job not found.', 404); return; }

        $nonChangeable = ['completed', 'cancelled', 'paid'];
        if (in_array($job['status'], $nonChangeable)) {
            echo utilities::apiMessage("Cannot change payment method for a {$job['status']} booking.", 409);
            return;
        }

        $method  = $this->str('payment_method');
        $allowed = ['cash', 'bank_transfer', 'flutterwave'];
        if (!in_array($method, $allowed)) {
            echo utilities::apiMessage('Invalid payment method.', 422);
            return;
        }

        $this->update('bookings', ['payment_method' => $method], "id = '$id'");
        $this->notify('customer', $job['customer_id'], 'Payment Method Updated',
            "Driver changed payment method to $method.", 'payment_method_changed', $id);

        echo utilities::apiMessage('Payment method updated.', 200, ['payment_method' => $method]);
    }

    // ── GET /driver/history ───────────────────────────────────────────────────
    public function history(): void
    {
        $me      = BaseController::$authDriver;
        $page    = max(1, (int) $this->query('page', 1));
        $perPage = 20;
        $offset  = ($page - 1) * $perPage;

        $stmt = $this->db->prepare(
            "SELECT b.id, b.booking_code, b.booking_type, b.status, b.final_fare,
                    b.pickup_address, b.destination_address, b.created_at,
                    u.name AS customer_name
             FROM bookings b
             LEFT JOIN users u ON u.id = b.customer_id
             WHERE b.driver_id = ? AND b.status IN ('completed','cancelled')
             ORDER BY b.created_at DESC
             LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute([$me['id']]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('History retrieved.', 200, $rows);
    }

    // ── Driver Notifications ──────────────────────────────────────────────────
    public function notifications(): void
    {
        $me   = BaseController::$authDriver;
        $stmt = $this->db->prepare(
            "SELECT * FROM notifications WHERE recipient_role = 'driver' AND recipient_id = ?
             ORDER BY created_at DESC LIMIT 50"
        );
        $stmt->execute([$me['id']]);
        echo utilities::apiMessage('Notifications retrieved.', 200, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function markNotificationRead(string $notifId): void
    {
        $me = BaseController::$authDriver;
        $this->update('notifications', ['is_read' => 1],
            "id = '$notifId' AND recipient_id = '{$me['id']}' AND recipient_role = 'driver'");
        echo utilities::apiMessage('Marked as read.', 200);
    }

    // ── Private helper ────────────────────────────────────────────────────────
    private function getStops(string $bookingId): array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM booking_stops WHERE booking_id = ? ORDER BY stop_order ASC'
        );
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
