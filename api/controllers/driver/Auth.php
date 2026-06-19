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

    private function photoUrl(?string $file): ?string
    {
        return $this->uploadUrl('drivers', $file);
    }

    private function vehiclePhotoUrl(?string $file): ?string
    {
        return $this->uploadUrl('vehicles', $file);
    }

    private function assignedVehiclePayload(?string $vehicleId): ?array
    {
        if (!$vehicleId) {
            return null;
        }

        $withPhoto = $this->tableHasColumn('vehicles', 'photo');
        $stmt = $this->db->prepare(
            "SELECT v.id, v.plate_number, v.make, v.model, v.color, v.year, v.status," .
            ($withPhoto ? " v.photo," : "") .
            " vt.name AS vehicle_type_name
             FROM vehicles v
             LEFT JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
             WHERE v.id = ?
             LIMIT 1"
        );
        $stmt->execute([$vehicleId]);
        $vehicle = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!is_array($vehicle)) {
            return null;
        }

        $payload = [
            'id' => $vehicle['id'],
            'plate_number' => $vehicle['plate_number'] ?? null,
            'make' => $vehicle['make'] ?? null,
            'model' => $vehicle['model'] ?? null,
            'color' => $vehicle['color'] ?? null,
            'year' => $vehicle['year'] ?? null,
            'status' => $vehicle['status'] ?? null,
            'vehicle_type' => $vehicle['vehicle_type_name'] ?? null,
        ];

        if ($withPhoto) {
            $payload['photo'] = $vehicle['photo'] ?? null;
            $payload['photo_url'] = $this->vehiclePhotoUrl($vehicle['photo'] ?? null);
        }

        return $payload;
    }

    private function driverPayload(array $driver, array $extra = []): array
    {
        unset($driver['password'], $driver['reset_code']);

        $driver['photo_url'] = $this->photoUrl($driver['photo'] ?? null);
        $driver['profile_photo'] = $driver['photo'] ?? null;
        $driver['profile_photo_url'] = $driver['photo_url'];
        $driver['kyc_front_url'] = $this->photoUrl($driver['kyc_id_front'] ?? null);
        $driver['kyc_back_url'] = $this->photoUrl($driver['kyc_id_back'] ?? null);
        $driver['driving_experience'] = $driver['driving_experience'] ?? null;
        $driver['kyc_note'] = $driver['kyc_note'] ?? null;
        $driver['rejection_reason'] = $driver['kyc_note'];
        $driver['assigned_vehicle'] = $this->assignedVehiclePayload($driver['vehicle_id'] ?? null);

        return array_merge($driver, $extra);
    }

    // ── POST /driver/auth/login ───────────────────────────────────────────────
    public function login(): void
    {
        if (!in_array($this->driverAuthMode(), ['password', 'both'], true)) {
            echo utilities::apiMessage('Password login is disabled. Use OTP login.', 403);
            return;
        }

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

        echo utilities::apiMessage('Login successful.', 200, $this->driverPayload($driver, [
            'token' => $token,
            'expires_at' => $expiresAt,
        ]));
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
        echo utilities::apiMessage('Driver registered successfully.', 201, $this->driverPayload([
            'id'         => $id,
            'name'       => $name,
            'phone'      => $phone,
            'email'      => $email !== '' ? $email : null,
            'photo'      => null,
            'kyc_id_front' => null,
            'kyc_id_back' => null,
            'driving_experience' => null,
            'kyc_note' => null,
            'kyc_status' => 'not_submitted',
        ]));
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

        echo utilities::apiMessage('Verified successfully.', 200, $this->driverPayload($driver, [
            'token' => $token,
            'expires_at' => $expiresAt,
        ]));
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
        $driver = $this->getall('drivers', 'id = ?', [$me['id']]);

        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver account not found.', 404);
            return;
        }

        echo utilities::apiMessage('Profile retrieved.', 200, $this->driverPayload($driver));
    }

    // ── PUT /driver/auth/profile ──────────────────────────────────────────────
    public function updateProfile(): void
    {
        $me     = BaseController::$authDriver;
        $fields = [];

        if ($this->input('name') !== null) {
            $name = trim((string) $this->input('name', ''));
            if ($name === '') {
                echo utilities::apiMessage('Name is required.', 422);
                return;
            }
            $fields['name'] = $name;
        }

        if ($this->input('email') !== null) {
            $email = trim((string) $this->input('email', ''));
            if ($email === '') {
                $fields['email'] = null;
            } else {
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                    echo utilities::apiMessage('Enter a valid email address.', 422);
                    return;
                }

                $exists = $this->db->prepare('SELECT COUNT(*) FROM drivers WHERE email = ? AND id != ?');
                $exists->execute([$email, $me['id']]);
                if ((int) $exists->fetchColumn() > 0) {
                    echo utilities::apiMessage('Email already in use.', 409);
                    return;
                }

                $fields['email'] = $email;
            }
        }

        if ($this->str('fcm_token') !== '') $fields['fcm_token'] = $this->str('fcm_token');

        if (empty($fields)) {
            echo utilities::apiMessage('No fields to update.', 400);
            return;
        }

        $this->update('drivers', $fields, "id = '{$me['id']}'");
        $driver = $this->getall('drivers', 'id = ?', [$me['id']]);
        if (!is_array($driver)) {
            echo utilities::apiMessage('Driver account not found.', 404);
            return;
        }

        echo utilities::apiMessage('Profile updated.', 200, $this->driverPayload($driver));
    }
}
