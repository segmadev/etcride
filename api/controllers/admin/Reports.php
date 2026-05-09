<?php
require_once ROOT . 'functions/BaseController.php';

class Reports extends BaseController
{
    // ── GET /admin/reports/bookings ───────────────────────────────────────────
    // ?from=YYYY-MM-DD&to=YYYY-MM-DD&status=&type=
    public function bookings(): void
    {
        [$from, $to, $conditions, $params] = $this->dateRange();

        $status = $this->query('status', '');
        $type   = $this->query('type', '');
        if ($status !== '') { $conditions[] = 'status = ?';       $params[] = $status; }
        if ($type   !== '') { $conditions[] = 'booking_type = ?'; $params[] = $type; }

        $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        // Summary counts
        $summaryStmt = $this->db->prepare(
            "SELECT
                COUNT(*)                                   AS total,
                SUM(status = 'completed')                  AS completed,
                SUM(status = 'cancelled')                  AS cancelled,
                SUM(status = 'pending')                    AS pending,
                SUM(status = 'in_progress')                AS in_progress,
                SUM(booking_type = 'ride')                 AS rides,
                SUM(booking_type = 'delivery')             AS deliveries,
                SUM(payment_status = 'paid')               AS paid_count,
                COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN final_fare ELSE estimated_fare END), 0) AS total_revenue
             FROM bookings $where"
        );
        $summaryStmt->execute($params);
        $summary = $summaryStmt->fetch(PDO::FETCH_ASSOC);

        // Daily breakdown
        $dailyStmt = $this->db->prepare(
            "SELECT DATE(created_at) AS date,
                    COUNT(*)           AS total,
                    SUM(status = 'completed') AS completed,
                    SUM(status = 'cancelled') AS cancelled,
                    COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN final_fare ELSE 0 END), 0) AS revenue
             FROM bookings $where
             GROUP BY DATE(created_at)
             ORDER BY date DESC
             LIMIT 90"
        );
        $dailyStmt->execute($params);

        echo utilities::apiMessage('Booking report retrieved.', 200, [
            'period'  => ['from' => $from, 'to' => $to],
            'summary' => $summary,
            'daily'   => $dailyStmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }

    // ── GET /admin/reports/revenue ────────────────────────────────────────────
    public function revenue(): void
    {
        [$from, $to, $conditions, $params] = $this->dateRange('b.');
        $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        $stmt = $this->db->prepare(
            "SELECT
                COALESCE(SUM(CASE WHEN b.payment_status = 'paid' THEN b.final_fare ELSE 0 END), 0)  AS total_revenue,
                COALESCE(SUM(CASE WHEN b.payment_status = 'paid' THEN b.estimated_fare ELSE 0 END), 0) AS estimated_total,
                COUNT(CASE WHEN b.payment_status = 'paid' THEN 1 END)   AS paid_bookings,
                COUNT(CASE WHEN b.payment_status = 'failed' THEN 1 END) AS failed_payments,
                AVG(CASE WHEN b.payment_status = 'paid' THEN b.final_fare END) AS avg_fare
             FROM bookings b $where"
        );
        $stmt->execute($params);
        $summary = $stmt->fetch(PDO::FETCH_ASSOC);

        // Per provider breakdown — reuse same date conditions (already prefixed b.)
        $provStmt = $this->db->prepare(
            "SELECT p.provider, COUNT(*) AS transactions,
                    SUM(p.amount) AS total, AVG(p.amount) AS avg
             FROM payments p
             JOIN bookings b ON b.id = p.booking_id
             WHERE p.status = 'paid'
             " . ($conditions ? 'AND ' . implode(' AND ', $conditions) : '') . "
             GROUP BY p.provider"
        );
        $provStmt->execute($params);

        echo utilities::apiMessage('Revenue report retrieved.', 200, [
            'period'    => ['from' => $from, 'to' => $to],
            'summary'   => $summary,
            'providers' => $provStmt->fetchAll(PDO::FETCH_ASSOC),
            'currency'  => $this->setting('currency', 'NGN'),
        ]);
    }

    // ── GET /admin/reports/drivers ────────────────────────────────────────────
    public function drivers(): void
    {
        [$from, $to, $conditions, $params] = $this->dateRange('b.');

        $having  = $conditions ? 'HAVING ' . implode(' AND ', $conditions) : '';
        // For driver stats, conditions reference booking columns via b.
        $where   = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

        $stmt = $this->db->prepare(
            "SELECT d.id, d.name, d.phone, d.is_active, d.is_online,
                    COUNT(b.id)                        AS total_jobs,
                    SUM(b.status = 'completed')        AS completed,
                    SUM(b.status = 'cancelled')        AS cancelled,
                    SUM(b.status = 'rejected')         AS rejected,
                    COALESCE(SUM(CASE WHEN b.payment_status = 'paid'
                                  THEN b.final_fare ELSE 0 END), 0) AS total_earned
             FROM drivers d
             LEFT JOIN bookings b ON b.driver_id = d.id
             " . ($conditions ? 'AND ' . implode(' AND ', $conditions) : '') . "
             GROUP BY d.id
             ORDER BY completed DESC
             LIMIT 100"
        );
        $stmt->execute($params);

        echo utilities::apiMessage('Driver report retrieved.', 200, [
            'period' => ['from' => $from, 'to' => $to],
            'data'   => $stmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }

    // ── Private: build date range conditions ──────────────────────────────────
    private function dateRange(string $prefix = ''): array
    {
        $from = $this->query('from', date('Y-m-01'));   // default: first of month
        $to   = $this->query('to',   date('Y-m-d'));    // default: today

        $conditions = [];
        $params     = [];

        if ($from !== '') {
            $conditions[] = "DATE({$prefix}created_at) >= ?";
            $params[]     = $from;
        }
        if ($to !== '') {
            $conditions[] = "DATE({$prefix}created_at) <= ?";
            $params[]     = $to;
        }

        return [$from, $to, $conditions, $params];
    }
}
