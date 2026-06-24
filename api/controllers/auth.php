<?php
require_once ROOT . 'functions/BaseController.php';
require_once ROOT . 'functions/mailer.php';

class auth extends BaseController
{
    private Mymailer $mailer;

    public function __construct()
    {
        parent::__construct();
        $this->mailer = new Mymailer();
    }

    // ── POST /auth/register ───────────────────────────────────────────────────
    public function register(): void
    {
        $err = $this->requireFields(['name', 'phone', 'password']);
        if ($err) { echo $err; return; }

        $name     = $this->str('name');
        $email    = $this->str('email');
        $phone    = $this->str('phone');
        $passRaw  = $this->input('password', '');

        // Decode base64 password
        $decoded = base64_decode($passRaw, true);
        if ($decoded === false || strlen(trim($decoded)) < 6) {
            echo utilities::apiMessage('Password must be at least 6 characters.', 422);
            return;
        }

        if ($this->getall('users', 'phone = ?', [$phone], fetch: '') > 0) {
            echo utilities::apiMessage('Phone number is already registered.', 409);
            return;
        }

        if ($email !== '' && $this->getall('users', 'email = ?', [$email], fetch: '') > 0) {
            echo utilities::apiMessage('Email address is already registered.', 409);
            return;
        }

        $id   = utilities::genID('USR_', 10);
        $code = mt_rand(100000, 999999);

        $inserted = $this->quick_insert('users', [
            'id'           => $id,
            'name'         => $name,
            'email'        => $email ?: null,
            'phone'        => $phone,
            'password'     => password_hash($decoded, PASSWORD_DEFAULT),
            'status'       => 0,
            'reset_code'   => password_hash((string) $code, PASSWORD_DEFAULT),
        ]);

        if (!$inserted) {
            echo utilities::apiMessage('Could not create account. Please try again.', 500);
            return;
        }

        if ($email !== '' && $this->setting('email_notifications_enabled', '1') === '1') {
            $appName = $this->setting('app_name', 'EtcRide');
            $this->mailer->smtpmailer(
                $email,
                "Verify your $appName account",
                "Hi $name,\n\nYour verification code is: $code\n\nThis code expires in 30 minutes.\n\n— $appName Team"
            );
        }

        $this->logActivity('customer', $id, 'register');

        echo utilities::apiMessage('Account created. Please verify your email to continue.', 201, [
            'id'    => $id,
            'name'  => $name,
            'phone' => $phone,
            'email' => $email ?: null,
        ]);
    }

    // ── POST /auth/verify-email ───────────────────────────────────────────────
    public function verifyEmail(): void
    {
        $err = $this->requireFields(['email', 'code']);
        if ($err) { echo $err; return; }

        $email = $this->str('email');
        $code  = trim((string) $this->input('code', ''));

        $user = $this->getall('users', 'email = ?', [$email]);
        if (!is_array($user)) {
            echo utilities::apiMessage('Account not found.', 404);
            return;
        }

        if ((int) $user['status'] === 1) {
            echo utilities::apiMessage('Email is already verified.', 200);
            return;
        }

        if (empty($user['reset_code']) || !password_verify($code, $user['reset_code'])) {
            echo utilities::apiMessage('Invalid verification code.', 400);
            return;
        }

        $this->update('users', ['status' => 1, 'reset_code' => null], "id = '{$user['id']}'");
        $this->logActivity('customer', $user['id'], 'email_verified');

        echo utilities::apiMessage('Email verified. You can now log in.', 200);
    }

    // ── POST /auth/resend-verification ───────────────────────────────────────
    public function resendVerification(): void
    {
        $err = $this->requireFields(['email']);
        if ($err) { echo $err; return; }

        $email = $this->str('email');
        $user  = $this->getall('users', 'email = ?', [$email]);

        if (!is_array($user)) {
            echo utilities::apiMessage('Account not found.', 404);
            return;
        }

        if ((int) $user['status'] === 1) {
            echo utilities::apiMessage('Email is already verified.', 200);
            return;
        }

        $code = mt_rand(100000, 999999);
        $this->update('users', [
            'reset_code' => password_hash((string) $code, PASSWORD_DEFAULT),
        ], "id = '{$user['id']}'");

        if ($this->setting('email_notifications_enabled', '1') === '1') {
            $appName = $this->setting('app_name', 'EtcRide');
            $this->mailer->smtpmailer(
                $email,
                "Your new verification code — $appName",
                "Hi {$user['name']},\n\nYour new verification code is: $code\n\n— $appName Team"
            );
        }

        echo utilities::apiMessage('Verification code resent. Please check your email.', 200);
    }

