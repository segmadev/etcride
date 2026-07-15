<?php
/**
 * EtcRide Mailer
 * Wraps PHPMailer for transactional emails.
 *
 * SMTP config priority (highest → lowest):
 *   1. $config array passed directly to smtpmailer()
 *   2. Active row in smtp_configs table (via injected PDO — call setDb() first)
 *   3. .env MAIL_* variables (legacy fallback)
 *
 * OTP emails only: if email_provider=termii the sendOtpEmail() method
 * routes through Termii's email API instead of SMTP.
 * All other emails always use SMTP.
 *
 * Debug:
 *   mail_type=log in .env  → writes to logs/mail.log instead of sending
 *   Full structured log always written to logs/mail.log regardless of mode
 */
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as MailerException;

class Mymailer
{
    private string $lastError = '';

    public function getLastError(): string { return $this->lastError; }

    // ── PDO injection (call setDb before any send) ────────────────────────────
    private static ?PDO $pdo = null;

    public static function setDb(PDO $db): void
    {
        self::$pdo = $db;
    }

    /**
     * Branded email wrapper — the single source of truth for email design.
     * All transactional emails should use this so header/footer stay consistent.
     *
     * @param string $title       Header bar title (e.g. "Booking Confirmed")
     * @param string $accent      Header background hex color (e.g. "#2563eb")
     * @param string $innerHtml   The body content that goes between header and footer
     * @param string $appName     App name (shown in header and footer)
     * @param string $supportEmail  If set, shown as a contact link in the footer
     */
    public static function layout(
        string $title,
        string $accent,
        string $innerHtml,
        string $appName  = 'EtcRide',
        string $supportEmail = ''
    ): string {
        $year    = date('Y');
        $contact = $supportEmail
            ? "<a href='mailto:$supportEmail' style='color:#64748b;text-decoration:none;'>$supportEmail</a>"
            : '';
        return <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>$title</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#f1f5f9;padding:48px 16px;">
  <tr><td align="center">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;">
      <!-- Logo strip -->
      <tr>
        <td style="padding:0 0 20px;text-align:center;">
          <img src="https://etcride.com/images/logo-light.svg" alt="$appName" height="40" style="display:inline-block;max-height:40px;width:auto;">
        </td>
      </tr>
      <!-- Card -->
      <tr>
        <td style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.06),0 4px 16px rgba(0,0,0,0.06);">
          <!-- Accent bar -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="background:#0f172a;padding:28px 40px 24px;">
                <p style="margin:0 0 10px;color:rgba(255,255,255,0.5);font-size:11px;font-weight:600;letter-spacing:1.5px;text-transform:uppercase;">$appName</p>
                <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;line-height:1.25;letter-spacing:-0.5px;">$title</h1>
              </td>
            </tr>
            <!-- Body -->
            <tr>
              <td style="padding:36px 40px 32px;color:#374151;font-size:15px;line-height:1.7;">
                $innerHtml
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <!-- Footer -->
      <tr>
        <td style="padding:28px 0 0;text-align:center;">
          <p style="margin:0 0 4px;color:#94a3b8;font-size:12px;">$contact</p>
          <p style="margin:0;color:#cbd5e1;font-size:11px;">&copy; $year $appName. All rights reserved.</p>
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body>
</html>
HTML;
    }

    // ── Active SMTP config (lazy-loaded, reset on each setDb call) ────────────
    private static ?array $activeSmtp = null;

    private function loadActiveSmtp(): array
    {
        if (self::$activeSmtp !== null) {
            return self::$activeSmtp;
        }

        $pdo = self::$pdo;

        // Fallback: try global $db (legacy — keep for backwards compatibility)
        if ($pdo === null) {
            global $db;
            if (isset($db) && $db instanceof PDO) {
                $pdo = $db;
            }
        }

        if ($pdo !== null) {
            try {
                $stmt = $pdo->query(
                    "SELECT host, port, username, password, encryption, from_name, from_email
                     FROM smtp_configs WHERE is_active = 1 LIMIT 1"
                );
                $row = $stmt ? $stmt->fetch(PDO::FETCH_ASSOC) : false;
                if (is_array($row) && !empty($row['host'])) {
                    self::$activeSmtp = [
                        'smtp_host'       => $row['host'],
                        'smtp_port'       => (int) $row['port'],
                        'smtp_username'   => $row['username'],
                        'smtp_password'   => $row['password'],
                        'smtp_encryption' => $row['encryption'],
                        'smtp_from_name'  => $row['from_name']  ?: '',
                        'smtp_from_email' => (!empty($row['from_email']) && $row['from_email'] !== 'null')
                                                ? $row['from_email']
                                                : $row['username'],
                    ];
                    self::log([
                        'event'       => 'SMTP_CONFIG_LOADED',
                        'source'      => 'smtp_configs table',
                        'host'        => self::$activeSmtp['smtp_host'],
                        'port'        => self::$activeSmtp['smtp_port'],
                        'username'    => self::$activeSmtp['smtp_username'],
                        'from_email'  => self::$activeSmtp['smtp_from_email'],
                        'encryption'  => self::$activeSmtp['smtp_encryption'],
                    ]);
                    return self::$activeSmtp;
                }
                self::log(['event' => 'SMTP_CONFIG_MISSING', 'note' => 'No active row in smtp_configs — falling back to .env']);
            } catch (\Throwable $e) {
                self::log(['event' => 'SMTP_CONFIG_DB_ERROR', 'error' => $e->getMessage()]);
            }
        } else {
            self::log(['event' => 'SMTP_CONFIG_NO_PDO', 'note' => 'Mymailer::setDb() was never called and global $db is not set — call setDb($this->db) from controller constructor']);
        }

        // Fallback: .env
        self::$activeSmtp = [];
        return self::$activeSmtp;
    }

    // ── OTP email — routes via Termii or SMTP ────────────────────────────────
    public function sendOtpEmail(string $to, string $otp, string $appName = 'ETCRide'): bool
    {
        $provider = $this->dbSetting('email_provider', 'smtp');
        self::log(['event' => 'OTP_EMAIL_ATTEMPT', 'to' => $to, 'provider' => $provider, 'app' => $appName]);

        if ($provider === 'termii') {
            return $this->sendTermiiOtpEmail($to, $otp);
        }

        return $this->smtpmailer(
            $to,
            "Your $appName verification code",
            "Your one-time code is: <b>$otp</b><br><br>This code expires in 10 minutes.<br><br>— $appName Team"
        );
    }

    private function sendTermiiOtpEmail(string $to, string $otp): bool
    {
        $apiKey   = $this->dbSetting('sms_api_key', '');
        $configId = $this->dbSetting('termii_email_config_id', '');

        if ($apiKey === '' || $configId === '') {
            self::log(['event' => 'TERMII_EMAIL_CONFIG_MISSING', 'api_key_set' => $apiKey !== '', 'config_id_set' => $configId !== '']);
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
            self::log(['event' => 'TERMII_EMAIL_CURL_ERROR', 'to' => $to, 'curl_errno' => $err, 'result' => 'FAILED']);
            return false;
        }

        $data    = json_decode($resp, true);
        $success = isset($data['message_id']);
        self::log(['event' => 'TERMII_EMAIL_RESPONSE', 'to' => $to, 'success' => $success, 'response' => $resp]);
        return $success;
    }

    // ── Legacy aliases ────────────────────────────────────────────────────────
    public function send_email(string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name);
    }

    public function send_email_with_config(array $config, string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name, $config);
    }

    /**
     * Core SMTP send. Config priority: $config param > smtp_configs table > .env
     */
    public function smtpmailer(string $to, string $subject, string $body, string $name = '', array $config = []): bool
    {
        $this->lastError = '';

        // ── Dev log mode ──────────────────────────────────────────────────────
        if (($_ENV['mail_type'] ?? '') === 'log') {
            $entry = "To: $to | Subject: $subject\n" . strip_tags($body);
            self::log(['event' => 'MAIL_DEV_LOG', 'to' => $to, 'subject' => $subject, 'body_preview' => substr(strip_tags($body), 0, 120)]);
            return true;
        }

        if (!class_exists(PHPMailer::class)) {
            self::log(['event' => 'MAIL_NO_PHPMAILER', 'to' => $to, 'subject' => $subject]);
            error_log('EtcRide Mailer: PHPMailer not available.');
            return false;
        }

        // Merge: explicit $config > active smtp_configs row > .env
        $active = empty($config) ? $this->loadActiveSmtp() : [];

        $nullish = fn($v) => ($v === null || $v === '' || $v === 'null');

        $host       = $config['smtp_host']       ?? $active['smtp_host']       ?? $_ENV['MAIL_HOST']       ?? '';
        $port       = (int) ($config['smtp_port'] ?? $active['smtp_port']       ?? $_ENV['MAIL_PORT']       ?? 587);
        $username   = $config['smtp_username']   ?? $active['smtp_username']   ?? $_ENV['MAIL_USERNAME']   ?? '';
        $password   = $config['smtp_password']   ?? $active['smtp_password']   ?? $_ENV['MAIL_PASSWORD']   ?? '';
        $encryption = strtolower($config['smtp_encryption'] ?? $active['smtp_encryption'] ?? $_ENV['MAIL_ENCRYPTION'] ?? 'tls');
        $fromEmail  = $config['smtp_from_email'] ?? $active['smtp_from_email'] ?? $_ENV['MAIL_FROM_EMAIL'] ?? '';
        $fromName   = $config['smtp_from_name']  ?? $active['smtp_from_name']  ?? $_ENV['MAIL_FROM_NAME']  ?? ($_ENV['app_name'] ?? 'EtcRide');

        if ($nullish($fromEmail)) $fromEmail = $username;
        if ($nullish($fromName))  $fromName  = $_ENV['app_name'] ?? 'EtcRide';

        self::log([
            'event'      => 'SMTP_SEND_ATTEMPT',
            'to'         => $to,
            'subject'    => $subject,
            'host'       => $host ?: '(empty)',
            'port'       => $port,
            'username'   => $username ?: '(empty)',
            'from_email' => $fromEmail,
            'encryption' => $encryption,
            'config_src' => !empty($config) ? 'direct-param' : (!empty($active) ? 'smtp_configs-table' : '.env-or-empty'),
        ]);

        if (empty($host) || empty($username)) {
            $this->lastError = 'SMTP not configured — add an active SMTP profile in Admin → Settings → SMTP, or set MAIL_HOST/MAIL_USERNAME in .env';
            self::log(['event' => 'SMTP_NOT_CONFIGURED', 'to' => $to, 'error' => $this->lastError]);
            error_log('EtcRide Mailer: ' . $this->lastError);
            return false;
        }

        try {
            $mail = new PHPMailer(true);
            $mail->CharSet    = PHPMailer::CHARSET_UTF8;
            $mail->Encoding   = PHPMailer::ENCODING_BASE64;
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
            self::log(['event' => 'SMTP_SEND_SUCCESS', 'to' => $to, 'subject' => $subject]);
            return true;
        } catch (MailerException $e) {
            $this->lastError = $e->getMessage();
            self::log(['event' => 'SMTP_SEND_FAILED', 'to' => $to, 'subject' => $subject, 'error' => $this->lastError]);
            error_log('EtcRide Mailer: ' . $this->lastError);
            return false;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function dbSetting(string $key, string $default = ''): string
    {
        $pdo = self::$pdo;
        if ($pdo === null) { global $db; if (isset($db) && $db instanceof PDO) $pdo = $db; }
        if ($pdo === null) return $default;
        try {
            $stmt = $pdo->prepare("SELECT config_value FROM settings WHERE config_key = ? LIMIT 1");
            $stmt->execute([$key]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            return $row ? (string) $row['config_value'] : $default;
        } catch (\Throwable $e) {
            return $default;
        }
    }

    private static function log(array $data): void
    {
        $logFile = defined('ROOT') ? ROOT . 'logs/mail.log' : __DIR__ . '/../logs/mail.log';
        $dir = dirname($logFile);
        if (!is_dir($dir)) mkdir($dir, 0755, true);
        $line = '[' . date('Y-m-d H:i:s') . '] ' . json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL;
        file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
    }
}
