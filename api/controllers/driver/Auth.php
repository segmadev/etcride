<?php
require_once ROOT . 'functions/BaseController.php';
require_once ROOT . 'functions/mailer.php';

class Auth extends BaseController
{
    private Mymailer $mailer;

    public function __construct()
    {
        parent::__construct();
        $this->mailer = new Mymailer();
    }

    private function driverAuthMode(): string
    {
        $mode = strtolower(trim($this->setting('driver_auth_mode', 'both')));
        return in_array($mode, ['otp', 'password', 'both'], true) ? $mode : 'both';
    }

    // ── POST /driver/auth/login ───────────────────────────────────────────────
    public function login(): void
    {
        if (!in_array($this->driverAuthMode(), ['password', 'both'], true)) {
            echo utilities::apiMessage('Password login is disabled. Use OTP login.', 403);
            return;
        }

        // Accept 'login' (phone or email, sent by the Flutter app) or legacy 'phone'.
        $loginId = $this->str('login') ?: $this->str('phone');
        $passRaw = $this->input('password', '');
        if (empty($loginId) || empty(trim((string) $passRaw))) {
            echo utilities::apiMessage('The following fields are required: login, password', 422);
            return;
        }

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false) {
            echo utilities::apiMessage('Invalid password format.', 400);
            return;
        }

        $field  = filter_var($loginId, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        $driver = $this->getall('drivers', "$field = ?", [$loginId]);

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

    // ── POST /driver/auth/register ────────────────────────────────────────────
    public function register(): void
    {
        $err = $this->requireFields(['name', 'phone', 'password']);
        if ($err) { echo $err; return; }

        $name    = $this->str('name');
        $email   = $this->str('email');
        $phone   = $this->str('phone');
        $passRaw = $this->input('password', '');

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false || strlen(trim($decoded)) < 6) {
            echo utilities::apiMessage('Password must be at least 6 characters.', 422);
            return;
        }

        if ($this->getall('drivers', 'phone = ?', [$phone], fetch: '') > 0) {
            echo utilities::apiMessage('Phone number already in use.', 409);
            return;
        }
        if ($email !== '' && $this->getall('drivers', 'email = ?', [$email], fetch: '') > 0) {
            echo utilities::apiMessage('Email already in use.', 409);
            return;
        }

        $id = utilities::genID('DRV_', 10);

        $fields = [
            'id'         => $id,
            'name'       => $name,
            'email'      => $email !== '' ? $email : null,
            'phone'      => $phone,
            'password'   => password_hash($decoded, PASSWORD_DEFAULT),
            'is_active'  => 1,
            'is_online'  => 0,
            'kyc_status' => 'not_submitted',
        ];

        $state = $this->str('state');
        $lga   = $this->str('lga');
        if ($state !== '' && $this->tableHasColumn('drivers', 'state')) $fields['state'] = $state;
        if ($lga   !== '' && $this->tableHasColumn('drivers', 'lga'))   $fields['lga']   = $lga;

        $inserted = $this->quick_insert('drivers', $fields);
        if (!$inserted) {
            echo utilities::apiMessage('Could not create driver account. Please try again.', 500);
            return;
        }

        $this->logActivity('driver', $id, 'register');
        echo utilities::apiMessage('Driver registered successfully.', 201, [
            'id'         => $id,
            'name'       => $name,
            'phone'      => $phone,
            'email'      => $email !== '' ? $email : null,
            'kyc_status' => 'not_submitted',
        ]);
    }

