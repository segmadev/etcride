<?php
require_once ROOT . 'functions/helper.php';

/**
 * BaseController
 * All API controllers extend this class.
 * Provides: auth state, input helpers, DB shortcuts, fare calc, Haversine, notifications, activity logging.
 */
class BaseController extends helper
{
    // ── Shared auth state (set by auth guards, read by controllers) ───────────
    protected static ?array $authUser   = null;  // logged-in customer
    protected static ?array $authDriver = null;  // logged-in driver
    protected static ?array $authAdmin  = null;  // logged-in admin

    private array $columnExistsCache = [];

    // ── Input helpers ─────────────────────────────────────────────────────────

    /** Raw POST value or default */
    protected function input(string $key, mixed $default = null): mixed
    {
        return $_POST[$key] ?? $default;
    }

    /** Sanitised string from POST */
    protected function str(string $key, string $default = ''): string
    {
        return isset($_POST[$key]) ? trim(htmlspecialchars((string) $_POST[$key])) : $default;
    }

    /** Float from POST */
    protected function flt(string $key, float $default = 0.0): float
    {
        return isset($_POST[$key]) ? (float) $_POST[$key] : $default;
    }

    /** Int from POST */
    protected function int(string $key, int $default = 0): int
    {
        return isset($_POST[$key]) ? (int) $_POST[$key] : $default;
    }

    /** Query-string (URL param) value */
    protected function query(string $key, mixed $default = null): mixed
    {
        return $_GET[$key] ?? $default;
    }

    /**
     * Validate required fields.
     * Returns an error response string if any field is missing, otherwise null.
     */
    protected function requireFields(array $fields): ?string
    {
        $missing = [];
        foreach ($fields as $field) {
            $val = trim((string) ($_POST[$field] ?? ''));
            if ($val === '') {
                $missing[] = str_replace('_', ' ', $field);
            }
        }
        if (!empty($missing)) {
            return utilities::apiMessage(
                'The following fields are required: ' . implode(', ', $missing),
                422
            );
        }
        return null;
    }

    // ── Settings helper ───────────────────────────────────────────────────────

    /** Read a value from the settings table */
    protected function setting(string $key, string $default = ''): string
    {
        // .env vars take priority (map snake_key → UPPER_KEY)
        $envKey = strtoupper($key);
        if (!empty($_ENV[$envKey])) return $_ENV[$envKey];

        $row = $this->getall('settings', 'config_key = ?', [$key]);
        return is_array($row) ? (string) $row['config_value'] : $default;
    }

    protected function tableHasColumn(string $table, string $column): bool
    {
        $k = $table . '.' . $column;
        if (isset($this->columnExistsCache[$k])) return (bool) $this->columnExistsCache[$k];
        $stmt = $this->db->prepare(
            'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
        );
        $stmt->execute([$table, $column]);
        $exists = ((int) $stmt->fetchColumn()) > 0;
        $this->columnExistsCache[$k] = $exists;
        return $exists;
    }

    protected function uploadUrl(string $folder, ?string $file): ?string
    {
        if (!$file) {
            return null;
        }

        $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $scriptName = (string) ($_SERVER['SCRIPT_NAME'] ?? '/api/index.php');
        $apiBase = trim(str_replace('\\', '/', dirname($scriptName)), '/');
        // When the docroot IS the api/ folder (e.g. `php -S host:port -t api/` for
        // local dev), dirname(SCRIPT_NAME) resolves to '' — uploads are already
        // served from the docroot, so no extra path segment should be added.
        // Only XAMPP/Apache deployments where api/ is a real subfolder (e.g.
        // /etcride/api/index.php) produce a non-empty apiBase here.
        if ($apiBase === '.') {
            $apiBase = '';
        }

        // Routed through FrontContent@serveUpload (not the raw /uploads/ static
        // path) so Access-Control-Allow-Origin is always applied — see that
        // method for why direct static serving can't be relied on for CORS.
        // Filename is a query param, not a path segment — PHP's built-in dev
        // server short-circuits any URL path ending in a recognized extension
        // straight to its own static handler without ever invoking PHP.
        $path = '/' . $apiBase . '/files/' . trim($folder, '/');
        $path = preg_replace('#/+#', '/', $path); // guard against any double slashes

        return $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . $path
             . '?file=' . rawurlencode($file);
    }

