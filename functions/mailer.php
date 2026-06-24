<?php
/**
 * EtcRide Mailer
 * Wraps PHPMailer for transactional emails.
 *
 * SMTP config priority (highest → lowest):
 *   1. $config array passed directly to smtpmailer()
 *   2. Active row in smtp_configs table
 *   3. .env MAIL_* variables (legacy fallback)
 *
 * OTP emails only: if email_provider=termii the sendOtpEmail() method
 * routes through Termii's email API instead of SMTP.
 * All other emails (booking confirmations, etc.) always use SMTP.
 *
 * Dev mode: set mail_type=log in .env to write to maillog.log instead.
 */
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as MailerException;

class Mymailer
{
    // ── Active SMTP config (lazy-loaded from smtp_configs table) ──────────────
    private static ?array $activeSmtp = null;

    private function loadActiveSmtp(): array
    {
        if (self::$activeSmtp !== null) {
            return self::$activeSmtp;
        }

        global $db;
        if (isset($db)) {
            try {
                $stmt = $db->query(
                    "SELECT host, port, username, password, encryption, from_name, from_email
                     FROM smtp_configs WHERE is_active = 1 LIMIT 1"
                );
                $row = $stmt ? $stmt->fetch(PDO::FETCH_ASSOC) : false;
                if (is_array($row) && $row['host'] !== '') {
                    self::$activeSmtp = [
                        'smtp_host'       => $row['host'],
                        'smtp_port'       => (int) $row['port'],
                        'smtp_username'   => $row['username'],
                        'smtp_password'   => $row['password'],
                        'smtp_encryption' => $row['encryption'],
                        'smtp_from_name'  => $row['from_name'],
                        'smtp_from_email' => $row['from_email'],
                    ];
                    return self::$activeSmtp;
                }
            } catch (\Throwable $e) {
                error_log('EtcRide Mailer: could not load smtp_configs — ' . $e->getMessage());
            }
        }

        // Fallback: build from .env
        self::$activeSmtp = [];
        return self::$activeSmtp;
    }

    // ── OTP email — routes via Termii or SMTP depending on email_provider ─────
    /**
     * Send an OTP verification email.
     * If email_provider=termii the code is sent via Termii's email OTP API.
     * Otherwise falls through to smtpmailer().
     */
    public function sendOtpEmail(string $to, string $otp, string $appName = 'ETCRide'): bool
    {
        $provider = $this->dbSetting('email_provider', 'smtp');

        if ($provider === 'termii') {
            return $this->sendTermiiOtpEmail($to, $otp);
        }

        // SMTP path
        return $this->smtpmailer(
            $to,
            "Your $appName verification code",
            "Your one-time code is: $otp\n\nThis code expires in 10 minutes.\n\n— $appName Team"
        );
    }

    private function sendTermiiOtpEmail(string $to, string $otp): bool
    {
        $apiKey   = $this->dbSetting('sms_api_key', '');
        $configId = $this->dbSetting('termii_email_config_id', '');

        if ($apiKey === '' || $configId === '') {
            error_log('EtcRide Mailer: Termii email not configured (missing sms_api_key or termii_email_config_id).');
            return false;
        }

        $payload = json_encode([
            'api_key'                => $apiKey,
            'email_address'          => $to,
            'code'                   => $otp,
            'email_configuration_id' => $configId,
        ]);

        $ch = curl_init('https://api.ng.termii.com/api/email/otp/send');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_TIMEOUT        => 10,
        ]);
        $resp = curl_exec($ch);
        $err  = curl_errno($ch);
        curl_close($ch);

        if ($err) {
            error_log("[Termii Email] cURL error: $err");
            return false;
        }

        $data = json_decode($resp, true);
        // Termii returns message_id on success
        return isset($data['message_id']);
    }

    private function dbSetting(string $key, string $default = ''): string
    {
        global $db;
        if (!isset($db)) return $default;
        try {
            $stmt = $db->prepare("SELECT config_value FROM settings WHERE config_key = ? LIMIT 1");
            $stmt->execute([$key]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            return $row ? (string) $row['config_value'] : $default;
        } catch (\Throwable $e) {
            return $default;
        }
    }

    // ── Legacy alias (used by old code paths) ─────────────────────────────────
    public function send_email(string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name);
    }

    public function send_email_with_config(array $config, string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name, $config);
    }

    /**
     * Core SMTP send method.
     * Config priority: $config param > active smtp_configs row > .env
     */
    public function smtpmailer(string $to, string $subject, string $body, string $name = '', array $config = []): bool
    {
        // ── Dev log mode ───────────────────────────────────────────────────────
        if (($_ENV['mail_type'] ?? '') === 'log') {
            $logFile = ROOT . 'maillog.log';
            $entry   = '[' . date('Y-m-d H:i:s') . '] To: ' . $to . ' | Subject: ' . $subject
                     . PHP_EOL . strip_tags($body) . PHP_EOL . str_repeat('-', 60) . PHP_EOL;
            file_put_contents($logFile, $entry, FILE_APPEND);
            return true;
        }

        if (!class_exists(PHPMailer::class)) {
            error_log('EtcRide Mailer: PHPMailer not available.');
            return false;
        }

        // Merge: explicit $config > active smtp_configs row > .env
        $active = empty($config) ? $this->loadActiveSmtp() : [];

        $host       = $config['smtp_host']       ?? $active['smtp_host']       ?? $_ENV['MAIL_HOST']       ?? '';
        $port       = (int) ($config['smtp_port'] ?? $active['smtp_port']       ?? $_ENV['MAIL_PORT']       ?? 587);
        $username   = $config['smtp_username']   ?? $active['smtp_username']   ?? $_ENV['MAIL_USERNAME']   ?? '';
        $password   = $config['smtp_password']   ?? $active['smtp_password']   ?? $_ENV['MAIL_PASSWORD']   ?? '';
        $fromEmail  = $config['smtp_from_email'] ?? $active['smtp_from_email'] ?? $_ENV['MAIL_FROM_EMAIL'] ?? $username;
        $fromName   = $config['smtp_from_name']  ?? $active['smtp_from_name']  ?? $_ENV['MAIL_FROM_NAME']  ?? ($_ENV['app_name'] ?? 'EtcRide');
        $encryption = strtolower($config['smtp_encryption'] ?? $active['smtp_encryption'] ?? $_ENV['MAIL_ENCRYPTION'] ?? 'tls');

        if (empty($host) || empty($username)) {
            error_log('EtcRide Mailer: SMTP not configured — add an active SMTP profile in Admin → Settings → SMTP, or set MAIL_HOST/MAIL_USERNAME in .env');
            return false;
        }

        try {
            $mail = new PHPMailer(true);
            $mail->isSMTP();
            $mail->Host       = $host;
            $mail->Port       = $port;
            $mail->SMTPAuth   = true;
            $mail->Username   = $username;
            $mail->Password   = $password;
            $mail->SMTPSecure = $encryption === 'ssl' ? PHPMailer::ENCRYPTION_SMTPS : PHPMailer::ENCRYPTION_STARTTLS;

            $mail->setFrom($fromEmail, $fromName);
            $mail->addAddress($to, $name);
            $mail->addReplyTo($fromEmail, $fromName);

            $mail->isHTML(true);
            $mail->Subject = $subject;
            $mail->Body    = $body;
            $mail->AltBody = strip_tags($body);

            $mail->send();
            return true;
        } catch (MailerException $e) {
            error_log('EtcRide Mailer: ' . $e->getMessage());
            return false;
        }
    }
}
