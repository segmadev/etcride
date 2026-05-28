<?php
require_once ROOT . 'functions/BaseController.php';

class Bookings extends BaseController
{
    private function normalizeId(string $id): string
    {
        return strlen($id) > 20 ? substr($id, 0, 20) : $id;
    }

    // ── GET /admin/bookings ───────────────────────────────────────────────────
    public function index(): void
    {
        $me      = BaseController::$authAdmin;
        $status  = $this->query('status', '');
        $from    = $this->query('from', '');
        $to      = $this->query('to', '');
        $type    = $this->query('type', '');
        $page    = max(1, (int) $this->query('page', 1));
        $perPage = 25;
        $offset  = ($page - 1) * $perPage;

        $conditions = [];
        $params     = [];

        if ($status !== '') { $conditions[] = 'b.status = ?';       $params[] = $status; }
        if ($type   !== '') { $conditions[] = 'b.booking_type = ?'; $params[] = $type; }
        if ($from   !== '') { $conditions[] = 'DATE(b.created_at) >= ?'; $params[] = $from; }
        if ($to     !== '') { $conditions[] = 'DATE(b.created_at) <= ?'; $params[] = $to; }

        $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        $stmt = $this->db->prepare(
            "SELECT b.id, b.booking_code, b.booking_type, b.status, b.estimated_fare,
                    b.final_fare, b.payment_status, b.pickup_address, b.destination_address,
                    b.created_at, b.num_stops, b.distance_km,
                    b.vehicle_type_id,
                    u.name AS customer_name, u.phone AS customer_phone,
                    d.name AS driver_name, d.phone AS driver_phone,
                    vt.name AS vehicle_type, vt.category AS vehicle_type_category
             FROM bookings b
             LEFT JOIN users u          ON u.id  = b.customer_id
             LEFT JOIN drivers d        ON d.id  = b.driver_id
             LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
             $where
             ORDER BY b.created_at DESC
             LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute($params);

        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM bookings b $where");
        $countStmt->execute($params);
        $total = (int) $countStmt->fetchColumn();

        echo utilities::apiMessage('Bookings retrieved.', 200, [
            'total'    => $total,
            'page'     => $page,
            'per_page' => $perPage,
            'data'     => $stmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }

    // ── GET /admin/bookings/:id ───────────────────────────────────────────────
    public function show(string $id): void
    {
        $id = $this->normalizeId($id);
        $booking = $this->getall('bookings', 'id = ?', [$id]);
        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        $booking['stops']   = $this->getStops($id);
        $booking['history'] = $this->getStatusHistory($id);
        $booking['payment'] = $this->getall('payments', 'booking_id = ?', [$id]);
        $booking['customer'] = $this->getall('users', 'id = ?', [$booking['customer_id']], 'id, name, phone, email');

        if ($booking['driver_id']) {
            $booking['driver'] = $this->getall('drivers', 'id = ?', [$booking['driver_id']],
                'id, name, phone, last_lat, last_lng, last_seen, vehicle_id');
        }

        echo utilities::apiMessage('Booking retrieved.', 200, $booking);
    }

    // ── POST /admin/bookings/:id/assign ───────────────────────────────────────
    public function assign(string $id): void
    {
        $me       = BaseController::$authAdmin;
        $id       = $this->normalizeId($id);
        $driverId = $this->str('driver_id');

        if ($driverId === '') {
            echo utilities::apiMessage('driver_id is required.', 422);
            return;
        }

        $booking = $this->getall('bookings', 'id = ?', [$id]);
        if (!is_array($booking)) { echo utilities::apiMessage('Booking not found.', 404); return; }

        if (!in_array($booking['status'], ['pending', 'rejected'])) {
            echo utilities::apiMessage("Cannot assign driver to a booking in '{$booking['status']}' status.", 409);
            return;
        }

        $driver = $this->getall('drivers', 'id = ? AND is_active = 1', [$driverId]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found or inactive.', 404);
            return;
        }

        $this->update('bookings', ['status' => 'assigned', 'driver_id' => $driverId], "id = '$id'");
        $this->recordStatusChange($id, $booking['status'], 'assigned', 'admin', $me['id']);

        $this->notify('driver', $driverId, 'New Job Assigned',
            "You have a new {$booking['booking_type']} booking.", 'driver_assigned', $id);

        // Email customer: driver assigned
        $customer = $this->getall('users', 'id = ?', [$booking['customer_id']], 'name, email');
        if (is_array($customer) && !empty($customer['email'])) {
            $vt = $this->getall('vehicle_types', 'id = ?', [$booking['vehicle_type_id']], 'name');
            $this->sendTemplateEmail('driver_assigned', $customer['email'], $customer['name'], [
                '{{customer_name}}' => $customer['name'],
                '{{booking_code}}' => $booking['booking_code'] ?? $id,
                '{{driver_name}}'  => $driver['name'],
                '{{driver_phone}}' => $driver['phone'] ?? '',
                '{{vehicle_type}}' => is_array($vt) ? $vt['name'] : '',
            ]);
        }

        $this->logActivity('admin', $me['id'], 'booking_driver_assigned',
            ['booking_id' => $id, 'driver_id' => $driverId]);

        echo utilities::apiMessage('Driver assigned successfully.', 200);
    }

    // ── POST /admin/bookings/:id/reassign ─────────────────────────────────────
    public function reassign(string $id): void
    {
        $me          = BaseController::$authAdmin;
        $id          = $this->normalizeId($id);
        $newDriverId = $this->str('driver_id');
        $reason      = $this->str('reason', 'Reassigned by admin');

        if ($newDriverId === '') {
            echo utilities::apiMessage('driver_id is required.', 422);
            return;
        }

        $booking = $this->getall('bookings', 'id = ?', [$id]);
        if (!is_array($booking)) { echo utilities::apiMessage('Booking not found.', 404); return; }

        $prevDriverId = $booking['driver_id'];

        $this->update('bookings', ['status' => 'assigned', 'driver_id' => $newDriverId], "id = '$id'");
        $this->recordStatusChange($id, $booking['status'], 'assigned', 'admin', $me['id'], "Reassigned: $reason");

        // Notify previous driver
        if ($prevDriverId && $prevDriverId !== $newDriverId) {
            $this->notify('driver', $prevDriverId, 'Job Reassigned',
                'This booking has been reassigned to another driver.', 'booking_cancelled', $id);
        }

        // Notify new driver
        $this->notify('driver', $newDriverId, 'New Job Assigned',
            "You have been assigned a new {$booking['booking_type']} booking.", 'driver_assigned', $id);

        $this->logActivity('admin', $me['id'], 'booking_reassigned',
            ['booking_id' => $id, 'from' => $prevDriverId, 'to' => $newDriverId]);

        echo utilities::apiMessage('Driver reassigned successfully.', 200);
    }

    // ── POST /admin/bookings/:id/cancel ───────────────────────────────────────
    public function cancel(string $id): void
    {
        $me      = BaseController::$authAdmin;
        $id      = $this->normalizeId($id);
        $reason  = $this->str('reason', 'Cancelled by admin');
        $booking = $this->getall('bookings', 'id = ?', [$id]);

        if (!is_array($booking)) { echo utilities::apiMessage('Booking not found.', 404); return; }
        if (in_array($booking['status'], ['completed', 'cancelled'])) {
            echo utilities::apiMessage("Booking is already {$booking['status']}.", 409);
            return;
        }

        $this->update('bookings', [
            'status'              => 'cancelled',
            'cancelled_by_role'   => 'admin',
            'cancelled_by_id'     => $me['id'],
            'cancellation_reason' => $reason,
        ], "id = '$id'");

        $this->recordStatusChange($id, $booking['status'], 'cancelled', 'admin', $me['id'], $reason);

        $this->notify('customer', $booking['customer_id'], 'Booking Cancelled',
            "Your booking has been cancelled. Reason: $reason", 'booking_cancelled', $id);

        if ($booking['driver_id']) {
            $this->notify('driver', $booking['driver_id'], 'Booking Cancelled',
                'A booking assigned to you has been cancelled by admin.', 'booking_cancelled', $id);
        }

        // Email customer: booking cancelled
        $customer = $this->getall('users', 'id = ?', [$booking['customer_id']], 'name, email');
        if (is_array($customer) && !empty($customer['email'])) {
            $this->sendTemplateEmail('booking_cancelled', $customer['email'], $customer['name'], [
                '{{customer_name}}'       => $customer['name'],
                '{{booking_code}}'        => $booking['booking_code'] ?? $id,
                '{{cancellation_reason}}' => $reason,
            ]);
        }

        $this->logActivity('admin', $me['id'], 'booking_cancelled', ['booking_id' => $id]);

        echo utilities::apiMessage('Booking cancelled.', 200);
    }

    // ── POST /admin/bookings/:id/deassign ────────────────────────────────────
    public function deassign(string $id): void
    {
        $me      = BaseController::$authAdmin;
        $id      = $this->normalizeId($id);
        $booking = $this->getall('bookings', 'id = ?', [$id]);

        if (!is_array($booking)) { echo utilities::apiMessage('Booking not found.', 404); return; }

        if ($booking['status'] !== 'assigned') {
            echo utilities::apiMessage("Cannot deassign a driver from a booking in '{$booking['status']}' status.", 409);
            return;
        }

        $prevDriverId = $booking['driver_id'];

        $this->update('bookings', ['status' => 'pending', 'driver_id' => null], "id = '$id'");
        $this->recordStatusChange($id, 'assigned', 'pending', 'admin', $me['id'], 'Driver deassigned by admin');

        if ($prevDriverId) {
            $this->notify('driver', $prevDriverId, 'Job Removed',
                'A booking that was assigned to you has been unassigned by admin.', 'booking_cancelled', $id);
        }

        $this->logActivity('admin', $me['id'], 'booking_driver_deassigned',
            ['booking_id' => $id, 'driver_id' => $prevDriverId]);

        echo utilities::apiMessage('Driver deassigned. Booking is now pending.', 200);
    }

    // ── GET /admin/bookings/:id/track ─────────────────────────────────────────
    public function track(string $id): void
    {
        $id = $this->normalizeId($id);
        $booking = $this->getall('bookings', 'id = ?', [$id]);
        if (!is_array($booking)) { echo utilities::apiMessage('Booking not found.', 404); return; }

        $location = null;
        if ($booking['driver_id']) {
            $driver   = $this->getall('drivers', 'id = ?', [$booking['driver_id']],
                'id, name, phone, last_lat, last_lng, last_seen');
            $location = is_array($driver) ? [
                'driver'    => $driver,
                'lat'       => $driver['last_lat'],
                'lng'       => $driver['last_lng'],
                'last_seen' => $driver['last_seen'],
            ] : null;
        }

        echo utilities::apiMessage('Tracking info retrieved.', 200, [
            'booking_id' => $id,
            'status'     => $booking['status'],
            'location'   => $location,
        ]);
    }

    // ── GET /admin/notifications ──────────────────────────────────────────────
    public function notifications(): void
    {
        $me   = BaseController::$authAdmin;
        $stmt = $this->db->prepare(
            "SELECT * FROM notifications WHERE recipient_role = 'admin'
             ORDER BY created_at DESC LIMIT 100"
        );
        $stmt->execute();
        echo utilities::apiMessage('Notifications retrieved.', 200, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    // ── Private helpers ───────────────────────────────────────────────────────
    private function getStops(string $bookingId): array
    {
        $stmt = $this->db->prepare('SELECT * FROM booking_stops WHERE booking_id = ? ORDER BY stop_order');
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function getStatusHistory(string $bookingId): array
    {
        $stmt = $this->db->prepare('SELECT * FROM booking_status_history WHERE booking_id = ? ORDER BY created_at');
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
