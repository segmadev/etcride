<?php
require_once ROOT . 'functions/BaseController.php';

class Payments extends BaseController
{
    // ── GET /admin/payments ───────────────────────────────────────────────────
    public function index(): void
    {
        $page    = max(1, (int) ($this->query('page', 1)));
        $perPage = 25;
        $offset  = ($page - 1) * $perPage;
        $status  = $this->query('status', '');
        $search  = $this->query('search', '');

        $where  = '1=1';
        $params = [];

        if ($status !== '') {
            $where   .= ' AND p.status = ?';
            $params[] = $status;
        }
        if ($search !== '') {
            $where   .= ' AND (p.reference LIKE ? OR p.provider_ref LIKE ? OR u.name LIKE ?)';
            $like     = '%' . $search . '%';
            $params   = array_merge($params, [$like, $like, $like]);
        }

        $total = $this->db->prepare(
            "SELECT COUNT(*) FROM payments p
             LEFT JOIN bookings b ON b.id = p.booking_id
             LEFT JOIN users u ON u.id = b.customer_id
             WHERE $where"
        );
        $total->execute($params);
        $totalCount = (int) $total->fetchColumn();

        $stmt = $this->db->prepare(
            "SELECT p.id, p.booking_id, p.provider, p.amount, p.currency,
                    p.status, p.reference, p.provider_ref, p.created_at,
                    u.name AS customer_name, u.phone AS customer_phone,
                    b.booking_code, b.status AS booking_status,
                    b.final_fare, b.estimated_fare
             FROM payments p
             LEFT JOIN bookings b ON b.id = p.booking_id
             LEFT JOIN users u ON u.id = b.customer_id
             WHERE $where
             ORDER BY p.created_at DESC
             LIMIT $perPage OFFSET $offset"
        );
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo utilities::apiMessage('Payments retrieved.', 200, [
            'data'       => $rows,
            'total'      => $totalCount,
            'page'       => $page,
            'per_page'   => $perPage,
            'last_page'  => max(1, (int) ceil($totalCount / $perPage)),
        ]);
    }

    // ── GET /admin/payments/:id ───────────────────────────────────────────────
    public function show(string $id): void
    {
        $stmt = $this->db->prepare(
            "SELECT p.*, u.name AS customer_name, u.phone AS customer_phone,
                    b.booking_code, b.status AS booking_status,
                    b.final_fare, b.estimated_fare, b.distance_km,
                    b.pickup_address, b.destination_address
             FROM payments p
             LEFT JOIN bookings b ON b.id = p.booking_id
             LEFT JOIN users u ON u.id = b.customer_id
             WHERE p.id = ?"
        );
        $stmt->execute([$id]);
        $payment = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$payment) {
            echo utilities::apiMessage('Payment not found.', 404);
            return;
        }

        echo utilities::apiMessage('Payment retrieved.', 200, $payment);
    }

    // ── POST /admin/payments/:id/refund ───────────────────────────────────────
    public function refund(string $id): void
    {
        $me      = BaseController::$authAdmin;
        $payment = $this->getall('payments', 'id = ?', [$id]);

        if (!is_array($payment)) {
            echo utilities::apiMessage('Payment not found.', 404);
            return;
        }

        if ($payment['status'] !== 'paid') {
            echo utilities::apiMessage('Only paid payments can be refunded.', 409);
            return;
        }

        // Mark as refunded — actual gateway refund handled manually for now
        $this->update('payments', ['status' => 'refunded'], "id = '$id'");
        $this->update('bookings', ['payment_status' => 'refunded'], "id = '{$payment['booking_id']}'");

        $this->logActivity('admin', $me['id'], 'payment_refunded', [
            'payment_id'  => $id,
            'booking_id'  => $payment['booking_id'],
            'amount'      => $payment['amount'],
        ]);

        echo utilities::apiMessage('Payment marked as refunded.', 200);
    }
}
