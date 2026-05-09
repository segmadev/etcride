<?php
require_once ROOT . 'functions/BaseController.php';

class Auth extends BaseController
{
    // ── POST /driver/auth/login ───────────────────────────────────────────────
    public function login(): void
    {
        $err = $this->requireFields(['phone', 'password']);
        if ($err) { echo $err; return; }

        $phone   = $this->str('phone');
        $passRaw = $this->input('password', '');

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false) {
            echo utilities::apiMessage('Invalid password format.', 400);
            return;
        }

        $field  = filter_var($phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        $driver = $this->getall('drivers', "$field = ?", [$phone]);

        if (!is_array($driver) || !password_verify($decoded, $driver['password'])) {
            echo utilities::apiMessage('Invalid credentials.', 401);
            return;
        }

        if ((int) $driver['is_active'] !== 1) {
            echo utilities::apiMessage('Your account has been deactivated. Contact admin.', 403);
            return;
        }

        $token     = $this->generateToken();
        $expiresAt = date('Y-m-d H:i:s', time() + 86400 * 30);

        $this->delete('driver_sessions', 'driver_id = ?', [$driver['id']]);
        $this->quick_insert('driver_sessions', [
            'id'         => utilities::genID('DSS_', 10),
            'driver_id'  => $driver['id'],
            'token'      => $token,
            'expires_at' => $expiresAt,
            'device'     => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
            'ip'         => $_SERVER['REMOTE_ADDR'] ?? '',
        ]);

        $this->logActivity('driver', $driver['id'], 'login');

        unset($driver['password'], $driver['reset_code']);
        $driver['token']      = $token;
        $driver['expires_at'] = $expiresAt;

        echo utilities::apiMessage('Login successful.', 200, $driver);
    }

    // ── POST /driver/auth/logout ──────────────────────────────────────────────
    public function logout(): void
    {
        $me    = BaseController::$authDriver;
        $token = $this->extractBearerToken();
        $this->delete('driver_sessions', 'token = ?', [$token]);
        $this->logActivity('driver', $me['id'], 'logout');
        echo utilities::apiMessage('Logged out successfully.', 200);
    }

    // ── PUT /driver/auth/profile ──────────────────────────────────────────────
    public function updateProfile(): void
    {
        $me     = BaseController::$authDriver;
        $fields = [];

        if ($this->str('fcm_token') !== '') $fields['fcm_token'] = $this->str('fcm_token');

        if (empty($fields)) {
            echo utilities::apiMessage('No fields to update.', 400);
            return;
        }

        $this->update('drivers', $fields, "id = '{$me['id']}'");
        echo utilities::apiMessage('Profile updated.', 200);
    }
}
