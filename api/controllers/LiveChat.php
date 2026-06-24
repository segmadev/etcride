<?php
require_once ROOT . 'functions/BaseController.php';

class LiveChat extends BaseController
{
    // ── GET /live-chat/settings ───────────────────────────────────────────────
    // Public endpoint - no auth required
    public function getSettings(): void
    {
        try {
            $settings = $this->getall('settings', '1=1 LIMIT 1', []);

            if (!is_array($settings)) {
                echo utilities::apiMessage('Settings not found', 404);
                return;
            }

            $response = [
                'live_chat_enabled' => (bool) ($settings['live_chat_enabled'] ?? false),
                'tawk_widget_id' => $settings['tawk_widget_id'] ?? null,
            ];

            echo utilities::apiMessage('Live chat settings retrieved', 200, $response);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error fetching settings: ' . $e->getMessage(), 500);
        }
    }

    // ── PUT /admin/live-chat/settings ──────────────────────────────────────────
    // Admin only - update live chat settings
    public function updateSettings(): void
    {
        $me = BaseController::$authAdmin;

        if (!$me) {
            echo utilities::apiMessage('Unauthorized', 401);
            return;
        }

        try {
            $enabled = $this->bool('live_chat_enabled');
            $widgetId = $this->str('tawk_widget_id');

            if ($enabled && empty($widgetId)) {
                echo utilities::apiMessage('Tawk widget ID is required when live chat is enabled', 422);
                return;
            }

            // Update settings
            $sql = "UPDATE settings SET live_chat_enabled = ?, tawk_widget_id = ? WHERE 1=1 LIMIT 1";
            $this->db->run($sql, [$enabled ? 1 : 0, $widgetId]);

            // Log activity
            $this->logActivity('admin', $me['id'], 'live_chat_settings_updated', [
                'enabled' => $enabled,
                'widget_id' => $widgetId ? substr($widgetId, 0, 10) . '...' : null,
            ]);

            echo utilities::apiMessage('Live chat settings updated', 200, [
                'live_chat_enabled' => $enabled,
                'tawk_widget_id' => $widgetId,
            ]);
        } catch (Exception $e) {
            echo utilities::apiMessage('Error updating settings: ' . $e->getMessage(), 500);
        }
    }
}
?>
