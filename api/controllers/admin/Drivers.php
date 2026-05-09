<?php
require_once ROOT . 'functions/BaseController.php';

class Drivers extends BaseController
{
    private string $uploadDir = ROOT . 'api/uploads/drivers/';

    private function saveUpload(string $field, string $prefix): ?string
    {
        if (empty($_FILES[$field]['name']) || $_FILES[$field]['error'] !== UPLOAD_ERR_OK) return null;
        $allowed = ['image/jpeg', 'image/png', 'image/webp'];
        $mime    = mime_content_type($_FILES[$field]['tmp_name']);
        if (!in_array($mime, $allowed, true) || $_FILES[$field]['size'] > 5 * 1024 * 1024) return null;
        $ext      = strtolower(pathinfo($_FILES[$field]['name'], PATHINFO_EXTENSION));
        $filename = $prefix . '_' . uniqid() . '.' . $ext;
        if (!is_dir($this->uploadDir)) mkdir($this->uploadDir, 0755, true);
        move_uploaded_file($_FILES[$field]['tmp_name'], $this->uploadDir . $filename);
        return $filename;
    }

    private function photoUrl(?string $f): ?string
    {
        if (!$f) return null;
        $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        return $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . '/uploads/drivers/' . $f;
    }

    // ── GET /admin/drivers ────────────────────────────────────────────────────
    public function index(): void
    {
        $search  = $this->query('search', '');
        $status  = $this->query('status', '');
        $online  = $this->query('online', '');
        $page    = max(1, (int) $this->query('page', 1));
        $perPage = 25;
        $offset  = ($page - 1) * $perPage;

        $conditions = [];
        $params     = [];

        if ($search !== '') {
            $conditions[] = '(d.name LIKE ? OR d.phone LIKE ? OR d.email LIKE ?)';
            $like = "%$search%";
            array_push($params, $like, $like, $like);
        }
        if ($status !== '') { $conditions[] = 'd.is_active = ?'; $params[] = $status === 'active' ? 1 : 0; }
        if ($online !== '') { $conditions[] = 'd.is_online = ?'; $params[] = (int) $online; }

        $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        $stmt = $this->db->prepare(
            "SELECT d.id, d.name, d.email, d.phone, d.photo, d.license_number,
                    d.is_active, d.is_online, d.kyc_status, d.last_seen, d.created_at,
                    v.id AS vehicle_id, v.plate_number, v.make, v.model, v.color,
                    vt.name AS vehicle_type
             FROM drivers d
             LEFT JOIN vehicles v       ON v.id  = d.vehicle_id
             LEFT JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
             $where ORDER BY d.created_at DESC LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as &$row) $row['photo_url'] = $this->photoUrl($row['photo']);

        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM drivers d $where");
        $countStmt->execute($params);

        echo utilities::apiMessage('Drivers retrieved.', 200, [
            'total' => (int) $countStmt->fetchColumn(), 'page' => $page,
            'per_page' => $perPage, 'data' => $rows,
        ]);
    }

