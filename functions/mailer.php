<?php
/**
 * EtcRide Mailer
 * Wraps PHPMailer for transactional emails.
 * When mail_type=log (local dev), writes to maillog.log instead of sending.
 */
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as MailerException;

class Mymailer
{
    /**
     * Send an email using .env SMTP config (legacy path, still works).
     */
    public function send_email(string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name);
    }

    /**
     * Send an email using a config array (DB-sourced SMTP settings).
     * Falls back to .env for any missing values.
     *
     * @param array  $config  Keys: smtp_host, smtp_port, smtp_username, smtp_password,
     *                              smtp_encryption, smtp_from_name, smtp_from_email
     */
    public function send_email_with_config(array $config, string $to, string $subject, string $body, string $name = ''): bool
    {
        return $this->smtpmailer($to, $subject, $body, $name, $config);
    }

    /**
     * Core send method.
     * In dev (mail_type=log) writes to maillog.log.
     * $config values override .env values when provided.
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

        // ── SMTP send ──────────────────────────────────────────────────────────
        if (!class_exists(PHPMailer::class)) {
            error_log('EtcRide Mailer: PHPMailer not available.');
            return false;
        }

        // Config values from $config array take priority over .env
        $host       = $config['smtp_host']       ?? $_ENV['MAIL_HOST']       ?? '';
        $port       = (int) ($config['smtp_port'] ?? $_ENV['MAIL_PORT']       ?? 587);
        $username   = $config['smtp_username']   ?? $_ENV['MAIL_USERNAME']   ?? '';
        $password   = $config['smtp_password']   ?? $_ENV['MAIL_PASSWORD']   ?? '';
        $fromEmail  = $config['smtp_from_email'] ?? $_ENV['MAIL_FROM_EMAIL'] ?? $username;
        $fromName   = $config['smtp_from_name']  ?? $_ENV['MAIL_FROM_NAME']  ?? ($_ENV['app_name'] ?? 'EtcRide');
        $encryption = strtolower($config['smtp_encryption'] ?? $_ENV['MAIL_ENCRYPTION'] ?? 'tls');

        if (empty($host) || empty($username)) {
            error_log('EtcRide Mailer: SMTP not configured — set smtp_host and smtp_username in Settings or MAIL_HOST/MAIL_USERNAME in .env');
            return false;
        }

        try {
            $mail = new PHPMailer(true);
            $mail->isSMTP();
            $mail->Host        = $host;
            $mail->Port        = $port;
            $mail->SMTPAuth    = true;
            $mail->Username    = $username;
            $mail->Password    = $password;
            $mail->SMTPSecure  = $encryption === 'ssl' ? PHPMailer::ENCRYPTION_SMTPS : PHPMailer::ENCRYPTION_STARTTLS;

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
