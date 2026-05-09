<?php
require_once ROOT . 'functions/BaseController.php';

class Zones extends BaseController
{
    // ── GET /admin/zones ──────────────────────────────────────────────────────
    public function index(): void
    {
        $stmt = $this->db->query(
            "SELECT z.*, COUNT(zp.id) AS pricing_entries
             FROM zones z
             LEFT JOIN zone_pricing zp ON zp.zone_id = z.id
             GROUP BY z.id
             ORDER BY z.is_default DESC, z.name ASC"
        );
        echo utilities::apiMessage('Zones retrieved.', 200, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    // ── POST /admin/zones ─────────────────────────────────────────────────────
    public function create(): void
    {
        $me  = BaseController::$authAdmin;
        $err = $this->requireFields(['name']);
        if ($err) { echo $err; return; }

        $name = $this->str('name');
        if ($this->getall('zones', 'name = ?', [$name], fetch: '') > 0) {
            echo utilities::apiMessage('A zone with this name already exists.', 409);
            return;
        }

        $id = utilities::genID('ZNE_', 10);
        $this->quick_insert('zones', [
            'id'          => $id,
            'name'        => $name,
            'description' => $this->str('description'),
            'is_default'  => 0,
            'is_active'   => 1,
        ]);

        $this->logActivity('admin', $me['id'], 'zone_created', ['id' => $id, 'name' => $name]);

        echo utilities::apiMessage('Zone created.', 201, ['id' => $id, 'name' => $name]);
    }

    // ── PUT /admin/zones/:id ──────────────────────────────────────────────────
    public function edit(string $id): void
    {
        $me   = BaseController::$authAdmin;
        $zone = $this->getall('zones', 'id = ?', [$id]);
        if (!is_array($zone)) { echo utilities::apiMessage('Zone not found.', 404); return; }

        $fields = [];
        if ($this->str('name')        !== '') $fields['name']        = $this->str('name');
        if ($this->str('description') !== '') $fields['description'] = $this->str('description');
        if (isset($_POST['is_active'])) {
            $fields['is_active'] = filter_var($_POST['is_active'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
        }

        if (empty($fields)) { echo utilities::apiMessage('No fields to update.', 400); return; }

        $this->update('zones', $fields, "id = '$id'");
        $this->logActivity('admin', $me['id'], 'zone_updated', ['id' => $id]);

        echo utilities::apiMessage('Zone updated.', 200);
    }

    // ── DELETE /admin/zones/:id ───────────────────────────────────────────────
    public function remove(string $id): void
    {
        $me   = BaseController::$authAdmin;
        $zone = $this->getall('zones', 'id = ?', [$id]);
        if (!is_array($zone)) { echo utilities::apiMessage('Zone not found.', 404); return; }

        if ((int) $zone['is_default'] === 1) {
            echo utilities::apiMessage('Cannot delete the default zone.', 403);
            return;
        }

        $this->delete('zone_pricing', 'zone_id = ?', [$id]);
        $this->delete('zones', 'id = ?', [$id]);
        $this->logActivity('admin', $me['id'], 'zone_deleted', ['id' => $id]);

        echo utilities::apiMessage('Zone deleted.', 200);
    }

    // ── GET /admin/zones/:id/pricing ─────────────────────────────────────────
    public function pricing(string $id): void
    {
        $zone = $this->getall('zones', 'id = ?', [$id]);
        if (!is_array($zone)) { echo utilities::apiMessage('Zone not found.', 404); return; }

        $stmt = $this->db->prepare(
            "SELECT zp.*, vt.name AS vehicle_type_name
             FROM zone_pricing zp
             JOIN vehicle_types vt ON vt.id = zp.vehicle_type_id
             WHERE zp.zone_id = ?
             ORDER BY vt.name ASC"
        );
        $stmt->execute([$id]);

        echo utilities::apiMessage('Zone pricing retrieved.', 200, [
            'zone'    => $zone,
            'pricing' => $stmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }

    // ── POST /admin/zones/:id/pricing ─────────────────────────────────────────
    // Set (upsert) pricing for a specific vehicle type in this zone
    public function setPricing(string $id): void
    {
        $me  = BaseController::$authAdmin;
        $err = $this->requireFields(['vehicle_type_id', 'base_fare', 'per_km_rate', 'per_stop_fee']);
        if ($err) { echo $err; return; }

        $zone = $this->getall('zones', 'id = ?', [$id]);
        if (!is_array($zone)) { echo utilities::apiMessage('Zone not found.', 404); return; }

        $vtId = $this->str('vehicle_type_id');
        if (!is_array($this->getall('vehicle_types', 'id = ?', [$vtId]))) {
            echo utilities::apiMessage('Invalid vehicle type.', 400); return;
        }

        // Upsert
        $existing = $this->getall('zone_pricing', 'zone_id = ? AND vehicle_type_id = ?', [$id, $vtId]);

        $data = [
            'base_fare'    => $this->flt('base_fare'),
            'per_km_rate'  => $this->flt('per_km_rate'),
            'per_stop_fee' => $this->flt('per_stop_fee'),
            'is_active'    => 1,
        ];

        if (is_array($existing)) {
            $this->update('zone_pricing', $data, "zone_id = '$id' AND vehicle_type_id = '$vtId'");
            $msg = 'Zone pricing updated.';
        } else {
            $data['id']              = utilities::genID('ZPR_', 10);
            $data['zone_id']         = $id;
            $data['vehicle_type_id'] = $vtId;
            $this->quick_insert('zone_pricing', $data);
            $msg = 'Zone pricing set.';
        }

        $this->logActivity('admin', $me['id'], 'zone_pricing_set',
            ['zone_id' => $id, 'vehicle_type_id' => $vtId]);

        echo utilities::apiMessage($msg, 200);
    }

    // ── DELETE /admin/zones/:id/pricing/:pricing_id ───────────────────────────
    public function removePricing(string $id, string $pricingId): void
    {
        $me = BaseController::$authAdmin;
        $this->delete('zone_pricing', 'id = ? AND zone_id = ?', [$pricingId, $id]);
        $this->logActivity('admin', $me['id'], 'zone_pricing_removed',
            ['zone_id' => $id, 'pricing_id' => $pricingId]);
        echo utilities::apiMessage('Zone pricing entry removed.', 200);
    }
}