    protected function computeRouteSnapshot(
        float $originLat,
        float $originLng,
        float $destLat,
        float $destLng,
        array $stops = []
    ): ?array {
        $apiKey = $this->setting('google_maps_server_key', '');
        if ($apiKey === '') $apiKey = $this->setting('google_maps_api_key', '');
        if ($apiKey === '') return null;

        $waypoints = [];
        foreach ($stops as $s) {
            $lat = $s['lat'] ?? null;
            $lng = $s['lng'] ?? null;
            if (!is_numeric($lat) || !is_numeric($lng)) continue;
            $waypoints[] = ((float) $lat) . ',' . ((float) $lng);
        }

        $q = [
            'origin' => $originLat . ',' . $originLng,
            'destination' => $destLat . ',' . $destLng,
            'mode' => 'driving',
            'overview' => 'full',
            'key' => $apiKey,
        ];
        if (!empty($waypoints)) $q['waypoints'] = implode('|', $waypoints);

        $url = 'https://maps.googleapis.com/maps/api/directions/json?' . http_build_query($q);
        $ch2 = curl_init($url);
        curl_setopt_array($ch2, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 12,
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $resp2 = curl_exec($ch2);
        $err2  = $resp2 === false ? curl_error($ch2) : null;
        curl_close($ch2);
        if ($err2 !== null || $resp2 === false) return null;

        $data2 = json_decode($resp2, true) ?? [];
        if (($data2['status'] ?? '') !== 'OK') return null;
        $r2 = ($data2['routes'][0] ?? null);
        if (!is_array($r2)) return null;
        $poly2 = $r2['overview_polyline']['points'] ?? '';
        if (!is_string($poly2) || $poly2 === '') return null;

        $distanceMeters2 = 0;
        $durationSeconds2 = 0;
        $legs = ($r2['legs'] ?? []);
        if (is_array($legs)) {
            foreach ($legs as $leg) {
                $distanceMeters2 += (int) (($leg['distance']['value'] ?? 0));
                $durationSeconds2 += (int) (($leg['duration']['value'] ?? 0));
            }
        }

        return [
            'polyline' => $poly2,
            'distance_meters' => $distanceMeters2,
            'duration_seconds' => $durationSeconds2,
        ];
    }

    // ── Notification helper ───────────────────────────────────────────────────

    /**
     * Save a notification record and optionally dispatch FCM push.
     */
    protected function notify(
        string  $role,
        string  $recipientId,
        string  $title,
        string  $body,
        string  $type,
        ?string $bookingId = null
    ): void {
        $this->quick_insert('notifications', [
            'id'             => utilities::genID('NTF_', 12),
            'recipient_role' => $role,
            'recipient_id'   => $recipientId,
            'title'          => $title,
            'body'           => $body,
            'type'           => $type,
            'booking_id'     => $bookingId,
            'is_read'        => 0,
        ]);

        if ($this->setting('fcm_enabled', '1') === '1') {
            $this->dispatchFCM($role, $recipientId, $title, $body, $type, $bookingId);
        }
    }

    /**
     * Send FCM push via the HTTP v1 API (replaces deprecated Legacy API).
     * Requires FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_PATH in .env.
     */
    private function dispatchFCM(
        string  $role,
        string  $recipientId,
        string  $title,
        string  $body,
        string  $type,
        ?string $bookingId
    ): void {
        $table = match ($role) {
            'customer' => 'users',
            'driver'   => 'drivers',
            default    => null,
        };
        if (!$table) return;

        $rec = $this->getall($table, 'id = ?', [$recipientId], 'fcm_token');
        if (!is_array($rec) || empty($rec['fcm_token'])) return;

        $projectId = $_ENV['FCM_PROJECT_ID'] ?? '';
        if (empty($projectId)) return;

        $accessToken = $this->getFcmAccessToken();
        if (!$accessToken) return;

        $payload = json_encode([
            'message' => [
                'token'        => $rec['fcm_token'],
                'notification' => ['title' => $title, 'body' => $body],
                'data'         => [
                    'type'       => $type,
                    'booking_id' => $bookingId ?? '',
                ],
                'android' => [
                    'priority'     => 'high',
                    'notification' => ['channel_id' => 'etcride_main'],
                ],
                'apns' => [
                    'headers' => ['apns-priority' => '10'],
                    'payload' => ['aps' => ['sound' => 'default']],
                ],
            ],
        ]);

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
        $ch  = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_TIMEOUT    => 5,
        ]);
        $result = curl_exec($ch);
        curl_close($ch);

