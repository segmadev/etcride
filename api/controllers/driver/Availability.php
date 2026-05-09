<?php
require_once ROOT . 'functions/BaseController.php';

class Availability extends BaseController
{
    // ── PUT /driver/availability ──────────────────────────────────────────────
    public function toggle(): void
    {
        $me     = BaseController::$authDriver;
        $online = $this->input('is_online');

        if ($online === null) {
            echo utilities::apiMessage('is_online field is required (true or false).', 422);
            return;
        }

        $isOnline = filter_var($online, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;

        $this->update('drivers', ['is_online' => $isOnline], "id = '{$me['id']}'");

        $status = $isOnline ? 'online' : 'offline';
        $this->logActivity('driver', $me['id'], "went_$status");

        echo utilities::apiMessage("You are now $status.", 200, ['is_online' => (bool) $isOnline]);
    }
}
