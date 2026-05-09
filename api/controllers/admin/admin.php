<?php
require_once ROOT . 'functions/BaseController.php';
require_once ROOT . 'functions/mailer.php';

/**
 * Admin auth guard + login endpoint.
 * set_admin() is called by the router for every /admin/* route.
 */
class admin extends BaseController
{
    // ── Auth guard ────────────────────────────────────────────────────────────
    public function set_admin(): void
    {
        $token = $this->extractBearerToken();

        if (empty($token)) {
            die(utilities::apiMessage('Admin authentication required.', 401));
        }

        $row = $this->getall('admin', 'token = ? AND status = 1', [$token]);

        if (!is_array($row)) {
            die(utilities::apiMessage('Invalid or expired admin token.', 401));
        }

        unset($row['password']);
        BaseController::$authAdmin = $row;
    }

    // ── POST /admin/auth/login ────────────────────────────────────────────────
    public function login(): void
    {
        $err = $this->requireFields(['email', 'password']);
        if ($err) { echo $err; return; }

        $email   = $this->str('email');
        $passRaw = $this->input('password', '');

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false) {
            echo utilities::apiMessage('Invalid password format.', 400);
            return;
        }

        $adminRow = $this->getall('admin', 'email = ?', [$email]);

        if (!is_array($adminRow) || !password_verify($decoded, $adminRow['password'])) {
            echo utilities::apiMessage('Invalid credentials.', 401);
            return;
        }

        if ((int) $adminRow['status'] !== 1) {
            echo utilities::apiMessage('Account is not active.', 403);
            return;
        }

        $token = $this->generateToken();
        $this->update('admin', ['token' => $token], "id = '{$adminRow['id']}'");

        $this->logActivity('admin', $adminRow['id'], 'admin_login');

        unset($adminRow['password']);
        $adminRow['token'] = $token;

        echo utilities::apiMessage('Login successful.', 200, $adminRow);
    }

    // ── GET /admin/ping ───────────────────────────────────────────────────────
    public function ping(): void
    {
        $this->set_admin();
        echo utilities::apiMessage('Admin OK.', 200, [
            'admin'  => BaseController::$authAdmin,
            'time'   => date('Y-m-d H:i:s'),
        ]);
    }

    // ── GET /admin/profile ────────────────────────────────────────────────────
    public function getProfile(): void
    {
        $me = BaseController::$authAdmin;
        echo utilities::apiMessage('Profile retrieved.', 200, $me);
    }

    // ── PUT /admin/profile ────────────────────────────────────────────────────
    public function updateProfile(): void
    {
        $me     = BaseController::$authAdmin;
        $fields = [];

        if ($this->str('name') !== '')  $fields['name']  = $this->str('name');
        if ($this->str('email') !== '') {
            $email  = $this->str('email');
            $exists = $this->db->prepare('SELECT COUNT(*) FROM admin WHERE email = ? AND id != ?');
            $exists->execute([$email, $me['id']]);
            if ((int) $exists->fetchColumn() > 0) {
                echo utilities::apiMessage('Email already in use.', 409); return;
            }
            $fields['email'] = $email;
        }

        if (empty($fields)) { echo utilities::apiMessage('Nothing to update.', 400); return; }

        $this->update('admin', $fields, "id = '{$me['id']}'");
        $this->logActivity('admin', $me['id'], 'profile_updated');

        // Return updated row (excluding password)
        $updated = $this->getall('admin', 'id = ?', [$me['id']]);
        unset($updated['password'], $updated['token']);
        echo utilities::apiMessage('Profile updated.', 200, $updated);
    }

    // ── PUT /admin/profile/password ───────────────────────────────────────────
    public function changePassword(): void
    {
        $me          = BaseController::$authAdmin;
        $currentRaw  = $this->input('current_password', '');
        $newRaw      = $this->input('new_password', '');

        if ($currentRaw === '' || $newRaw === '') {
            echo utilities::apiMessage('current_password and new_password are required.', 422); return;
        }

        // Fetch full row to verify current password
        $row = $this->getall('admin', 'id = ?', [$me['id']]);
        if (!is_array($row) || !password_verify($currentRaw, $row['password'])) {
            echo utilities::apiMessage('Current password is incorrect.', 401); return;
        }

        if (strlen(trim($newRaw)) < 6) {
            echo utilities::apiMessage('New password must be at least 6 characters.', 422); return;
        }

        $this->update('admin', ['password' => password_hash($newRaw, PASSWORD_DEFAULT)], "id = '{$me['id']}'");
        $this->logActivity('admin', $me['id'], 'password_changed');
        echo utilities::apiMessage('Password changed successfully.', 200);
    }
}
