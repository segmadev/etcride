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
            $where = "driver_id = ? AND status = ? LIMIT $perPage OFFSET $offset";
            $params = [$me['id'], $status];
        } else {
            $placeholders = implode(',', array_fill(0, count($activeStatuses), '?'));
            $where = "driver_id = ? AND status IN ($placeholders) LIMIT $perPage OFFSET $offset";
            $params = array_merge([$me['id']], $activeStatuses);
        }

        $stmt = $this->db->prepare("SELECT b.*, u.name AS customer_name, u.phone AS customer_phone,
            vt.name AS vehicle_type_name
            FROM bookings b
            LEFT JOIN users u ON u.id = b.customer_id
            LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
            WHERE b.driver_id = ?
            " . ($status !== '' ? "AND b.status = ?" : "AND b.status IN (" . implode(',', array_fill(0, count($activeStatuses), '?')) . ")")
            . " ORDER BY b.created_at DESC LIMIT $perPage OFFSET $offset");

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

        // Return to pending for admin to reassign
        $this->update('bookings', ['status' => 'pending', 'driver_id' => null], "id = '$id'");
        $this->recordStatusChange($id, 'assigned', 'rejected', 'driver', $me['id'], $reason);

        // Notify admin (log only — admin gets notified via dashboard polling)
        $this->logActivity('driver', $me['id'], 'job_rejected', ['booking_id' => $id, 'reason' => $reason]);

        echo utilities::apiMessage('Job rejected. Admin has been notified to reassign.', 200);
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

        $this->update('bookings', ['status' => 'arrived'], "id = '$id'");
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

        $this->update('bookings', ['status' => 'in_progress'], "id = '$id'");
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
