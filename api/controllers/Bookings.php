<?php
require_once ROOT . 'functions/BaseController.php';

class Bookings extends BaseController
{
    // ── POST /bookings ────────────────────────────────────────────────────────
    public function create(): void
    {
        $me  = BaseController::$authUser;
        $err = $this->requireFields([
            'booking_type', 'vehicle_type_id',
            'pickup_address', 'pickup_lat', 'pickup_lng',
            'destination_address', 'destination_lat', 'destination_lng',
        ]);
        if ($err) { echo $err; return; }

        $bookingType = $this->str('booking_type');
        if (!in_array($bookingType, ['ride', 'delivery'])) {
            echo utilities::apiMessage("booking_type must be 'ride' or 'delivery'.", 422);
            return;
        }

        // One active ride per customer (delivery has no limit)
        if ($bookingType === 'ride') {
            $activeRide = $this->db->prepare(
                "SELECT id FROM bookings
                 WHERE customer_id = ? AND booking_type = 'ride'
                   AND status NOT IN ('completed','cancelled','paid')
                 LIMIT 1"
            );
            $activeRide->execute([$me['id']]);
            if ($activeRide->fetch()) {
                echo utilities::apiMessage(
                    'You already have an active ride. Please complete or cancel it before booking a new one.',
                    409
                );
                return;
            }
        }

        // Validate delivery fields
        if ($bookingType === 'delivery') {
            $dErr = $this->requireFields(['recipient_name', 'recipient_phone']);
            if ($dErr) { echo $dErr; return; }
        }

        $vtId = $this->str('vehicle_type_id');
        $vt   = $this->getall('vehicle_types', 'id = ? AND is_active = 1', [$vtId]);
        if (!is_array($vt)) {
            echo utilities::apiMessage('Invalid or inactive vehicle type.', 400);
            return;
        }

        // Parse stops
        $stopsRaw = $_POST['stops'] ?? [];
        if (is_string($stopsRaw)) $stopsRaw = json_decode($stopsRaw, true) ?? [];
        $stops    = is_array($stopsRaw) ? $stopsRaw : [];
        $numStops = count($stops);

        // Distance
        $pickupLat = $this->flt('pickup_lat');
        $pickupLng = $this->flt('pickup_lng');
        $destLat   = $this->flt('destination_lat');
        $destLng   = $this->flt('destination_lng');

        $calcMethod = $this->setting('calc_method', 'server');
        $distanceKm = 0.0;

        if ($calcMethod === 'app' && isset($_POST['distance_km'])) {
            $distanceKm = (float) $_POST['distance_km'];
        } else {
            $allPoints = array_merge(
                [['lat' => $pickupLat, 'lng' => $pickupLng]],
                array_map(fn($s) => ['lat' => (float)($s['lat'] ?? 0), 'lng' => (float)($s['lng'] ?? 0)], $stops),
                [['lat' => $destLat, 'lng' => $destLng]]
            );
            for ($i = 0; $i < count($allPoints) - 1; $i++) {
                $distanceKm += $this->haversine(
                    $allPoints[$i]['lat'], $allPoints[$i]['lng'],
                    $allPoints[$i + 1]['lat'], $allPoints[$i + 1]['lng']
                );
            }
            $distanceKm = round($distanceKm, 2);
        }

        $zoneId        = $this->getDefaultZoneId();
        $estimatedFare = $this->calculateFare($vtId, $zoneId, $distanceKm, $numStops);

        // Ensure pay_mode_snapshot is always a valid ENUM value
        $rawPayMode = $this->setting('pay_mode', '');
        $payMode    = in_array($rawPayMode, ['pay_on_booking', 'pay_on_completion'])
                        ? $rawPayMode
                        : 'pay_on_booking';

        $id   = utilities::genID('BKG_', 10);
        $code = strtoupper(substr(md5($id . time()), 0, 8));

        // Build the insert array — only columns that exist in every DB version
        $insertData = [
            'id'                  => $id,
            'booking_code'        => $code,
            'customer_id'         => $me['id'],
            'vehicle_type_id'     => $vtId,
            'booking_type'        => $bookingType,
            'status'              => 'pending',
            'pickup_address'      => $this->str('pickup_address'),
            'pickup_lat'          => $pickupLat,
            'pickup_lng'          => $pickupLng,
            'destination_address' => $this->str('destination_address'),
            'destination_lat'     => $destLat,
            'destination_lng'     => $destLng,
            'estimated_fare'      => $estimatedFare,
            'distance_km'         => $distanceKm,
            'num_stops'           => $numStops,
            'payment_status'      => 'pending',
            'pay_mode_snapshot'   => $payMode,
        ];

        // Optional nullable columns
        if ($zoneId)                          $insertData['zone_id'] = $zoneId;
        $notes = $this->str('notes');
        if ($notes !== '')                    $insertData['notes'] = $notes;

        // Delivery-only fields
        if ($bookingType === 'delivery') {
            $insertData['recipient_name']  = $this->str('recipient_name');
            $insertData['recipient_phone'] = $this->str('recipient_phone');
            $pkg = $this->str('package_description');
            if ($pkg !== '') $insertData['package_description'] = $pkg;
            $size = $this->str('package_size');
            if (in_array($size, ['small', 'medium', 'large'])) $insertData['package_size'] = $size;
        }

        // Insert using raw PDO to get a real error if it fails
        try {
            $cols   = implode(', ', array_map(fn($k) => "`$k`", array_keys($insertData)));
            $marks  = implode(', ', array_fill(0, count($insertData), '?'));
            $stmt   = $this->db->prepare("INSERT INTO bookings ($cols) VALUES ($marks)");
            $stmt->execute(array_values($insertData));
        } catch (\Throwable $e) {
            echo utilities::apiMessage('Failed to create booking: ' . $e->getMessage(), 500);
            return;
        }

        // Insert stops
        foreach ($stops as $i => $stop) {
            $this->quick_insert('booking_stops', [
                'id'         => utilities::genID('STP_', 10),
                'booking_id' => $id,
                'stop_order' => $i + 1,
                'address'    => $stop['address'] ?? '',
                'lat'        => (float)($stop['lat'] ?? 0),
                'lng'        => (float)($stop['lng'] ?? 0),
                'status'     => 'pending',
            ]);
        }

        $this->recordStatusChange($id, null, 'pending', 'system');
        $this->logActivity('customer', $me['id'], 'booking_created', ['booking_id' => $id]);

        // Auto-assign nearest driver matching the chosen vehicle type
        $assignedDriver = null;
        $autoAssign = $this->setting('auto_assign_enabled', '1') === '1';
        if ($autoAssign) {
            $driver = $this->findNearestDriver($pickupLat, $pickupLng, $vtId);
            if ($driver) {
                $this->assignDriver($id, $driver['id'], $insertData);
                $assignedDriver = [
                    'id'   => $driver['id'],
                    'name' => $driver['name'],
                    'phone'=> $driver['phone'],
                ];
                $insertData['status']    = 'assigned';
                $insertData['driver_id'] = $driver['id'];
            }
        }

        // Return the data we already have — no re-fetch needed
        echo utilities::apiMessage('Booking created successfully.', 201, array_merge($insertData, [
            'driver'         => $assignedDriver,
            'vehicle_type'   => $vt['name'] ?? null,
            'created_at'     => date('Y-m-d H:i:s'),
        ]));
    }

