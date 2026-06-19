<?php
require_once ROOT . 'functions/BaseController.php';

class Vehicles extends BaseController
{
    private string $uploadDir = ROOT . 'api/uploads/vehicles/';

    private function saveUpload(string $field, string $prefix): ?string
    {
        if (empty($_FILES[$field]['name']) || ($_FILES[$field]['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
            return null;
        }

        $allowed = ['image/jpeg', 'image/png', 'image/webp'];
        $tmp = $_FILES[$field]['tmp_name'] ?? '';
        if (!is_string($tmp) || $tmp === '') {
            return null;
        }

        $mime = mime_content_type($tmp);
        if (!in_array($mime, $allowed, true) || (int) ($_FILES[$field]['size'] ?? 0) > 5 * 1024 * 1024) {
            return null;
        }

        $ext = strtolower(pathinfo($_FILES[$field]['name'], PATHINFO_EXTENSION));
        $filename = $prefix . '_' . uniqid() . '.' . $ext;

        if (!is_dir($this->uploadDir)) {
            mkdir($this->uploadDir, 0755, true);
        }

        move_uploaded_file($tmp, $this->uploadDir . $filename);
        return $filename;
    }

    private function photoUrl(?string $f): ?string
    {
        return $this->uploadUrl('vehicles', $f);
    }

    private function mapVehicleRecord(array $vehicle): array
    {
        if (array_key_exists('photo', $vehicle)) {
            $vehicle['photo_url'] = $this->photoUrl($vehicle['photo'] ?? null);
        }
        return $vehicle;
    }

    // ── GET /admin/vehicles ───────────────────────────────────────────────────
    public function index(): void
    {
        $typeId = $this->query('vehicle_type_id', '');
        $status = $this->query('status', '');
        $page   = max(1, (int) $this->query('page', 1));
        $perPage = 25;
        $offset  = ($page - 1) * $perPage;

        $conditions = [];
        $params     = [];

        if ($typeId !== '') { $conditions[] = 'v.vehicle_type_id = ?'; $params[] = $typeId; }
        if ($status !== '') { $conditions[] = 'v.status = ?';          $params[] = $status; }

        $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        $stmt = $this->db->prepare(
            "SELECT v.*, vt.name AS vehicle_type_name,
                    d.id AS driver_id, d.name AS driver_name, d.phone AS driver_phone
             FROM vehicles v
             LEFT JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
             LEFT JOIN drivers d ON d.vehicle_id = v.id
             $where
             ORDER BY v.created_at DESC
             LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($rows as &$row) {
            if (is_array($row)) $row = $this->mapVehicleRecord($row);
        }

        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM vehicles v $where");
        $countStmt->execute($params);

        echo utilities::apiMessage('Vehicles retrieved.', 200, [
            'total'    => (int) $countStmt->fetchColumn(),
            'page'     => $page,
            'per_page' => $perPage,
            'data'     => $rows,
        ]);
    }

    // ── POST /admin/vehicles ──────────────────────────────────────────────────
    public function create(): void
    {
        $me  = BaseController::$authAdmin;
        $err = $this->requireFields(['vehicle_type_id', 'plate_number']);
        if ($err) { echo $err; return; }

        $plate = strtoupper($this->str('plate_number'));

        if ($this->getall('vehicles', 'plate_number = ?', [$plate], fetch: '') > 0) {
            echo utilities::apiMessage('Plate number already registered.', 409);
            return;
        }

        $vtId = $this->str('vehicle_type_id');
        if (!is_array($this->getall('vehicle_types', 'id = ?', [$vtId]))) {
            echo utilities::apiMessage('Invalid vehicle type.', 400);
            return;
        }

        $id = utilities::genID('VCL_', 10);
        $fields = [
            'id'              => $id,
            'vehicle_type_id' => $vtId,
            'plate_number'    => $plate,
            'make'            => $this->str('make'),
            'model'           => $this->str('model'),
            'color'           => $this->str('color'),
            'year'            => $this->str('year') ?: null,
            'status'          => 'active',
        ];

        $wantsPhoto = !empty($_FILES['photo']['name']);
        if ($wantsPhoto && !$this->tableHasColumn('vehicles', 'photo')) {
            echo utilities::apiMessage('Vehicle photo upload is not enabled on this server.', 400);
            return;
        }
        if ($wantsPhoto) {
            $photoFile = $this->saveUpload('photo', $id);
            if ($photoFile === null) {
                echo utilities::apiMessage('Invalid vehicle photo. Use jpeg/png/webp up to 5MB.', 422);
                return;
            }
            $fields['photo'] = $photoFile;
        }

        $this->quick_insert('vehicles', $fields);

        $this->logActivity('admin', $me['id'], 'vehicle_created', ['id' => $id, 'plate' => $plate]);

        echo utilities::apiMessage('Vehicle created.', 201, ['id' => $id, 'plate_number' => $plate]);
    }

    // ── GET /admin/vehicles/:id ───────────────────────────────────────────────
    public function show(string $id): void
    {
        $stmt = $this->db->prepare(
            "SELECT v.*, vt.name AS vehicle_type_name,
                    d.id AS driver_id, d.name AS driver_name, d.phone AS driver_phone
             FROM vehicles v
             LEFT JOIN vehicle_types vt ON vt.id = v.vehicle_type_id
             LEFT JOIN drivers d ON d.vehicle_id = v.id
             WHERE v.id = ?"
        );
        $stmt->execute([$id]);
        $vehicle = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$vehicle) { echo utilities::apiMessage('Vehicle not found.', 404); return; }

        echo utilities::apiMessage('Vehicle retrieved.', 200, $this->mapVehicleRecord($vehicle));
    }

    // ── PUT /admin/vehicles/:id ───────────────────────────────────────────────
    public function edit(string $id): void
    {
        $me = BaseController::$authAdmin;
        if (!is_array($this->getall('vehicles', 'id = ?', [$id]))) {
            echo utilities::apiMessage('Vehicle not found.', 404); return;
        }

        $fields = [];
        foreach (['make', 'model', 'color'] as $f) {
            if ($this->str($f) !== '') $fields[$f] = $this->str($f);
        }
        if ($this->str('year') !== '') $fields['year'] = $this->str('year');
        if ($this->str('vehicle_type_id') !== '') $fields['vehicle_type_id'] = $this->str('vehicle_type_id');

        if ($this->str('plate_number') !== '') {
            $plate  = strtoupper($this->str('plate_number'));
            $exists = $this->db->prepare('SELECT COUNT(*) FROM vehicles WHERE plate_number = ? AND id != ?');
            $exists->execute([$plate, $id]);
            if ((int) $exists->fetchColumn() > 0) {
                echo utilities::apiMessage('Plate number already in use.', 409); return;
            }
            $fields['plate_number'] = $plate;
        }

        $wantsPhoto = !empty($_FILES['photo']['name']);
        if ($wantsPhoto && !$this->tableHasColumn('vehicles', 'photo')) {
            echo utilities::apiMessage('Vehicle photo upload is not enabled on this server.', 400);
            return;
        }
        if ($wantsPhoto) {
            $photoFile = $this->saveUpload('photo', $id);
            if ($photoFile === null) {
                echo utilities::apiMessage('Invalid vehicle photo. Use jpeg/png/webp up to 5MB.', 422);
                return;
            }
            $fields['photo'] = $photoFile;
        }

        if (empty($fields)) { echo utilities::apiMessage('No fields to update.', 400); return; }

        $this->update('vehicles', $fields, "id = '$id'");
        $this->logActivity('admin', $me['id'], 'vehicle_updated', ['id' => $id]);

        echo utilities::apiMessage('Vehicle updated.', 200);
    }

    // ── PUT /admin/vehicles/:id/status ────────────────────────────────────────
    public function toggleStatus(string $id): void
    {
        $me      = BaseController::$authAdmin;
        $vehicle = $this->getall('vehicles', 'id = ?', [$id]);
        if (!is_array($vehicle)) { echo utilities::apiMessage('Vehicle not found.', 404); return; }

        $newStatus = $vehicle['status'] === 'active' ? 'inactive' : 'active';
        $this->update('vehicles', ['status' => $newStatus], "id = '$id'");

        // If deactivating, unassign from driver
        if ($newStatus === 'inactive') {
            $this->db->prepare("UPDATE drivers SET vehicle_id = NULL WHERE vehicle_id = ?")
                     ->execute([$id]);
        }

        $this->logActivity('admin', $me['id'], "vehicle_$newStatus", ['id' => $id]);

        echo utilities::apiMessage("Vehicle $newStatus.", 200, ['status' => $newStatus]);
    }
}
