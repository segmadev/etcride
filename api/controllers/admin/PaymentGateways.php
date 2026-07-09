<?php
require_once ROOT . 'functions/BaseController.php';

class PaymentGateways extends BaseController
{
    private string $uploadDir = ROOT . 'api/uploads/gateways/';

    private function saveUpload(string $field, string $prefix): ?string
    {
        if (empty($_FILES[$field]['name']) || ($_FILES[$field]['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
            return null;
        }

        $allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];
        $tmp = $_FILES[$field]['tmp_name'] ?? '';
        if (!is_string($tmp) || $tmp === '') {
            return null;
        }

        $mime = mime_content_type($tmp);
        if (!in_array($mime, $allowed, true) || (int) ($_FILES[$field]['size'] ?? 0) > 2 * 1024 * 1024) {
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

    private function logoUrl(?string $f): ?string
    {
        return $this->uploadUrl('gateways', $f);
    }

    private function mapRecord(array $row): array
    {
        $row['logo_url'] = $this->logoUrl($row['logo'] ?? null);
        return $row;
    }

    // ── GET /admin/payment-gateways ────────────────────────────────────────────
    public function list(): void
    {
        $stmt = $this->db->prepare("
            SELECT id, name, display_name, logo, is_enabled, priority,
                   min_amount, max_amount, transaction_fee_percent,
                   transaction_fee_fixed, created_at, updated_at
            FROM payment_gateways
            ORDER BY priority ASC, created_at ASC
        ");
        $stmt->execute();
        $gateways = array_map([$this, 'mapRecord'], $stmt->fetchAll(PDO::FETCH_ASSOC));

        echo utilities::apiMessage('Payment gateways retrieved.', 200, $gateways);
    }

    // ── GET /admin/payment-gateways/:id ────────────────────────────────────────
    public function get(string $id): void
    {
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        unset($gateway['secret_key']);
        unset($gateway['webhook_secret']);
        $gateway = $this->mapRecord($gateway);

        echo utilities::apiMessage('Gateway retrieved.', 200, $gateway);
    }

    // ── PUT /admin/payment-gateways/:id ────────────────────────────────────────
    public function updateGateway(string $id): void
    {
        $me = BaseController::$authAdmin;
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        $updateData = [];

        $fields = ['display_name', 'is_enabled', 'priority', 'min_amount', 'max_amount',
                   'transaction_fee_percent', 'transaction_fee_fixed', 'public_key', 'secret_key', 'webhook_secret'];

        foreach ($fields as $field) {
            $value = $_POST[$field] ?? null;
            if ($value !== null && $value !== '') {
                $updateData[$field] = $value;
            }
        }

        // Handle logo upload
        $logoFile = $this->saveUpload('logo', $gateway['name']);
        if ($logoFile) {
            // Delete old logo if present
            if (!empty($gateway['logo']) && file_exists($this->uploadDir . $gateway['logo'])) {
                unlink($this->uploadDir . $gateway['logo']);
            }
            $updateData['logo'] = $logoFile;
        }

        if (empty($updateData)) {
            echo utilities::apiMessage('No fields to update.', 422);
            return;
        }

        $this->update('payment_gateways', $updateData, "id = '$id'");

        $this->logActivity('admin', $me['id'], 'payment_gateway_updated',
            ['gateway_id' => $id, 'gateway_name' => $gateway['name']]);

        $updated = $this->getall('payment_gateways', 'id = ?', [$id]);
        unset($updated['secret_key']);
        unset($updated['webhook_secret']);
        $updated = $this->mapRecord($updated);

        echo utilities::apiMessage('Gateway updated successfully.', 200, $updated);
    }

    // ── POST /admin/payment-gateways/:id/logo ─────────────────────────────────
    public function uploadLogo(string $id): void
    {
        $me = BaseController::$authAdmin;
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        $logoFile = $this->saveUpload('logo', $gateway['name']);
        if (!$logoFile) {
            echo utilities::apiMessage('No valid image uploaded. Allowed: JPEG, PNG, WebP, SVG (max 2 MB).', 422);
            return;
        }

        // Delete old logo
        if (!empty($gateway['logo']) && file_exists($this->uploadDir . $gateway['logo'])) {
            unlink($this->uploadDir . $gateway['logo']);
        }

        $this->update('payment_gateways', ['logo' => $logoFile], "id = '$id'");
        $this->logActivity('admin', $me['id'], 'payment_gateway_logo_updated',
            ['gateway_id' => $id, 'gateway_name' => $gateway['name']]);

        echo utilities::apiMessage('Logo uploaded successfully.', 200, [
            'logo_url' => $this->logoUrl($logoFile),
        ]);
    }

    // ── POST /admin/payment-gateways/:id/toggle ────────────────────────────────
    public function toggle(string $id): void
    {
        $me = BaseController::$authAdmin;
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        $newStatus = $gateway['is_enabled'] ? 0 : 1;
        $this->update('payment_gateways', ['is_enabled' => $newStatus], "id = '$id'");

        $this->logActivity('admin', $me['id'], 'payment_gateway_toggled',
            ['gateway_id' => $id, 'gateway_name' => $gateway['name'], 'new_status' => $newStatus]);

        echo utilities::apiMessage(
            ($newStatus ? 'Gateway enabled' : 'Gateway disabled') . ' successfully.',
            200,
            ['is_enabled' => $newStatus]
        );
    }

    // ── GET /customer/payment-gateways ─────────────────────────────────────────
    public function enabledGateways(): void
    {
        $stmt = $this->db->prepare("
            SELECT id, name, display_name, logo, min_amount, max_amount,
                   transaction_fee_percent, transaction_fee_fixed
            FROM payment_gateways
            WHERE is_enabled = 1
            ORDER BY priority ASC
        ");
        $stmt->execute();
        $gateways = array_map([$this, 'mapRecord'], $stmt->fetchAll(PDO::FETCH_ASSOC));

        echo utilities::apiMessage('Enabled gateways retrieved.', 200, $gateways);
    }

    // ── GET /admin/payment-gateways/stats ──────────────────────────────────────
    public function stats(): void
    {
        $stmt = $this->db->prepare("
            SELECT
                pg.name,
                pg.display_name,
                COUNT(p.id) as total_transactions,
                SUM(CASE WHEN p.status = 'paid' THEN p.amount ELSE 0 END) as total_amount,
                COUNT(CASE WHEN p.status = 'paid' THEN 1 END) as successful_count,
                COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_count,
                COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_count,
                MAX(p.updated_at) as last_transaction
            FROM payment_gateways pg
            LEFT JOIN payments p ON p.provider = pg.name
            WHERE pg.is_enabled = 1
            GROUP BY pg.id, pg.name, pg.display_name
            ORDER BY pg.priority ASC
        ");
        $stmt->execute();
        $stats = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Gateway statistics retrieved.', 200, $stats);
    }
}