    // ── POST /auth/login ──────────────────────────────────────────────────────
    public function login(): void
    {
        $err = $this->requireFields(['login', 'password']);
        if ($err) { echo $err; return; }

        $login   = $this->str('login');    // accepts phone or email
        $passRaw = $this->input('password', '');

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false) {
            echo utilities::apiMessage('Invalid password format.', 400);
            return;
        }

        // Allow login by phone or email
        $field = filter_var($login, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        $user  = $this->getall('users', "$field = ?", [$login]);

        $hash = is_array($user) ? ($user['password'] ?? null) : null;
        if (!is_string($hash) || $hash === '' || !password_verify($decoded, $hash)) {
            echo utilities::apiMessage('Invalid credentials.', 401);
            return;
        }

        if ((int) $user['status'] !== 1) {
            echo utilities::apiMessage('Please verify your email before logging in.', 403);
            return;
        }

        // Create session
        $token     = $this->generateToken();
        $expiresAt = date('Y-m-d H:i:s', time() + 86400 * 30); // 30 days

        $this->delete('user_sessions', 'user_id = ?', [$user['id']]);
        $this->quick_insert('user_sessions', [
            'id'         => utilities::genID('USS_', 10),
            'user_id'    => $user['id'],
            'token'      => $token,
            'expires_at' => $expiresAt,
            'device'     => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
            'ip'         => $_SERVER['REMOTE_ADDR'] ?? '',
        ]);

        $this->logActivity('customer', $user['id'], 'login');

        unset($user['password'], $user['reset_code']);
        $user['token']      = $token;
        $user['expires_at'] = $expiresAt;

        echo utilities::apiMessage('Login successful.', 200, $user);
    }

    // ── POST /auth/logout ─────────────────────────────────────────────────────
    public function logout(): void
    {
        $me    = BaseController::$authUser;
        $token = $this->extractBearerToken();
        $this->delete('user_sessions', 'token = ?', [$token]);
        $this->logActivity('customer', $me['id'], 'logout');
        echo utilities::apiMessage('Logged out successfully.', 200);
    }

    // ── POST /auth/forgot-password ────────────────────────────────────────────
    public function forgotPassword(): void
    {
        $err = $this->requireFields(['email']);
        if ($err) { echo $err; return; }

        $email = $this->str('email');
        $user  = $this->getall('users', 'email = ?', [$email]);

        // Always respond 200 to avoid email enumeration
        if (!is_array($user)) {
            echo utilities::apiMessage('If that email is registered you will receive a reset code.', 200);
            return;
        }

        $code = mt_rand(100000, 999999);
        $this->update('users', [
            'reset_code' => password_hash((string) $code, PASSWORD_DEFAULT),
        ], "id = '{$user['id']}'");

        if ($this->setting('email_notifications_enabled', '1') === '1') {
            $appName = $this->setting('app_name', 'EtcRide');
            $this->mailer->smtpmailer(
                $email,
                "Password reset code — $appName",
                "Hi {$user['name']},\n\nYour password reset code is: $code\n\nIf you did not request this, you can ignore this email.\n\n— $appName Team"
            );
        }

        echo utilities::apiMessage('If that email is registered you will receive a reset code.', 200);
    }

    // ── POST /auth/reset-password ─────────────────────────────────────────────
    public function resetPassword(): void
    {
        $err = $this->requireFields(['email', 'code', 'password']);
        if ($err) { echo $err; return; }

        $email   = $this->str('email');
        $code    = trim((string) $this->input('code', ''));
        $passRaw = $this->input('password', '');

        $decoded = base64_decode($passRaw, true);
        if ($decoded === false || strlen(trim($decoded)) < 6) {
            echo utilities::apiMessage('Password must be at least 6 characters.', 422);
            return;
        }

        $user = $this->getall('users', 'email = ?', [$email]);
        if (!is_array($user) || empty($user['reset_code'])) {
            echo utilities::apiMessage('Invalid request.', 400);
            return;
        }

        if (!password_verify($code, $user['reset_code'])) {
            echo utilities::apiMessage('Invalid or expired reset code.', 400);
            return;
        }

        $this->update('users', [
            'password'   => password_hash($decoded, PASSWORD_DEFAULT),
            'reset_code' => null,
        ], "id = '{$user['id']}'");

        // Invalidate all sessions on password reset
        $this->delete('user_sessions', 'user_id = ?', [$user['id']]);

        $this->logActivity('customer', $user['id'], 'password_reset');

        echo utilities::apiMessage('Password reset successfully. Please log in.', 200);
    }

