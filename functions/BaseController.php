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
        $row = $this->getall('settings', 'config_key = ?', [$key]);
        return is_array($row) ? (string) $row['config_value'] : $default;
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

    /** Send FCM push notification via Firebase HTTP v1 API */
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

        $serverKey = $_ENV['FCM_SERVER_KEY'] ?? '';
        if (empty($serverKey)) return;

        $payload = json_encode([
            'to'           => $rec['fcm_token'],
            'notification' => ['title' => $title, 'body' => $body],
            'data'         => ['type' => $type, 'booking_id' => $bookingId],
        ]);

        $ch = curl_init('https://fcm.googleapis.com/fcm/send');
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'Authorization: key=' . $serverKey,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_TIMEOUT        => 5,
        ]);
        curl_exec($ch);
        curl_close($ch);
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

    // ── Fare calculation ──────────────────────────────────────────────────────

    /**
     * Calculate fare using zone pricing (preferred) or vehicle type default pricing.
     * Formula: base_fare + (distance_km × per_km_rate) + (num_stops × per_stop_fee)
     */
    protected function calculateFare(string $vehicleTypeId, ?string $zoneId, float $distanceKm, int $numStops): float
    {
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

        $fare    = (float) $pricing['base_fare']
                 + ($distanceKm * (float) $pricing['per_km_rate'])
                 + ($numStops   * (float) $pricing['per_stop_fee']);
        $minFare = (float) $this->setting('min_booking_fare', '200');

        return max(round($fare, 2), $minFare);
    }

    // ── Auto-assign: find nearest free driver ────────────────────────────────

    /**
     * Find the nearest online, available (not on an active booking) driver.
     * Returns driver row or null.
     */
    protected function findNearestDriver(float $lat, float $lng, string $vehicleTypeId): ?array
    {
        $radius = (float) $this->setting('driver_search_radius_km', '10');

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

    protected function countAvailableDrivers(string $vehicleTypeId, float $lat, float $lng): int
    {
        $radius = (float) $this->setting('driver_search_radius_km', '10');

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
