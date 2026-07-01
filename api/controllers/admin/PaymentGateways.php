<?php
require_once ROOT . 'functions/BaseController.php';

class PaymentGateways extends BaseController
{
    // ── GET /admin/payment-gateways ────────────────────────────────────────────
    /**
     * List all payment gateways with their settings
     */
    public function list(): void
    {
        $stmt = $this->db->prepare("
            SELECT id, name, display_name, is_enabled, priority,
                   min_amount, max_amount, transaction_fee_percent,
                   transaction_fee_fixed, created_at, updated_at
            FROM payment_gateways
            ORDER BY priority ASC, created_at ASC
        ");
        $stmt->execute();
        $gateways = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Payment gateways retrieved.', 200, $gateways);
    }

    // ── GET /admin/payment-gateways/:id ────────────────────────────────────────
    /**
     * Get a specific payment gateway with all details
     */
    public function get(string $id): void
    {
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        // Don't expose secret key in response
        unset($gateway['secret_key']);
        unset($gateway['webhook_secret']);

        echo utilities::apiMessage('Gateway retrieved.', 200, $gateway);
    }

    // ── PUT /admin/payment-gateways/:id ────────────────────────────────────────
    /**
     * Update payment gateway settings
     */
    public function update(string $id): void
    {
        $me = BaseController::$authAdmin;
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        $updateData = [];

        // Allow updating these fields
        $fields = ['display_name', 'is_enabled', 'priority', 'min_amount', 'max_amount',
                   'transaction_fee_percent', 'transaction_fee_fixed', 'public_key', 'secret_key', 'webhook_secret'];

        foreach ($fields as $field) {
            $value = $_POST[$field] ?? null;
            if ($value !== null && $value !== '') {
                $updateData[$field] = $value;
            }
        }

        if (empty($updateData)) {
            echo utilities::apiMessage('No fields to update.', 422);
            return;
        }

        $this->update('payment_gateways', $updateData, "id = ?", [$id]);

        $this->logActivity('admin', $me['id'], 'payment_gateway_updated',
            ['gateway_id' => $id, 'gateway_name' => $gateway['name']]);

        // Fetch and return updated gateway (without secrets)
        $updated = $this->getall('payment_gateways', 'id = ?', [$id]);
        unset($updated['secret_key']);
        unset($updated['webhook_secret']);

        echo utilities::apiMessage('Gateway updated successfully.', 200, $updated);
    }

    // ── POST /admin/payment-gateways/:id/toggle ────────────────────────────────
    /**
     * Enable/disable a payment gateway
     */
    public function toggle(string $id): void
    {
        $me = BaseController::$authAdmin;
        $gateway = $this->getall('payment_gateways', 'id = ?', [$id]);
        if (!is_array($gateway)) {
            echo utilities::apiMessage('Gateway not found.', 404);
            return;
        }

        $newStatus = $gateway['is_enabled'] ? 0 : 1;
        $this->update('payment_gateways', ['is_enabled' => $newStatus], "id = ?", [$id]);

        $this->logActivity('admin', $me['id'], 'payment_gateway_toggled',
            ['gateway_id' => $id, 'gateway_name' => $gateway['name'], 'new_status' => $newStatus]);

        echo utilities::apiMessage(
            ($newStatus ? 'Gateway enabled' : 'Gateway disabled') . ' successfully.',
            200,
            ['is_enabled' => $newStatus]
        );
    }

    // ── GET /customer/payment-gateways ─────────────────────────────────────────
    /**
     * Get enabled payment gateways for customer app
     * Used to display available payment methods
     */
    public function enabledGateways(): void
    {
        $stmt = $this->db->prepare("
            SELECT id, name, display_name, min_amount, max_amount,
                   transaction_fee_percent, transaction_fee_fixed
            FROM payment_gateways
            WHERE is_enabled = 1
            ORDER BY priority ASC
        ");
        $stmt->execute();
        $gateways = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Enabled gateways retrieved.', 200, $gateways);
    }

    // ── GET /admin/payment-gateways/stats ──────────────────────────────────────
    /**
     * Get payment gateway statistics
     */
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