    // ── PUT /auth/profile ─────────────────────────────────────────────────────
    public function updateProfile(): void
    {
        $me = BaseController::$authUser;

        $name    = $this->str('name');
        $email   = $this->str('email');
        $phone   = $this->str('phone');
        $passRaw = $this->input('password', '');

        $update = [];

        if ($name !== '') {
            $update['name'] = $name;
        }

        if ($email !== '') {
            $existing = $this->getall('users', 'email = ? AND id != ?', [$email, $me['id']]);
            if (is_array($existing)) {
                echo utilities::apiMessage('Email address is already in use.', 409);
                return;
            }
            // OTP verification gate for email change
            if ($this->setting('email_verification_enabled', '0') === '1' && $email !== ($me['email'] ?? '')) {
                $emailToken = trim($this->str('email_token'));
                if (!$this->consumeContactToken('change_email:' . $email, $emailToken)) {
                    echo utilities::apiMessage('Please verify your new email address with an OTP first.', 403);
                    return;
                }
            }
            $update['email'] = $email;
        }

        if ($phone !== '') {
            if (!$this->isNigeriaPhone($phone)) {
                echo utilities::apiMessage('Only Nigerian phone numbers are supported (+234 / 07x / 08x / 09x).', 422);
                return;
            }
            $existing = $this->getall('users', 'phone = ? AND id != ?', [$phone, $me['id']]);
            if (is_array($existing)) {
                echo utilities::apiMessage('Phone number is already in use.', 409);
                return;
            }
            // OTP verification gate for phone change
            if ($this->setting('phone_verification_enabled', '0') === '1' && $phone !== ($me['phone'] ?? '')) {
                $phoneToken = trim($this->str('phone_token'));
                if (!$this->consumeContactToken('change_phone:' . $phone, $phoneToken)) {
                    echo utilities::apiMessage('Please verify your new phone number with an OTP first.', 403);
                    return;
                }
            }
            $update['phone'] = $phone;
        }

        if ($passRaw !== '') {
            $decoded = base64_decode($passRaw, true);
            if ($decoded === false || strlen(trim($decoded)) < 6) {
                echo utilities::apiMessage('Password must be at least 6 characters.', 422);
                return;
            }
            $update['password'] = password_hash($decoded, PASSWORD_DEFAULT);
        }

        if (isset($_POST['fcm_token'])) {
            $update['fcm_token'] = $this->str('fcm_token');
        }

        if (empty($update)) {
            echo utilities::apiMessage('No changes provided.', 400);
            return;
        }

        $this->update('users', $update, "id = '{$me['id']}'");

        $user = $this->getall('users', 'id = ?', [$me['id']]);
        unset($user['password'], $user['reset_code']);

        $this->logActivity('customer', $me['id'], 'profile_updated');

        echo utilities::apiMessage('Profile updated successfully.', 200, $user);
    }

