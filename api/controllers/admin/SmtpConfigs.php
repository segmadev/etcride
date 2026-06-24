<?php
require_once ROOT . 'functions/BaseController.php';

class SmtpConfigs extends BaseController
{
    private const MAX_CONFIGS = 3;

    // ── GET /admin/smtp-configs ───────────────────────────────────────────────
    public function index(): void
    {
        $stmt = $this->db->query(
            'SELECT id, name, host, port, username, encryption, from_name, from_email, is_active, created_at
             FROM smtp_configs ORDER BY id ASC'
        );
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Never expose stored passwords
        foreach ($rows as &$row) {
            $row['has_password'] = $row['password'] !== '' ? true : false;
            unset($row['password']);
        }

        echo utilities::apiMessage('SMTP configs retrieved.', 200, $rows);
    }

    // ── POST /admin/smtp-configs ──────────────────────────────────────────────
    public function create(): void
    {
        $count = (int) $this->db->query('SELECT COUNT(*) FROM smtp_configs')->fetchColumn();
        if ($count >= self::MAX_CONFIGS) {
            echo utilities::apiMessage('Maximum of ' . self::MAX_CONFIGS . ' SMTP profiles allowed.', 422);
            return;
        }

        $err = $this->requireFields(['name', 'host', 'username', 'from_name', 'from_email']);
        if ($err) { echo $err; return; }

        $row = $this->buildRow();
        if (!$row) return; // validation already echoed error

        $this->db->prepare(
            'INSERT INTO smtp_configs (name, host, port, username, password, encryption, from_name, from_email, is_active)
             VALUES (:name, :host, :port, :username, :password, :encryption, :from_name, :from_email, 0)'
        )->execute($row);

        $id = (int) $this->db->lastInsertId();
        echo utilities::apiMessage('SMTP profile created.', 201, ['id' => $id]);
    }

    // ── PUT /admin/smtp-configs/:id ───────────────────────────────────────────
    public function updateSmtpConfig(int $id): void
    {
        $existing = $this->getSmtp($id);
        if (!$existing) { echo utilities::apiMessage('SMTP profile not found.', 404); return; }

        $row = $this->buildRow(allowEmptyPassword: true);
        if ($row === null) return;

        // Keep existing password if none supplied
        if ($row['password'] === '') {
            unset($row['password']);
            $set = implode(', ', array_map(fn($k) => "$k = :$k", array_keys($row)));
            $stmt = $this->db->prepare("UPDATE smtp_configs SET $set WHERE id = :_id");
            $stmt->execute(array_merge($row, ['_id' => $id]));
        } else {
            $set = implode(', ', array_map(fn($k) => "$k = :$k", array_keys($row)));
            $stmt = $this->db->prepare("UPDATE smtp_configs SET $set WHERE id = :_id");
            $stmt->execute(array_merge($row, ['_id' => $id]));
        }

        echo utilities::apiMessage('SMTP profile updated.', 200);
    }

    // ── PUT /admin/smtp-configs/:id/activate ─────────────────────────────────
    public function activate(int $id): void
    {
        $existing = $this->getSmtp($id);
        if (!$existing) { echo utilities::apiMessage('SMTP profile not found.', 404); return; }

        $this->db->exec('UPDATE smtp_configs SET is_active = 0');
        $this->db->prepare('UPDATE smtp_configs SET is_active = 1 WHERE id = ?')->execute([$id]);

        echo utilities::apiMessage('SMTP profile activated.', 200);
    }

    // ── DELETE /admin/smtp-configs/:id ────────────────────────────────────────
    public function remove(int $id): void
    {
        $existing = $this->getSmtp($id);
        if (!$existing) { echo utilities::apiMessage('SMTP profile not found.', 404); return; }

        $count = (int) $this->db->query('SELECT COUNT(*) FROM smtp_configs')->fetchColumn();
        if ($count <= 1) {
            echo utilities::apiMessage('Cannot delete the last SMTP profile.', 422);
            return;
        }

        $this->db->prepare('DELETE FROM smtp_configs WHERE id = ?')->execute([$id]);

        // If deleted row was active, promote the first remaining row
        if ((int) $existing['is_active'] === 1) {
            $this->db->exec('UPDATE smtp_configs SET is_active = 1 ORDER BY id ASC LIMIT 1');
        }

        echo utilities::apiMessage('SMTP profile deleted.', 200);
    }

    // ── POST /admin/smtp-configs/test ─────────────────────────────────────────
    public function test(): void
    {
        $err = $this->requireFields(['to']);
        if ($err) { echo $err; return; }

        $to = $this->str('to');
        $id = $this->int('smtp_config_id', 0);

        $config = [];
        if ($id > 0) {
            $row = $this->getSmtp($id);
            if ($row) {
                $config = [
                    'smtp_host'       => $row['host'],
                    'smtp_port'       => (int) $row['port'],
                    'smtp_username'   => $row['username'],
                    'smtp_password'   => $row['password'],
                    'smtp_encryption' => $row['encryption'],
                    'smtp_from_name'  => $row['from_name'],
                    'smtp_from_email' => $row['from_email'],
                ];
            }
        }

        require_once ROOT . 'functions/mailer.php';
        $mailer = new Mymailer();
        $appName = $this->setting('app_name', 'ETCRide');
        $sent = $mailer->smtpmailer(
            $to,
            "Test email from $appName",
            "This is a test email from your $appName SMTP configuration.",
            '',
            $config
        );

        if ($sent) {
            echo utilities::apiMessage('Test email sent successfully.', 200);
        } else {
            echo utilities::apiMessage('Failed to send test email. Check your SMTP settings and server logs.', 500);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function getSmtp(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT * FROM smtp_configs WHERE id = ? LIMIT 1');
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return is_array($row) ? $row : null;
    }

    /** Build a field array from POST data. Returns null and echoes error on failure. */
    private function buildRow(bool $allowEmptyPassword = false): ?array
    {
        $encryption = $this->str('encryption', 'tls');
        if (!in_array($encryption, ['tls', 'ssl', 'none'], true)) $encryption = 'tls';

        $port = $this->int('port', 587);
        if ($port < 1 || $port > 65535) {
            echo utilities::apiMessage('Port must be between 1 and 65535.', 422);
            return null;
        }

        $fromEmail = $this->str('from_email');
        if ($fromEmail !== '' && !filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) {
            echo utilities::apiMessage('Enter a valid From Email address.', 422);
            return null;
        }

        $password = $this->str('password', '');

        if (!$allowEmptyPassword && $password === '') {
            echo utilities::apiMessage('Password is required.', 422);
            return null;
        }

        return [
            'name'       => $this->str('name', 'Default'),
            'host'       => $this->str('host'),
            'port'       => $port,
            'username'   => $this->str('username'),
            'password'   => $password,
            'encryption' => $encryption,
            'from_name'  => $this->str('from_name'),
            'from_email' => $fromEmail,
        ];
    }
}