    // ── POST /admin/drivers ───────────────────────────────────────────────────
    public function create(): void
    {
        $me  = BaseController::$authAdmin;
        $err = $this->requireFields(['name', 'phone', 'password']);
        if ($err) { echo $err; return; }

        $phone = $this->str('phone');
        $email = $this->str('email');

        if ($this->getall('drivers', 'phone = ?', [$phone], fetch: '') > 0) {
            echo utilities::apiMessage('Phone number already in use.', 409); return;
        }
        if ($email !== '' && $this->getall('drivers', 'email = ?', [$email], fetch: '') > 0) {
            echo utilities::apiMessage('Email already in use.', 409); return;
        }

        $decoded = base64_decode($this->input('password', ''), true);
        if ($decoded === false || strlen(trim($decoded)) < 6) {
            echo utilities::apiMessage('Password must be at least 6 characters.', 422); return;
        }

        $id        = utilities::genID('DRV_', 10);
        $photoFile = $this->saveUpload('photo', $id);
        $vehicleId = $this->str('vehicle_id') ?: null;

        if ($vehicleId !== null) {
            if (!is_array($this->getall('vehicles', "id = ? AND status = 'active'", [$vehicleId]))) {
                echo utilities::apiMessage('Vehicle not found or inactive.', 404); return;
            }
        }

        $kycIdType   = $this->str('kyc_id_type')   ?: null;
        $kycIdNumber = $this->str('kyc_id_number')  ?: null;
        $kycFront    = $kycIdType ? $this->saveUpload('kyc_id_front', $id . '_kf') : null;
        $kycBack     = $kycIdType ? $this->saveUpload('kyc_id_back',  $id . '_kb') : null;

        $this->quick_insert('drivers', [
            'id'             => $id,
            'name'           => $this->str('name'),
            'email'          => $email ?: null,
            'phone'          => $phone,
            'photo'          => $photoFile,
            'license_number' => $this->str('license_number') ?: null,
            'password'       => password_hash($decoded, PASSWORD_DEFAULT),
            'vehicle_id'     => $vehicleId,
            'kyc_id_type'    => $kycIdType,
            'kyc_id_number'  => $kycIdNumber,
            'kyc_id_front'   => $kycFront,
            'kyc_id_back'    => $kycBack,
            'kyc_status'     => $kycIdType ? 'pending' : 'not_submitted',
            'is_active'      => 1,
            'is_online'      => 0,
        ]);

        $this->logActivity('admin', $me['id'], 'driver_created', ['driver_id' => $id]);
        echo utilities::apiMessage('Driver created successfully.', 201, [
            'id' => $id, 'name' => $this->str('name'),
            'phone' => $phone, 'photo_url' => $this->photoUrl($photoFile),
        ]);
    }

    // ── GET /admin/drivers/:id ────────────────────────────────────────────────
    public function show(string $id): void
    {
        $stmt = $this->db->prepare(
            "SELECT d.*, v.plate_number, v.make, v.model, v.color, vt.name AS vehicle_type_name
             FROM drivers d
             LEFT JOIN vehicles v       ON v.id  = d.vehicle_id
             LEFT JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
             WHERE d.id = ?"
        );
        $stmt->execute([$id]);
        $driver = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$driver) { echo utilities::apiMessage('Driver not found.', 404); return; }

        unset($driver['password'], $driver['reset_code']);
        $driver['photo_url']     = $this->photoUrl($driver['photo'] ?? null);
        $driver['kyc_front_url'] = $this->photoUrl($driver['kyc_id_front'] ?? null);
        $driver['kyc_back_url']  = $this->photoUrl($driver['kyc_id_back']  ?? null);

        $s = $this->db->prepare(
            "SELECT COUNT(*) AS total, SUM(status='completed') AS completed,
                    SUM(status='cancelled') AS cancelled
             FROM bookings WHERE driver_id = ?"
        );
        $s->execute([$id]);
        $driver['stats'] = $s->fetch(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Driver retrieved.', 200, $driver);
    }

    // ── PUT /admin/drivers/:id ────────────────────────────────────────────────
    public function edit(string $id): void
    {
        $me     = BaseController::$authAdmin;
        $driver = $this->getall('drivers', 'id = ?', [$id]);
        if (!is_array($driver)) { echo utilities::apiMessage('Driver not found.', 404); return; }

        $fields = [];
        foreach (['name', 'email', 'license_number'] as $f) {
            if ($this->str($f) !== '') $fields[$f] = $this->str($f);
        }
        if ($this->str('phone') !== '') {
            $phone  = $this->str('phone');
            $exists = $this->db->prepare('SELECT COUNT(*) FROM drivers WHERE phone = ? AND id != ?');
            $exists->execute([$phone, $id]);
            if ((int) $exists->fetchColumn() > 0) {
                echo utilities::apiMessage('Phone number already in use.', 409); return;
            }
            $fields['phone'] = $phone;
        }
        if ($this->input('password') !== null) {
            $decoded = base64_decode($this->input('password', ''), true);
            if ($decoded && strlen(trim($decoded)) >= 6)
                $fields['password'] = password_hash($decoded, PASSWORD_DEFAULT);
        }

        $newPhoto = $this->saveUpload('photo', $id);
        if ($newPhoto) {
            if ($driver['photo'] && file_exists($this->uploadDir . $driver['photo']))
                unlink($this->uploadDir . $driver['photo']);
            $fields['photo'] = $newPhoto;
        }

        if (empty($fields)) { echo utilities::apiMessage('No fields to update.', 400); return; }

        $this->update('drivers', $fields, "id = '$id'");
        $this->logActivity('admin', $me['id'], 'driver_updated', ['driver_id' => $id]);
        echo utilities::apiMessage('Driver updated.', 200, [
            'photo_url' => $this->photoUrl($newPhoto ?? $driver['photo']),
        ]);
    }

