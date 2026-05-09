<?php
require_once ROOT . 'functions/BaseController.php';

class VehicleTypes extends BaseController
{
    // ── GET /admin/vehicle-types ──────────────────────────────────────────────
    public function index(): void
    {
        $stmt = $this->db->query(
            "SELECT vt.*, COUNT(v.id) AS vehicle_count
             FROM vehicle_types vt
             LEFT JOIN vehicles v ON v.vehicle_type_id = vt.id
             GROUP BY vt.id
             ORDER BY vt.name ASC"
        );
        echo utilities::apiMessage('Vehicle types retrieved.', 200, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    // ── POST /admin/vehicle-types ─────────────────────────────────────────────
    public function create(): void
    {
        $me  = BaseController::$authAdmin;
        $err = $this->requireFields(['name', 'base_fare', 'per_km_rate', 'per_stop_fee']);
        if ($err) { echo $err; return; }

        $name = $this->str('name');
        if ($this->getall('vehicle_types', 'name = ?', [$name], fetch: '') > 0) {
            echo utilities::apiMessage('A vehicle type with this name already exists.', 409);
            return;
        }

        $id = utilities::genID('VTP_', 10);
        $this->quick_insert('vehicle_types', [
            'id'           => $id,
            'name'         => $name,
            'description'  => $this->str('description'),
            'icon'         => $this->str('icon'),
            'base_fare'    => $this->flt('base_fare'),
            'per_km_rate'  => $this->flt('per_km_rate'),
            'per_stop_fee' => $this->flt('per_stop_fee'),
            'is_active'    => 1,
        ]);

        $this->logActivity('admin', $me['id'], 'vehicle_type_created', ['id' => $id, 'name' => $name]);

        echo utilities::apiMessage('Vehicle type created.', 201, ['id' => $id, 'name' => $name]);
    }

    // ── PUT /admin/vehicle-types/:id ──────────────────────────────────────────
    public function edit(string $id): void
    {
        $me = BaseController::$authAdmin;
        $vt = $this->getall('vehicle_types', 'id = ?', [$id]);
        if (!is_array($vt)) { echo utilities::apiMessage('Vehicle type not found.', 404); return; }

        $fields = [];
        foreach (['name', 'description', 'icon'] as $f) {
            if ($this->str($f) !== '') $fields[$f] = $this->str($f);
        }
        foreach (['base_fare', 'per_km_rate', 'per_stop_fee'] as $f) {
            if (isset($_POST[$f])) $fields[$f] = $this->flt($f);
        }
        if (isset($_POST['is_active'])) {
            $fields['is_active'] = filter_var($_POST['is_active'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
        }

        if (empty($fields)) { echo utilities::apiMessage('No fields to update.', 400); return; }

        $this->update('vehicle_types', $fields, "id = '$id'");
        $this->logActivity('admin', $me['id'], 'vehicle_type_updated', ['id' => $id]);

        echo utilities::apiMessage('Vehicle type updated.', 200);
    }

    // ── DELETE /admin/vehicle-types/:id ───────────────────────────────────────
    public function remove(string $id): void
    {
        $me = BaseController::$authAdmin;

        // Guard: don't delete if vehicles are assigned
        $count = $this->getall('vehicles', 'vehicle_type_id = ?', [$id], fetch: '');
        if ((int) $count > 0) {
            echo utilities::apiMessage('Cannot delete: vehicles are using this type.', 409);
            return;
        }

        $this->delete('vehicle_types', 'id = ?', [$id]);
        $this->logActivity('admin', $me['id'], 'vehicle_type_deleted', ['id' => $id]);

        echo utilities::apiMessage('Vehicle type deleted.', 200);
    }
}