        if ($result && str_contains((string) $result, '"error"')) {
            error_log('[FCM] dispatch failed for ' . $role . '/' . $recipientId . ': ' . $result);
        }
    }

    /**
     * Get a valid OAuth2 access token for the FCM HTTP v1 API.
     * Signs a JWT with the service account private key, exchanges it at
     * Google's token endpoint, and caches the result for up to 55 minutes.
     */
    private function getFcmAccessToken(): ?string
    {
        $cacheFile = sys_get_temp_dir() . '/etcride_fcm_token.json';

        // Return cached token if still valid (at least 60 s left)
        if (file_exists($cacheFile)) {
            $cached = json_decode((string) file_get_contents($cacheFile), true);
            if (is_array($cached) && ($cached['expires'] ?? 0) > time() + 60) {
                return $cached['token'];
            }
        }

        $saPath = $_ENV['FCM_SERVICE_ACCOUNT_PATH'] ?? '';
        if (empty($saPath) || !file_exists($saPath)) {
            error_log('[FCM] Service account file not found: ' . $saPath);
            return null;
        }

        $sa = json_decode((string) file_get_contents($saPath), true);
        if (!is_array($sa) || empty($sa['private_key']) || empty($sa['client_email'])) {
            error_log('[FCM] Invalid service account JSON.');
            return null;
        }

        $now    = time();
        $header = $this->b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = $this->b64url(json_encode([
            'iss'   => $sa['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud'   => 'https://oauth2.googleapis.com/token',
            'iat'   => $now,
            'exp'   => $now + 3600,
        ]));

        $signingInput = "{$header}.{$claims}";
        if (!openssl_sign($signingInput, $sig, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
            error_log('[FCM] Failed to sign JWT.');
            return null;
        }
        $jwt = "{$signingInput}." . $this->b64url($sig);

        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POSTFIELDS     => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ]),
            CURLOPT_TIMEOUT => 10,
        ]);
        $response = (string) curl_exec($ch);
        curl_close($ch);

        $data  = json_decode($response, true);
        $token = $data['access_token'] ?? null;
        if (!$token) {
            error_log('[FCM] Token exchange failed: ' . $response);
            return null;
        }

        file_put_contents($cacheFile, json_encode([
            'token'   => $token,
            'expires' => $now + (int) ($data['expires_in'] ?? 3600),
        ]));

        return $token;
    }

    private function b64url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    // ── Activity log ──────────────────────────────────────────────────────────

    protected function logActivity(string $role, ?string $actorId, string $action, array $meta = []): void
    {
        $this->quick_insert('activities', [
            'actor_role' => $role,
            'actor_id'   => $actorId,
            'action'     => $action,
            'ip'         => $_SERVER['REMOTE_ADDR'] ?? '',
            'device'     => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
            'meta'       => !empty($meta) ? json_encode($meta) : null,
        ]);
    }

    // ── Booking status history ────────────────────────────────────────────────

    protected function recordStatusChange(
        string  $bookingId,
        ?string $fromStatus,
        string  $toStatus,
        string  $byRole,
        ?string $byId   = null,
        ?string $note   = null
    ): void {
        $this->quick_insert('booking_status_history', [
            'id'              => utilities::genID('BSH_', 12),
            'booking_id'      => $bookingId,
            'from_status'     => $fromStatus,
            'to_status'       => $toStatus,
            'changed_by_role' => $byRole,
            'changed_by_id'   => $byId,
            'note'            => $note,
        ]);
    }

    // ── Haversine distance (km) ───────────────────────────────────────────────

    protected function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $R    = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a    = sin($dLat / 2) ** 2
              + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        return $R * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    // ── Driver ETA calculation ───────────────────────────────────────────────

    /**
     * Calculate driver ETA to pickup using Haversine × 1.3 road factor ÷ avg speed.
     * Returns ['driver_distance_km' => float, 'driver_eta_minutes' => int]
     */
    protected function calculateDriverEta(
        float $driverLat, float $driverLng,
        float $pickupLat, float $pickupLng
    ): array {
        $distKm      = $this->haversine($driverLat, $driverLng, $pickupLat, $pickupLng);
        $roadDistKm  = $distKm * 1.3;
        $avgSpeedKmh = (float) $this->setting('driver_avg_speed_kmh', '30');
        $etaMins     = $avgSpeedKmh > 0 ? (int) round($roadDistKm / $avgSpeedKmh * 60) : 0;
        return [
            'driver_distance_km' => round($distKm, 2),
            'driver_eta_minutes' => max(1, $etaMins),
        ];
    }

    /**
     * Find available drivers in OTHER vehicle types near a given location.
     * Returns array of vehicle type rows, each with an 'available_count'.
     */
    protected function findAlternativeVehicleTypes(
        float  $lat,
        float  $lng,
        string $excludeVehicleTypeId
    ): array {
        $radius = (float) $this->setting('driver_search_radius_km', '50');

        $sql = "
            SELECT vt.id, vt.name, vt.icon, COUNT(DISTINCT d.id) AS available_count
            FROM vehicle_types vt
            INNER JOIN vehicles v  ON v.vehicle_type_id = vt.id
            INNER JOIN drivers  d  ON d.vehicle_id = v.id
                AND d.is_online  = 1
                AND d.is_active  = 1
                AND d.last_lat   IS NOT NULL
                AND d.last_lng   IS NOT NULL
                AND (6371 * ACOS(
                    LEAST(1.0, COS(RADIANS(:lat)) * COS(RADIANS(d.last_lat))
                    * COS(RADIANS(d.last_lng) - RADIANS(:lng))
                    + SIN(RADIANS(:lat)) * SIN(RADIANS(d.last_lat)))
                )) <= :radius
            WHERE vt.is_active = 1
              AND vt.id <> :exclude_id
              AND d.id NOT IN (
                  SELECT b.driver_id FROM bookings b
                  WHERE b.driver_id IS NOT NULL
                    AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
              )
            GROUP BY vt.id, vt.name, vt.icon
            HAVING available_count > 0
            ORDER BY available_count DESC
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':lat'        => $lat,
            ':lng'        => $lng,
            ':radius'     => $radius,
            ':exclude_id' => $excludeVehicleTypeId,
        ]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }

    // ── Fare calculation ──────────────────────────────────────────────────────

    /**
     * Calculate fare using zone pricing (preferred) or vehicle type default pricing.
     * Formula: base_fare + (distance_km × per_km_rate) + (num_stops × per_stop_fee)
     *          + (duration_minutes × time_fare_per_minute)  [when time_fare_enabled = 1]
     *
     * @param float|null $durationMinutes  Actual trip duration in minutes (pass null for estimates)
     */
    protected function calculateFare(
        string  $vehicleTypeId,
        ?string $zoneId,
        float   $distanceKm,
        int     $numStops,
        ?float  $durationMinutes = null,
        string  $bookingType = 'ride'
    ): float {
        $pricing = null;

        if ($zoneId) {
            $pricing = $this->getall(
                'zone_pricing',
                'zone_id = ? AND vehicle_type_id = ? AND is_active = 1',
                [$zoneId, $vehicleTypeId]
            );
        }

        if (!is_array($pricing)) {
            $pricing = $this->getall('vehicle_types', 'id = ? AND is_active = 1', [$vehicleTypeId]);
        }

        if (!is_array($pricing)) return 0.00;

        $isDelivery = $bookingType === 'delivery';

        // Delivery: distance-only fare (no per-stop fee, no time component)
        $fare = (float) $pricing['base_fare']
              + ($distanceKm * (float) $pricing['per_km_rate'])
              + ($isDelivery ? 0.0 : $numStops * (float) $pricing['per_stop_fee']);

        // ── Time-based component (rides only) ──────────────────────────────────
        if (!$isDelivery && $durationMinutes !== null && $durationMinutes > 0
            && $this->setting('time_fare_enabled', '0') === '1'
        ) {
            $perMinute = (float) $this->setting('time_fare_per_minute', '5');
            $fare += $durationMinutes * $perMinute;
        }

        $minFare = (float) $this->setting('min_booking_fare', '200');

        return max(round($fare, 2), $minFare);
    }

    // ── Auto-assign: assign helper (shared across Bookings + Jobs) ───────────

    /**
     * Assign a driver to a booking: updates status, records history, notifies both parties.
     *
     * @param string $bookingId  The booking to assign
     * @param string $driverId   The driver to assign
     * @param array  $booking    Booking row (needs at least 'status', 'customer_id', 'booking_type')
     */
    protected function assignDriver(string $bookingId, string $driverId, array $booking): void
    {
        $prev = $booking['status'] ?? 'pending';
        $this->update('bookings', ['status' => 'assigned', 'driver_id' => $driverId], "id = '$bookingId'");
        $this->recordStatusChange($bookingId, $prev, 'assigned', 'system', null, 'Auto-assigned');
        $this->notify(
            'driver', $driverId,
            'New Job Assigned',
            "You have been assigned a new {$booking['booking_type']} booking.",
            'driver_assigned', $bookingId
        );
        $this->notify(
            'customer', $booking['customer_id'],
            'Driver Found',
            'A driver has been assigned to your booking.',
            'driver_assigned', $bookingId
        );
    }

    // ── Auto-assign: find nearest free driver ────────────────────────────────

    /**
     * Find the nearest online, available (not on an active booking) driver.
     * Returns driver row or null.
     */
    protected function findNearestDriver(float $lat, float $lng, string $vehicleTypeId): ?array
    {
        $radius = (float) $this->setting('driver_search_radius_km', '50');

        $sql = "
            SELECT d.id, d.name, d.phone, d.vehicle_id, d.fcm_token,
                   d.last_lat, d.last_lng,
                   (6371 * ACOS(
                       LEAST(1.0, COS(RADIANS(:lat)) * COS(RADIANS(d.last_lat))
                       * COS(RADIANS(d.last_lng) - RADIANS(:lng))
                       + SIN(RADIANS(:lat)) * SIN(RADIANS(d.last_lat)))
                   )) AS distance_km
            FROM drivers d
            INNER JOIN vehicles v ON v.id = d.vehicle_id AND v.vehicle_type_id = :vtid
            WHERE d.is_online  = 1
              AND d.is_active  = 1
              AND d.vehicle_id IS NOT NULL
              AND d.last_lat   IS NOT NULL
              AND d.last_lng   IS NOT NULL
              AND d.id NOT IN (
                  SELECT b.driver_id FROM bookings b
                  WHERE b.driver_id IS NOT NULL
                    AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
              )
            HAVING distance_km <= :radius
            ORDER BY distance_km ASC
            LIMIT 1
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':lat' => $lat, ':lng' => $lng, ':radius' => $radius, ':vtid' => $vehicleTypeId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }

    /**
     * Like findNearestDriver but excludes specific driver IDs (e.g., those who already rejected).
     * Uses positional params so the exclusion list can be dynamically spliced in.
     */
    protected function findNearestDriverExcluding(
        float  $lat,
        float  $lng,
        string $vehicleTypeId,
        array  $excludeDriverIds = []
    ): ?array {
        $radius = (float) $this->setting('driver_search_radius_km', '50');

        // Build the exclusion clause dynamically
        $excludeClause = '';
        if (!empty($excludeDriverIds)) {
            $marks = implode(',', array_fill(0, count($excludeDriverIds), '?'));
            $excludeClause = "AND d.id NOT IN ($marks)";
        }

        $sql = "
            SELECT d.id, d.name, d.phone, d.vehicle_id, d.fcm_token,
                   d.last_lat, d.last_lng,
                   (6371 * ACOS(
                       LEAST(1.0, COS(RADIANS(?)) * COS(RADIANS(d.last_lat))
                       * COS(RADIANS(d.last_lng) - RADIANS(?))
                       + SIN(RADIANS(?)) * SIN(RADIANS(d.last_lat)))
                   )) AS distance_km
            FROM drivers d
            INNER JOIN vehicles v ON v.id = d.vehicle_id AND v.vehicle_type_id = ?
            WHERE d.is_online  = 1
              AND d.is_active  = 1
              AND d.vehicle_id IS NOT NULL
              AND d.last_lat   IS NOT NULL
              AND d.last_lng   IS NOT NULL
              AND d.id NOT IN (
                  SELECT b.driver_id FROM bookings b
                  WHERE b.driver_id IS NOT NULL
                    AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
              )
              $excludeClause
            HAVING distance_km <= ?
            ORDER BY distance_km ASC
            LIMIT 1
        ";

        // Positional params: lat, lng, lat (ACOS reuse), vehicleTypeId, ...excludeIds, radius
        $params = array_merge([$lat, $lng, $lat, $vehicleTypeId], $excludeDriverIds, [$radius]);
        $stmt   = $this->db->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }

    protected function countAvailableDrivers(string $vehicleTypeId, float $lat, float $lng): int
    {
        $radius = (float) $this->setting('driver_search_radius_km', '50');

        $sql = "
            SELECT COUNT(*) FROM (
                SELECT d.id,
                       (6371 * ACOS(
                           LEAST(1.0, COS(RADIANS(:lat)) * COS(RADIANS(d.last_lat))
                           * COS(RADIANS(d.last_lng) - RADIANS(:lng))
                           + SIN(RADIANS(:lat)) * SIN(RADIANS(d.last_lat)))
                       )) AS distance_km
                FROM drivers d
                INNER JOIN vehicles v ON v.id = d.vehicle_id AND v.vehicle_type_id = :vtid
                WHERE d.is_online = 1
                  AND d.is_active = 1
                  AND d.vehicle_id IS NOT NULL
                  AND d.last_lat IS NOT NULL
                  AND d.last_lng IS NOT NULL
                  AND d.id NOT IN (
                      SELECT b.driver_id FROM bookings b
                      WHERE b.driver_id IS NOT NULL
                        AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
                  )
                HAVING distance_km <= :radius
            ) AS available
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':lat' => $lat, ':lng' => $lng, ':radius' => $radius, ':vtid' => $vehicleTypeId]);
        return (int) $stmt->fetchColumn();
    }

    /**
     * Find nearby OFFLINE drivers who could be soft-notified about a new trip.
     * Returns up to $limit drivers sorted by proximity.
     * Excludes drivers already on an active booking.
     */
    protected function findNearbyOfflineDrivers(
        float  $lat,
        float  $lng,
        string $vehicleTypeId,
        int    $limit = 3
    ): array {
        $radius = (float) $this->setting('driver_search_radius_km', '50');
        // Expand radius slightly for offline suggestions so we cast a wider net
        $softRadius = $radius * 1.5;

        $sql = "
            SELECT d.id, d.name, d.phone, d.fcm_token,
                   d.last_lat, d.last_lng,
                   (6371 * ACOS(
                       LEAST(1.0, COS(RADIANS(:lat)) * COS(RADIANS(d.last_lat))
                       * COS(RADIANS(d.last_lng) - RADIANS(:lng))
                       + SIN(RADIANS(:lat)) * SIN(RADIANS(d.last_lat)))
                   )) AS distance_km
            FROM drivers d
            INNER JOIN vehicles v ON v.id = d.vehicle_id AND v.vehicle_type_id = :vtid
            WHERE d.is_online  = 0
              AND d.is_active  = 1
              AND d.vehicle_id IS NOT NULL
              AND d.last_lat   IS NOT NULL
              AND d.last_lng   IS NOT NULL
              AND d.id NOT IN (
                  SELECT b.driver_id FROM bookings b
                  WHERE b.driver_id IS NOT NULL
                    AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
              )
            HAVING distance_km <= :radius
            ORDER BY distance_km ASC
            LIMIT $limit
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':lat' => $lat, ':lng' => $lng, ':radius' => $softRadius, ':vtid' => $vehicleTypeId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Find nearest drivers for a booking (both online and nearby-offline).
     * Returns array with keys 'online' (array) and 'offline' (array).
     */
    protected function findDriverCandidates(float $lat, float $lng, string $vehicleTypeId): array
    {
        $radius = (float) $this->setting('driver_search_radius_km', '50');

        $sql = "
            SELECT d.id, d.name, d.phone, d.fcm_token, d.is_online,
                   d.last_lat, d.last_lng, v.plate_number,
                   vt.name AS vehicle_type_name,
                   (6371 * ACOS(
                       LEAST(1.0, COS(RADIANS(:lat)) * COS(RADIANS(d.last_lat))
                       * COS(RADIANS(d.last_lng) - RADIANS(:lng))
                       + SIN(RADIANS(:lat)) * SIN(RADIANS(d.last_lat)))
                   )) AS distance_km
            FROM drivers d
            INNER JOIN vehicles v  ON v.id  = d.vehicle_id AND v.vehicle_type_id = :vtid
            INNER JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
            WHERE d.is_active    = 1
              AND d.vehicle_id   IS NOT NULL
              AND d.last_lat     IS NOT NULL
              AND d.last_lng     IS NOT NULL
              AND d.id NOT IN (
                  SELECT b.driver_id FROM bookings b
                  WHERE b.driver_id IS NOT NULL
                    AND b.status IN ('assigned','accepted','arrived','in_progress','payment_pending')
              )
            HAVING distance_km <= :radius
            ORDER BY d.is_online DESC, distance_km ASC
            LIMIT 10
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':lat' => $lat, ':lng' => $lng, ':radius' => $radius, ':vtid' => $vehicleTypeId]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $online  = array_values(array_filter($rows, fn($r) => (int)$r['is_online'] === 1));
        $offline = array_values(array_filter($rows, fn($r) => (int)$r['is_online'] === 0));

        return ['online' => $online, 'offline' => $offline];
    }

    // ── Email helpers ─────────────────────────────────────────────────────────

    /**
     * Send a transactional email using a stored template.
     * Template body/subject are loaded from settings (tpl_{key}_subject / tpl_{key}_body).
     * Variables in the template (e.g. {{customer_name}}) are replaced with $vars values.
     *
     * @param string $templateKey  One of: booking_confirmed, driver_assigned, booking_cancelled, welcome
     * @param string $to           Recipient email address
     * @param string $toName       Recipient display name
     * @param array  $vars         Associative array of placeholder → replacement values
     */
    protected function sendTemplateEmail(string $templateKey, string $to, string $toName, array $vars): void
    {
        if ($this->setting('email_notifications_enabled', '1') !== '1') return;
        if (empty($to) || !filter_var($to, FILTER_VALIDATE_EMAIL)) return;

        require_once ROOT . 'functions/mailer.php';

        // Resolve subject/body from DB (falling back to empty — EmailTemplates controller
        // exposes defaults, but here we just skip if nothing is stored yet)
        $subject = $this->setting("tpl_{$templateKey}_subject", '');
        $body    = $this->setting("tpl_{$templateKey}_body",    '');

        if (empty($subject) || empty($body)) return;

        // Merge universal variables
        $allVars = array_merge([
            '{{app_name}}'    => $this->setting('app_name', 'EtcRide'),
            '{{support_email}}' => $this->setting('support_email', ''),
        ], $vars);

        $renderedSubject = str_replace(array_keys($allVars), array_values($allVars), $subject);
        $renderedBody    = str_replace(array_keys($allVars), array_values($allVars), $body);

        $smtpConfig = [
            'smtp_host'       => $this->setting('smtp_host',       ''),
            'smtp_port'       => $this->setting('smtp_port',       '587'),
            'smtp_username'   => $this->setting('smtp_username',   ''),
            'smtp_password'   => $this->setting('smtp_password',   ''),
            'smtp_encryption' => $this->setting('smtp_encryption', 'tls'),
            'smtp_from_name'  => $this->setting('smtp_from_name',  $this->setting('app_name', 'EtcRide')),
            'smtp_from_email' => $this->setting('smtp_from_email', ''),
        ];

        $mailer = new Mymailer();
        $mailer->send_email_with_config($smtpConfig, $to, $renderedSubject, $renderedBody, $toName);
    }

    // ── Token helpers ─────────────────────────────────────────────────────────

    protected function extractBearerToken(): ?string
    {
        $header = $_SERVER['Authorization']
               ?? $_SERVER['HTTP_AUTHORIZATION']
               ?? (function_exists('apache_request_headers')
                   ? (apache_request_headers()['Authorization'] ?? null)
                   : null);
        if (empty($header)) return null;
        if (preg_match('/Bearer\s(\S+)/i', $header, $m)) return $m[1];
        return null;
    }

    protected function generateToken(): string
    {
        return bin2hex(random_bytes(32));
    }

    // ── Default zone lookup ───────────────────────────────────────────────────

    protected function getDefaultZoneId(): ?string
    {
        $zone = $this->getall('zones', 'is_default = 1 AND is_active = 1', [], 'id');
        return is_array($zone) ? $zone['id'] : null;
    }
}
