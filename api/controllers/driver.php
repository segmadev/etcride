<?php
require_once ROOT . 'functions/BaseController.php';

/**
 * Driver auth guard.
 * The router instantiates this and calls set_driver() before dispatching to any
 * route with authType = 'driver'.
 * Auth state is stored in BaseController::$authDriver for controllers to read.
 */
class driver extends BaseController
{
    public function set_driver(): void
    {
        $token = $this->extractBearerToken();

        if (empty($token)) {
            die(utilities::apiMessage('Authentication required. Please log in.', 401));
        }

        $session = $this->getall(
            'driver_sessions',
            'token = ?',
            [$token]
        );

        if (!is_array($session)) {
            die(utilities::apiMessage('Invalid or expired token. Please log in again.', 401));
        }

        if (strtotime($session['expires_at']) < time()) {
            $this->delete('driver_sessions', 'token = ?', [$token]);
            die(utilities::apiMessage('Session expired. Please log in again.', 401));
        }

        $driverRow = $this->getall('drivers', 'id = ?', [$session['driver_id']]);

        if (!is_array($driverRow)) {
            die(utilities::apiMessage('Driver account not found.', 401));
        }

        // Allow deactivated drivers to access account deletion endpoints only
        $path = $_SERVER['REQUEST_URI'] ?? '';
        $isAccountDeletionEndpoint = strpos($path, '/account/delete-request') !== false;

        if ((int) $driverRow['is_active'] !== 1 && !$isAccountDeletionEndpoint) {
            die(utilities::apiMessage('Your account has been deactivated. Please contact admin.', 403));
        }

        unset($driverRow['password'], $driverRow['reset_code']);

        BaseController::$authDriver = $driverRow;
    }
}