    // ── GET /bookings ─────────────────────────────────────────────────────────
    public function index(): void
    {
        $me      = BaseController::$authUser;
        $status  = $this->query('status', '');
        $page    = max(1, (int) $this->query('page', 1));
        $perPage = 20;
        $offset  = ($page - 1) * $perPage;

        $where  = $status ? "customer_id = ? AND status = ?" : "customer_id = ?";
        $params = $status ? [$me['id'], $status] : [$me['id']];

        $stmt = $this->db->prepare(
            "SELECT b.*, vt.name AS vehicle_type_name,
                    d.name AS driver_name, d.phone AS driver_phone
             FROM bookings b
             LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
             LEFT JOIN drivers d ON d.id = b.driver_id
             WHERE b.customer_id = ?" . ($status ? " AND b.status = ?" : "")
             . " ORDER BY b.created_at DESC LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute($params);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Bookings retrieved.', 200, $bookings);
    }

    // ── GET /bookings/:id ─────────────────────────────────────────────────────
    public function show(string $id): void
    {
        $me = BaseController::$authUser;

        try {
            $stmt = $this->db->prepare("
                SELECT b.*,
                       vt.name        AS vehicle_type_name,
                       d.name         AS driver_name,
                       d.phone        AS driver_phone,
                       d.photo        AS driver_avatar,
                       d.rating       AS driver_rating,
                       v.plate_number AS vehicle_plate,
                       v.color        AS vehicle_color
                FROM bookings b
                LEFT JOIN vehicle_types vt ON vt.id = b.vehicle_type_id
                LEFT JOIN drivers d        ON d.id  = b.driver_id
                LEFT JOIN vehicles v       ON v.id  = d.vehicle_id
                WHERE b.id = ? AND b.customer_id = ?
            ");
            $stmt->execute([$id, $me['id']]);
            $booking = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$booking) {
                echo utilities::apiMessage('Booking not found.', 404);
                return;
            }

            $booking['stops'] = $this->getStops($id);

            // Payments may not exist yet — guard against missing table
            try {
                $booking['payment'] = $this->getall('payments', 'booking_id = ?', [$id]);
            } catch (\Throwable $e) {
                $booking['payment'] = null;
            }

            echo utilities::apiMessage('Booking retrieved.', 200, $booking);

        } catch (\Throwable $e) {
            echo utilities::apiMessage('Failed to retrieve booking: ' . $e->getMessage(), 500);
        }
    }

    // ── POST /bookings/:id/cancel ─────────────────────────────────────────────
    public function cancel(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if (in_array($booking['status'], ['completed', 'cancelled'])) {
            echo utilities::apiMessage("Booking is already {$booking['status']}.", 409);
            return;
        }

        // Check cancellation permission
        $allowedBy = $this->setting('cancellation_allowed_by', 'customer');
        if (!in_array($allowedBy, ['customer', 'both'])) {
            echo utilities::apiMessage('Cancellation by customers is not allowed.', 403);
            return;
        }

        // Check cancellation window
        $windowMin = (int) $this->setting('cancellation_window_minutes', '5');
        $createdAt = strtotime($booking['created_at']);
        if ($windowMin > 0 && (time() - $createdAt) > ($windowMin * 60)) {
            echo utilities::apiMessage("Cancellation window of $windowMin minutes has passed.", 403);
            return;
        }

        // Cancellation fee
        $fee = 0.0;
        if ($this->setting('cancellation_fee_enabled', '0') === '1') {
            $onlyAfterAssign = $this->setting('cancellation_fee_after_assignment', '0') === '1';
            if (!$onlyAfterAssign || $booking['driver_id']) {
                $fee = (float) $this->setting('cancellation_fee_amount', '0');
            }
        }

        $reason = $this->str('reason', 'Cancelled by customer');
        $this->update('bookings', [
            'status'                   => 'cancelled',
            'cancelled_by_role'        => 'customer',
            'cancelled_by_id'          => $me['id'],
            'cancellation_reason'      => $reason,
            'cancellation_fee_charged' => $fee,
        ], "id = '$id'");

        $this->recordStatusChange($id, $booking['status'], 'cancelled', 'customer', $me['id'], $reason);

        if ($booking['driver_id']) {
            $this->notify('driver', $booking['driver_id'], 'Booking Cancelled',
                'Customer has cancelled the booking.', 'booking_cancelled', $id);
        }

        echo utilities::apiMessage('Booking cancelled.', 200, ['cancellation_fee' => $fee]);
    }

    // ── GET /bookings/:id/track ───────────────────────────────────────────────
    public function track(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if (!$booking['driver_id']) {
            echo utilities::apiMessage('No driver assigned yet.', 200, [
                'status'    => $booking['status'],
                'driver'    => null,
                'location'  => null,
            ]);
            return;
        }

        $driver = $this->getall('drivers', 'id = ?', [$booking['driver_id']],
            'id, name, phone, last_lat, last_lng, last_seen');

        echo utilities::apiMessage('Tracking info retrieved.', 200, [
            'status'   => $booking['status'],
            'driver'   => $driver,
            'location' => is_array($driver) ? [
                'lat'       => $driver['last_lat'],
                'lng'       => $driver['last_lng'],
                'last_seen' => $driver['last_seen'],
            ] : null,
        ]);
    }

    // ── POST /bookings/:id/confirm-delivery ───────────────────────────────────
    public function confirmDelivery(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if ($booking['booking_type'] !== 'delivery') {
            echo utilities::apiMessage('This action is only for delivery bookings.', 400);
            return;
        }

        if (!in_array($booking['status'], ['completed', 'payment_pending'])) {
            echo utilities::apiMessage("Cannot confirm delivery in '{$booking['status']}' status.", 409);
            return;
        }

        $this->logActivity('customer', $me['id'], 'delivery_confirmed', ['booking_id' => $id]);

        echo utilities::apiMessage('Delivery confirmed. Thank you!', 200);
    }

    // ── GET /notifications ────────────────────────────────────────────────────
    public function notifications(): void
    {
        $me   = BaseController::$authUser;
        $stmt = $this->db->prepare(
            "SELECT * FROM notifications WHERE recipient_role = 'customer' AND recipient_id = ?
             ORDER BY created_at DESC LIMIT 50"
        );
        $stmt->execute([$me['id']]);
        echo utilities::apiMessage('Notifications retrieved.', 200, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function markNotificationRead(string $notifId): void
    {
        $me = BaseController::$authUser;
        $this->update('notifications', ['is_read' => 1],
            "id = '$notifId' AND recipient_id = '{$me['id']}' AND recipient_role = 'customer'");
        echo utilities::apiMessage('Marked as read.', 200);
    }

    public function markAllNotificationsRead(): void
    {
        $me = BaseController::$authUser;
        $this->db->prepare(
            "UPDATE notifications SET is_read = 1 WHERE recipient_role = 'customer' AND recipient_id = ?"
        )->execute([$me['id']]);
        echo utilities::apiMessage('All notifications marked as read.', 200);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function getStops(string $bookingId): array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM booking_stops WHERE booking_id = ? ORDER BY stop_order ASC'
        );
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function assignDriver(string $bookingId, string $driverId, array $booking): void
    {
        $prev = $booking['status'] ?? 'pending';
        $this->update('bookings', ['status' => 'assigned', 'driver_id' => $driverId], "id = '$bookingId'");
        $this->recordStatusChange($bookingId, $prev, 'assigned', 'system', null, 'Auto-assigned');
        $this->notify('driver', $driverId, 'New Job Assigned',
            "You have been assigned a new {$booking['booking_type']} booking.", 'driver_assigned', $bookingId);
        $this->notify('customer', $booking['customer_id'], 'Driver Found',
            'A driver has been assigned to your booking.', 'driver_assigned', $bookingId);
    }

    // ── PUT /bookings/:id/payment-method ──────────────────────────────────────
    public function updatePaymentMethod(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if (in_array($booking['status'], ['completed', 'cancelled', 'paid'])) {
            echo utilities::apiMessage("Cannot change payment method for a {$booking['status']} booking.", 409);
            return;
        }

        $method = $this->str('payment_method');
        $allowed = ['cash', 'bank_transfer', 'flutterwave'];
        if (!in_array($method, $allowed)) {
            echo utilities::apiMessage("Invalid payment method. Must be one of: " . implode(', ', $allowed), 422);
            return;
        }

        $this->update('bookings', ['payment_method' => $method], "id = '$id'");

        if ($booking['driver_id']) {
            $this->notify('driver', $booking['driver_id'], 'Payment Method Updated',
                "Customer changed payment method to $method.", 'payment_method_changed', $id);
        }

        echo utilities::apiMessage('Payment method updated.', 200, ['payment_method' => $method]);
    }

    // ── POST /bookings/:id/rate ───────────────────────────────────────────────
    public function rateDriver(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        if (!in_array($booking['status'], ['completed', 'paid', 'payment_pending'])) {
            echo utilities::apiMessage("Can only rate a completed trip.", 409);
            return;
        }

        if ($booking['customer_rating']) {
            echo utilities::apiMessage('You have already rated this trip.', 409);
            return;
        }

        $rating  = (int) ($_POST['rating'] ?? 0);
        $comment = $this->str('comment', '');

        if ($rating < 1 || $rating > 5) {
            echo utilities::apiMessage('Rating must be between 1 and 5.', 422);
            return;
        }

        $this->update('bookings', [
            'customer_rating'  => $rating,
            'customer_comment' => $comment,
        ], "id = '$id'");

        // Recalculate driver's average rating
        if ($booking['driver_id']) {
            $stmt = $this->db->prepare(
                "SELECT AVG(customer_rating) FROM bookings
                 WHERE driver_id = ? AND customer_rating IS NOT NULL"
            );
            $stmt->execute([$booking['driver_id']]);
            $avg = round((float) $stmt->fetchColumn(), 1);
            $this->update('drivers', ['rating' => $avg], "id = '{$booking['driver_id']}'");

            $this->notify('driver', $booking['driver_id'], 'New Rating Received',
                "You received a $rating-star rating.", 'rating_received', $id);
        }

        echo utilities::apiMessage('Rating submitted. Thank you!', 200, ['new_driver_rating' => $avg ?? 0]);
    }

    // ── PUT /bookings/:id/cancel-before-start (cancel if not yet in_progress) ─
    public function cancelIfNotStarted(string $id): void
    {
        $me      = BaseController::$authUser;
        $booking = $this->getall('bookings', 'id = ? AND customer_id = ?', [$id, $me['id']]);

        if (!is_array($booking)) {
            echo utilities::apiMessage('Booking not found.', 404);
            return;
        }

        $cancellable = ['pending', 'assigned', 'accepted', 'arrived'];
        if (!in_array($booking['status'], $cancellable)) {
            echo utilities::apiMessage("Cannot cancel a booking in '{$booking['status']}' status.", 409);
            return;
        }

        $reason = $this->str('reason', 'Cancelled by customer');
        $this->update('bookings', [
            'status'              => 'cancelled',
            'cancelled_by_role'   => 'customer',
            'cancelled_by_id'     => $me['id'],
            'cancellation_reason' => $reason,
        ], "id = '$id'");

        $this->recordStatusChange($id, $booking['status'], 'cancelled', 'customer', $me['id'], $reason);

        if ($booking['driver_id']) {
            $this->notify('driver', $booking['driver_id'], 'Booking Cancelled',
                'Customer has cancelled the booking.', 'booking_cancelled', $id);
        }

        echo utilities::apiMessage('Booking cancelled.', 200);
    }
}