    // ── PUT /admin/drivers/:id/kyc ────────────────────────────────────────────
    public function updateKyc(string $id): void
    {
        $me     = BaseController::$authAdmin;
        $driver = $this->getall('drivers', 'id = ?', [$id]);
        if (!is_array($driver)) { echo utilities::apiMessage('Driver not found.', 404); return; }

        $fields = [];
        foreach (['kyc_id_type', 'kyc_id_number', 'kyc_note'] as $f) {
            if ($this->str($f) !== '') $fields[$f] = $this->str($f);
        }

        $kycFront = $this->saveUpload('kyc_id_front', $id . '_kf');
        $kycBack  = $this->saveUpload('kyc_id_back',  $id . '_kb');
        if ($kycFront) $fields['kyc_id_front'] = $kycFront;
        if ($kycBack)  $fields['kyc_id_back']  = $kycBack;

        $newStatus = $this->str('kyc_status');
        if (in_array($newStatus, ['not_submitted', 'pending', 'verified', 'rejected'], true)) {
            $fields['kyc_status'] = $newStatus;
        }

        if (empty($fields)) { echo utilities::apiMessage('No fields to update.', 400); return; }

        $this->update('drivers', $fields, "id = '$id'");
        $this->logActivity('admin', $me['id'], 'driver_kyc_updated', ['driver_id' => $id]);
        echo utilities::apiMessage('KYC updated.', 200, [
            'kyc_status'    => $fields['kyc_status'] ?? $driver['kyc_status'],
            'kyc_front_url' => $this->photoUrl($kycFront ?? $driver['kyc_id_front']),
            'kyc_back_url'  => $this->photoUrl($kycBack  ?? $driver['kyc_id_back']),
        ]);
    }

    // ── PUT /admin/drivers/:id/status ─────────────────────────────────────────
    public function toggleStatus(string $id): void
    {
        $me     = BaseController::$authAdmin;
        $driver = $this->getall('drivers', 'id = ?', [$id]);
        if (!is_array($driver)) { echo utilities::apiMessage('Driver not found.', 404); return; }

        $newStatus = ((int) $driver['is_active'] === 1) ? 0 : 1;
        $this->update('drivers', ['is_active' => $newStatus], "id = '$id'");
        $label = $newStatus ? 'activated' : 'deactivated';
        $this->logActivity('admin', $me['id'], "driver_$label", ['driver_id' => $id]);
        echo utilities::apiMessage("Driver $label.", 200, ['is_active' => (bool) $newStatus]);
    }

    // ── POST /admin/drivers/:id/assign-vehicle ────────────────────────────────
    public function assignVehicle(string $id): void
    {
        $me        = BaseController::$authAdmin;
        $vehicleId = $this->str('vehicle_id');

        $driver = $this->getall('drivers', 'id = ?', [$id]);
        if (!is_array($driver)) { echo utilities::apiMessage('Driver not found.', 404); return; }

        if ($vehicleId !== '') {
            if (!is_array($this->getall('vehicles', "id = ? AND status = 'active'", [$vehicleId]))) {
                echo utilities::apiMessage('Vehicle not found or inactive.', 404); return;
            }
        }

        $this->update('drivers', ['vehicle_id' => $vehicleId ?: null], "id = '$id'");
        $this->logActivity('admin', $me['id'], 'vehicle_assigned_to_driver',
            ['driver_id' => $id, 'vehicle_id' => $vehicleId]);
        echo utilities::apiMessage($vehicleId ? 'Vehicle assigned.' : 'Vehicle unassigned.', 200);
    }
}
