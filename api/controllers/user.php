<?php
require_once ROOT . 'functions/BaseController.php';

/**
 * Customer auth guard.
 * The router instantiates this and calls set_user() before dispatching to any
 * route with authType = 'customer' (default).
 * Auth state is stored in BaseController::$authUser for controllers to read.
 */
class user extends BaseController
{
    public function set_user(): void
    {
        $token = $this->extractBearerToken();

        if (empty($token)) {
            die(utilities::apiMessage('Authentication required. Please log in.', 401));
        }

        $session = $this->getall(
            'user_sessions',
            'token = ?',
            [$token]
        );

        if (!is_array($session)) {
            die(utilities::apiMessage('Invalid or expired token. Please log in again.', 401));
        }

        if (strtotime($session['expires_at']) < time()) {
            $this->delete('user_sessions', 'token = ?', [$token]);
            die(utilities::apiMessage('Session expired. Please log in again.', 401));
        }

        $customer = $this->getall('users', 'id = ?', [$session['user_id']]);

        if (!is_array($customer)) {
            die(utilities::apiMessage('Account not found.', 401));
        }

        if ((int) $customer['status'] !== 1) {
            die(utilities::apiMessage('Your account is not active. Please verify your email or contact support.', 403));
        }

        // Remove sensitive fields
        unset($customer['password'], $customer['reset_code']);

        BaseController::$authUser = $customer;
    }
}
