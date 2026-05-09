<?php
require_once ROOT . 'functions/BaseController.php';

class Settings extends BaseController
{
    // ── GET /admin/settings ───────────────────────────────────────────────────
    public function index(): void
    {
        $stmt = $this->db->query('SELECT config_key, config_value, description, updated_at FROM settings ORDER BY config_key ASC');
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Return as key → value map for easy frontend consumption
        $map = [];
        foreach ($rows as $row) {
            $map[$row['config_key']] = [
                'value'       => $row['config_value'],
                'description' => $row['description'],
                'updated_at'  => $row['updated_at'],
            ];
        }

        echo utilities::apiMessage('Settings retrieved.', 200, $map);
    }

    // ── PUT /admin/settings ───────────────────────────────────────────────────
    // Accepts a JSON body or POST fields of { key: value, ... }
    public function edit(): void
    {
        $me = BaseController::$authAdmin;

        // Accept both JSON body and POST fields
        $updates = $_POST;
        if (empty($updates)) {
            $body = json_decode(file_get_contents('php://input'), true);
            if (is_array($body)) $updates = $body;
        }

        if (empty($updates)) {
            echo utilities::apiMessage('No settings provided.', 400);
            return;
        }

        // Allowed keys (whitelist)
        $allowed = [
            'auto_assign_enabled', 'driver_search_radius_km', 'calc_method',
            'pay_mode', 'payment_provider',
            'cancellation_allowed_by', 'cancellation_window_minutes',
            'cancellation_fee_enabled', 'cancellation_fee_amount',
            'cancellation_fee_after_assignment',
            'email_notifications_enabled', 'fcm_enabled',
            'min_booking_fare', 'app_name', 'support_email', 'support_phone',
            'currency', 'currency_symbol',
            // Map settings
            'google_maps_api_key', 'google_maps_web_key', 'google_maps_server_key',
            'map_center_lat', 'map_center_lng',
            'map_default_zoom', 'service_boundary', 'booking_boundary_enforcement',
            // App content & legal
            'app_tagline', 'about_text', 'terms_and_conditions', 'privacy_policy',
            // SMTP configuration
            'smtp_enabled', 'smtp_host', 'smtp_port', 'smtp_username',
            'smtp_password', 'smtp_encryption', 'smtp_from_name', 'smtp_from_email',
            // Email templates
            'tpl_booking_confirmed_subject', 'tpl_booking_confirmed_body',
            'tpl_driver_assigned_subject',   'tpl_driver_assigned_body',
            'tpl_booking_cancelled_subject', 'tpl_booking_cancelled_body',
            'tpl_welcome_subject',           'tpl_welcome_body',
        ];

        $updated = [];
        $invalid = [];

        foreach ($updates as $key => $value) {
            if (!in_array($key, $allowed)) {
                $invalid[] = $key;
                continue;
            }

            $exists = $this->getall('settings', 'config_key = ?', [$key], fetch: '');
            if ((int) $exists > 0) {
                $this->update('settings', ['config_value' => (string) $value], "config_key = '$key'");
            } else {
                $this->quick_insert('settings', ['config_key' => $key, 'config_value' => (string) $value]);
            }
            $updated[] = $key;
        }

        $this->logActivity('admin', $me['id'], 'settings_updated', ['keys' => $updated]);

        echo utilities::apiMessage('Settings updated.', 200, [
            'updated' => $updated,
            'ignored' => $invalid,
        ]);
    }
}