    // ── POST /auth/send-contact-otp ───────────────────────────────────────────
    // Authenticated — sends OTP to a NEW phone/email the user wants to set.
    public function sendContactOtp(): void
    {
        $err = $this->requireFields(['contact', 'type']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $type    = trim($this->str('type')); // 'phone' or 'email'

        if (!in_array($type, ['phone', 'email'], true)) {
            echo utilities::apiMessage('type must be phone or email.', 422);
            return;
        }

        if ($type === 'phone' && !$this->isNigeriaPhone($contact)) {
            echo utilities::apiMessage('Only Nigerian phone numbers are supported (+234 / 07x / 08x / 09x).', 422);
            return;
        }
        if ($type === 'email' && !filter_var($contact, FILTER_VALIDATE_EMAIL)) {
            echo utilities::apiMessage('Enter a valid email address.', 422);
            return;
        }

        // Prefix distinguishes contact-change OTPs from login OTPs
        $contactKey = ($type === 'phone' ? 'change_phone:' : 'change_email:') . $contact;

        $otp     = str_pad((string) mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
        $hash    = password_hash($otp, PASSWORD_DEFAULT);
        $expires = date('Y-m-d H:i:s', time() + 600); // 10 minutes

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
        if ($type === 'email') {
            $this->mailer->sendOtpEmail($contact, $otp, $appName);
        } else {
            require_once ROOT . 'functions/sms.php';
            Sms::send($contact, "Your $appName code: $otp. Valid 10 mins.");
        }

        $devMode = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $extra   = $devMode ? ['_dev_otp' => $otp] : [];

        echo utilities::apiMessage('OTP sent successfully.', 200, array_merge(['contact' => $contact, 'type' => $type], $extra));
    }

    // ── POST /auth/verify-contact-otp ─────────────────────────────────────────
    // Authenticated — verifies OTP for contact change; returns a verification_token.
    public function verifyContactOtp(): void
    {
        $err = $this->requireFields(['contact', 'type', 'otp']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $type    = trim($this->str('type'));
        $otp     = trim($this->str('otp'));

        $devMode    = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $contactKey = ($type === 'phone' ? 'change_phone:' : 'change_email:') . $contact;
        $bypass     = $devMode && $otp === '123456';

        if (!$bypass) {
            $stmt = $this->db->prepare(
                "SELECT * FROM otp_requests
                 WHERE contact = ? AND used = 0 AND expires_at > NOW()
                 ORDER BY created_at DESC LIMIT 1"
            );
            $stmt->execute([$contactKey]);
            $otpRow = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$otpRow || !password_verify($otp, $otpRow['otp_hash'])) {
                echo utilities::apiMessage('Invalid or expired code.', 400);
                return;
            }

            // Mark used and store verification token
            $token = bin2hex(random_bytes(32));
            $this->update('otp_requests', ['used' => 1, 'verification_token' => $token], "id = '{$otpRow['id']}'");
        } else {
            $token = 'dev_bypass_' . bin2hex(random_bytes(8));
            // Store a dev-mode row so the profile update check passes
            $this->delete('otp_requests', 'contact = ?', [$contactKey]);
            $this->quick_insert('otp_requests', [
                'id'                 => utilities::genID('OTP_', 10),
                'contact'            => $contactKey,
                'contact_type'       => $type,
                'otp_hash'           => password_hash('used', PASSWORD_DEFAULT),
                'expires_at'         => date('Y-m-d H:i:s', time() + 600),
                'used'               => 1,
                'verification_token' => $token,
            ]);
        }

        echo utilities::apiMessage('Contact verified.', 200, ['verification_token' => $token]);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Validates Nigerian phone numbers: +234xxxxxxxxxx, 07x, 08x, 09x */
    private function isNigeriaPhone(string $phone): bool
    {
        return (bool) preg_match('/^(\+?234|0)[789]\d{9}$/', preg_replace('/[\s\-()]/', '', $phone));
    }

    /**
     * Checks that a verification_token exists in otp_requests for the given contactKey,
     * and deletes it (one-time use).
     */
    private function consumeContactToken(string $contactKey, string $token): bool
    {
        if ($token === '') return false;
        $stmt = $this->db->prepare(
            "SELECT id FROM otp_requests
             WHERE contact = ? AND verification_token = ? AND used = 1 AND expires_at > NOW()
             LIMIT 1"
        );
        $stmt->execute([$contactKey, $token]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) return false;
        // Consume: delete so the token can't be reused
        $this->delete('otp_requests', 'id = ?', [$row['id']]);
        return true;
    }

    // ── POST /auth/send-otp ───────────────────────────────────────────────────
    // Public — accepts email OR phone, creates user if new, sends OTP.
    public function sendOtp(): void
    {
        $err = $this->requireFields(['contact']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $isEmail = (bool) filter_var($contact, FILTER_VALIDATE_EMAIL);
        $type    = $isEmail ? 'email' : 'phone';

        // Find existing user
        $user = $this->getall('users', "$type = ?", [$contact]);

        if (!is_array($user)) {
            // Create minimal user record
            $id = utilities::genID('USR_', 10);
            $inserted = $this->quick_insert('users', [
                'id'     => $id,
                'email'  => $isEmail ? $contact : null,
                'phone'  => $isEmail ? null : $contact,
                'name'   => null,
                'password' => null,
                'status' => 0,
            ]);
            if (!$inserted) {
                echo utilities::apiMessage('Could not create account. Please try again.', 500);
                return;
            }
            $user = $this->getall('users', 'id = ?', [$id]);
        }

        // Generate 6-digit OTP
        $otp     = str_pad((string) mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
        $hash    = password_hash($otp, PASSWORD_DEFAULT);
        $expires = date('Y-m-d H:i:s', time() + 600); // 10 minutes

        // Invalidate old OTPs for this contact
        $this->delete('otp_requests', 'contact = ? AND used = 0', [$contact]);

        $this->quick_insert('otp_requests', [
            'id'           => utilities::genID('OTP_', 10),
            'contact'      => $contact,
            'contact_type' => $type,
            'otp_hash'     => $hash,
            'expires_at'   => $expires,
            'used'         => 0,
        ]);

        $appName = $this->setting('app_name', 'ETCRide');
        $sent    = false;

        if ($isEmail) {
            $sent = $this->mailer->sendOtpEmail($contact, $otp, $appName);
        } else {
            require_once ROOT . 'functions/sms.php';
            $sent = Sms::send($contact, "Your $appName code is: $otp. Valid for 10 mins.");
        }

        // In non-production, always include OTP in response so devs can test
        $devMode = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $extra   = $devMode ? ['_dev_otp' => $otp] : [];

        echo utilities::apiMessage('OTP sent successfully.', 200, array_merge([
            'contact'      => $contact,
            'contact_type' => $type,
        ], $extra));
    }

    // ── POST /auth/verify-otp ─────────────────────────────────────────────────
    // Public — verifies OTP, creates session, returns user + token.
    public function verifyOtp(): void
    {
        $err = $this->requireFields(['contact', 'otp']);
        if ($err) { echo $err; return; }

        $contact = trim($this->str('contact'));
        $otp     = trim($this->str('otp'));
        $devMode = defined('APP_ENV') ? (APP_ENV !== 'production') : (strtolower((string) ($_ENV['APP_ENV'] ?? 'development')) !== 'production');
        $isEmail = (bool) filter_var($contact, FILTER_VALIDATE_EMAIL);
        $type    = $isEmail ? 'email' : 'phone';

        $user = $this->getall('users', "$type = ?", [$contact]);
        if (!is_array($user)) {
            echo utilities::apiMessage('Account not found. Please start again.', 404);
            return;
        }

        $bypass = $devMode && $otp === '123456';

        if (!$bypass) {
            // Find latest valid OTP for this contact
            $stmt = $this->db->prepare(
                "SELECT * FROM otp_requests
                 WHERE contact = ? AND used = 0 AND expires_at > NOW()
                 ORDER BY created_at DESC LIMIT 1"
            );
            $stmt->execute([$contact]);
            $otpRow = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$otpRow || !password_verify($otp, $otpRow['otp_hash'])) {
                echo utilities::apiMessage('Invalid or expired code. Please try again.', 400);
                return;
            }

            // Mark OTP used
            $this->update('otp_requests', ['used' => 1], "id = '{$otpRow['id']}'");
        }

        // Mark user verified
        $this->update('users', ['status' => 1], "id = '{$user['id']}'");

        // Create session
        $token     = $this->generateToken();
        $expiresAt = date('Y-m-d H:i:s', time() + 86400 * 30);

        $this->delete('user_sessions', 'user_id = ?', [$user['id']]);
        $this->quick_insert('user_sessions', [
            'id'         => utilities::genID('USS_', 10),
            'user_id'    => $user['id'],
            'token'      => $token,
            'expires_at' => $expiresAt,
            'device'     => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
            'ip'         => $_SERVER['REMOTE_ADDR'] ?? '',
        ]);

        $this->logActivity('customer', $user['id'], 'otp_login');

        $user['hasPassword'] = !empty($user['password']);
        unset($user['password'], $user['reset_code']);
        $user['token']      = $token;
        $user['expires_at'] = $expiresAt;

        echo utilities::apiMessage('Verified successfully.', 200, $user);
    }
}