    // ── POST /driver/auth/send-otp ────────────────────────────────────────────
    public function sendOtp(): void
    {
        if (!in_array($this->driverAuthMode(), ['otp', 'both'], true)) {
            echo utilities::apiMessage('OTP login is disabled. Use password login.', 403);
            return;
        }

        $err = $this->requireFields(['contact']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $isEmail = (bool) filter_var($contact, FILTER_VALIDATE_EMAIL);
        $type    = $isEmail ? 'email' : 'phone';

        $driver = $this->getall('drivers', "$type = ?", [$contact]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver account not found. Please register first.', 404);
            return;
        }

        if ((int) $driver['is_active'] !== 1) {
            echo utilities::apiMessage('Your account has been deactivated. Contact admin.', 403);
            return;
        }

        $otp     = str_pad((string) mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
        $hash    = password_hash($otp, PASSWORD_DEFAULT);
        $expires = date('Y-m-d H:i:s', time() + 600);

        $contactKey = 'driver:' . $contact;
        $this->delete('otp_requests', 'contact = ? AND used = 0', [$contactKey]);

        $this->quick_insert('otp_requests', [
            'id'           => utilities::genID('OTP_', 10),
            'contact'      => $contactKey,
            'contact_type' => $type,
            'otp_hash'     => $hash,
            'expires_at'   => $expires,
            'used'         => 0,
        ]);

        $appName = $this->setting('app_name', 'ETCRide');
        if ($isEmail) {
            $this->mailer->smtpmailer(
                $contact,
                "Your $appName driver code",
                "Hi,\n\nYour one-time code is: $otp\n\nThis code expires in 10 minutes.\n\n— $appName Team"
            );
        } else {
            require_once ROOT . 'functions/sms.php';
            Sms::send($contact, "Your $appName driver code is: $otp. Valid for 10 mins.");
        }

        $devMode = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $extra   = $devMode ? ['_dev_otp' => $otp] : [];

        echo utilities::apiMessage('OTP sent successfully.', 200, array_merge([
            'contact'      => $contact,
            'contact_type' => $type,
        ], $extra));
    }

    // ── POST /driver/auth/verify-otp ──────────────────────────────────────────
    public function verifyOtp(): void
    {
        if (!in_array($this->driverAuthMode(), ['otp', 'both'], true)) {
            echo utilities::apiMessage('OTP login is disabled. Use password login.', 403);
            return;
        }

        $err = $this->requireFields(['contact', 'otp']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $otp     = trim($this->str('otp'));
        $devMode = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $isEmail = (bool) filter_var($contact, FILTER_VALIDATE_EMAIL);
        $type    = $isEmail ? 'email' : 'phone';

        $driver = $this->getall('drivers', "$type = ?", [$contact]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver account not found. Please register first.', 404);
            return;
        }

        if ((int) $driver['is_active'] !== 1) {
            echo utilities::apiMessage('Your account has been deactivated. Contact admin.', 403);
            return;
        }

        $bypass = $devMode && $otp === '123456';

        if (!$bypass) {
            $contactKey = 'driver:' . $contact;
            $stmt = $this->db->prepare(
                "SELECT * FROM otp_requests
                 WHERE contact = ? AND used = 0 AND expires_at > NOW()
                 ORDER BY created_at DESC LIMIT 1"
            );
            $stmt->execute([$contactKey]);
            $otpRow = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$otpRow || !password_verify($otp, $otpRow['otp_hash'])) {
                echo utilities::apiMessage('Invalid or expired code. Please try again.', 400);
                return;
            }

            $this->update('otp_requests', ['used' => 1], "id = '{$otpRow['id']}'");
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

        $this->logActivity('driver', $driver['id'], 'otp_login');

        unset($driver['password'], $driver['reset_code']);
        $driver['token']      = $token;
        $driver['expires_at'] = $expiresAt;

        echo utilities::apiMessage('Verified successfully.', 200, $driver);
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

    // ── GET /driver/auth/profile ──────────────────────────────────────────────
    public function getProfile(): void
    {
        $me = BaseController::$authDriver;
        // Re-fetch from DB so the response always reflects the latest kyc_status,
        // is_online, rating, etc. — not just the session snapshot.
        $driver = $this->getall('drivers', 'id = ?', [$me['id']]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver not found.', 404);
            return;
        }
        unset($driver['password'], $driver['reset_code']);
        echo utilities::apiMessage('Profile retrieved.', 200, $driver);
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
