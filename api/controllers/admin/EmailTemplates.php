<?php
require_once ROOT . 'functions/BaseController.php';
require_once ROOT . 'functions/mailer.php';

class EmailTemplates extends BaseController
{
    // ── Template metadata ──────────────────────────────────────────────────────
    private const TEMPLATES = [
        'booking_confirmed' => [
            'label'       => 'Booking Confirmed',
            'description' => 'Sent to the customer when their booking is confirmed.',
            'variables'   => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{pickup_address}}', '{{destination_address}}', '{{estimated_fare}}', '{{support_email}}'],
            'default_subject' => 'Your {{app_name}} booking {{booking_code}} is confirmed',
            'default_body'    => self::DEFAULT_BOOKING_CONFIRMED,
        ],
        'driver_assigned' => [
            'label'       => 'Driver Assigned',
            'description' => 'Sent to the customer when a driver has been assigned to their booking.',
            'variables'   => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{driver_name}}', '{{driver_phone}}', '{{vehicle_type}}', '{{support_email}}'],
            'default_subject' => 'Driver assigned for your {{app_name}} booking {{booking_code}}',
            'default_body'    => self::DEFAULT_DRIVER_ASSIGNED,
        ],
        'booking_cancelled' => [
            'label'       => 'Booking Cancelled',
            'description' => 'Sent to the customer when a booking is cancelled.',
            'variables'   => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{cancellation_reason}}', '{{support_email}}'],
            'default_subject' => 'Your {{app_name}} booking {{booking_code}} has been cancelled',
            'default_body'    => self::DEFAULT_BOOKING_CANCELLED,
        ],
        'welcome' => [
            'label'       => 'Welcome / Registration',
            'description' => 'Sent to a new customer when they register.',
            'variables'   => ['{{app_name}}', '{{customer_name}}', '{{support_email}}'],
            'default_subject' => 'Welcome to {{app_name}}!',
            'default_body'    => self::DEFAULT_WELCOME,
        ],
    ];

    // ── GET /admin/email-templates ─────────────────────────────────────────────
    public function index(): void
    {
        $result = [];
        foreach (self::TEMPLATES as $key => $meta) {
            $subject = $this->setting("tpl_{$key}_subject", $meta['default_subject']);
            $body    = $this->setting("tpl_{$key}_body",    $meta['default_body']);
            $result[] = [
                'key'         => $key,
                'label'       => $meta['label'],
                'description' => $meta['description'],
                'variables'   => $meta['variables'],
                'subject'     => $subject,
                'body'        => $body,
            ];
        }
        echo utilities::apiMessage('Email templates retrieved.', 200, $result);
    }

    // ── POST /admin/email-templates/test ──────────────────────────────────────
    // Body: { to: "test@example.com", template_key: "booking_confirmed" }
    public function test(): void
    {
        $body = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $to          = trim($body['to'] ?? '');
        $templateKey = trim($body['template_key'] ?? 'booking_confirmed');

        if (empty($to) || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
            echo utilities::apiMessage('A valid recipient email is required.', 422);
            return;
        }

        if (!isset(self::TEMPLATES[$templateKey])) {
            echo utilities::apiMessage('Unknown template key.', 422);
            return;
        }

        $meta    = self::TEMPLATES[$templateKey];
        $subject = $this->setting("tpl_{$templateKey}_subject", $meta['default_subject']);
        $bodyTpl = $this->setting("tpl_{$templateKey}_body",    $meta['default_body']);

        // Replace variables with sample values for preview
        $sampleVars = [
            '{{app_name}}'              => $this->setting('app_name', 'EtcRide'),
            '{{customer_name}}'         => 'John Doe',
            '{{booking_code}}'          => 'BK-DEMO123',
            '{{pickup_address}}'        => '12 Sample Street, Ilorin',
            '{{destination_address}}'   => '45 Demo Avenue, Ilorin',
            '{{estimated_fare}}'        => '₦1,500',
            '{{driver_name}}'           => 'Ahmed Musa',
            '{{driver_phone}}'          => '+234 801 234 5678',
            '{{vehicle_type}}'          => 'Economy',
            '{{cancellation_reason}}'   => 'Test cancellation',
            '{{support_email}}'         => $this->setting('support_email', 'support@etcride.com'),
        ];

        $renderedSubject = str_replace(array_keys($sampleVars), array_values($sampleVars), $subject);
        $renderedBody    = str_replace(array_keys($sampleVars), array_values($sampleVars), $bodyTpl);

        // Read DB SMTP config
        $smtpConfig = [
            'smtp_host'       => $this->setting('smtp_host',       ''),
            'smtp_port'       => $this->setting('smtp_port',       '587'),
            'smtp_username'   => $this->setting('smtp_username',   ''),
            'smtp_password'   => $this->setting('smtp_password',   ''),
            'smtp_encryption' => $this->setting('smtp_encryption', 'tls'),
            'smtp_from_name'  => $this->setting('smtp_from_name',  $this->setting('app_name', 'EtcRide')),
            'smtp_from_email' => $this->setting('smtp_from_email', ''),
        ];

        $mailer = new Mymailer();
        $sent   = $mailer->send_email_with_config($smtpConfig, $to, "[TEST] $renderedSubject", $renderedBody, 'Test Recipient');

        if ($sent) {
            echo utilities::apiMessage("Test email sent to $to.", 200);
        } else {
            echo utilities::apiMessage('Failed to send email. Check SMTP settings and server logs.', 500);
        }
    }

    // ── Default template bodies ────────────────────────────────────────────────

    private const DEFAULT_BOOKING_CONFIRMED = <<<HTML
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f8fafc;margin:0;padding:20px;">
<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08);">
  <div style="background:#2563eb;padding:24px 28px;">
    <h1 style="color:#fff;margin:0;font-size:20px;">Booking Confirmed</h1>
  </div>
  <div style="padding:28px;">
    <p style="color:#334155;margin-top:0;">Hi <strong>{{customer_name}}</strong>,</p>
    <p style="color:#334155;">Your ride with <strong>{{app_name}}</strong> has been confirmed.</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0;">
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Booking Code</td><td style="padding:8px 0;font-weight:600;color:#0f172a;">{{booking_code}}</td></tr>
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Pickup</td><td style="padding:8px 0;color:#0f172a;">{{pickup_address}}</td></tr>
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Destination</td><td style="padding:8px 0;color:#0f172a;">{{destination_address}}</td></tr>
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Estimated Fare</td><td style="padding:8px 0;font-weight:600;color:#16a34a;">{{estimated_fare}}</td></tr>
    </table>
    <p style="color:#64748b;font-size:13px;">We will notify you once a driver is assigned. Need help? Contact us at <a href="mailto:{{support_email}}" style="color:#2563eb;">{{support_email}}</a>.</p>
  </div>
  <div style="background:#f1f5f9;padding:16px 28px;text-align:center;">
    <p style="color:#94a3b8;font-size:12px;margin:0;">© {{app_name}}. All rights reserved.</p>
  </div>
</div>
</body>
</html>
HTML;

    private const DEFAULT_DRIVER_ASSIGNED = <<<HTML
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f8fafc;margin:0;padding:20px;">
<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08);">
  <div style="background:#16a34a;padding:24px 28px;">
    <h1 style="color:#fff;margin:0;font-size:20px;">Driver Assigned</h1>
  </div>
  <div style="padding:28px;">
    <p style="color:#334155;margin-top:0;">Hi <strong>{{customer_name}}</strong>,</p>
    <p style="color:#334155;">Great news! A driver has been assigned to your booking <strong>{{booking_code}}</strong>.</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0;">
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Driver</td><td style="padding:8px 0;font-weight:600;color:#0f172a;">{{driver_name}}</td></tr>
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Phone</td><td style="padding:8px 0;color:#0f172a;">{{driver_phone}}</td></tr>
      <tr><td style="padding:8px 0;color:#64748b;font-size:14px;">Vehicle Type</td><td style="padding:8px 0;color:#0f172a;">{{vehicle_type}}</td></tr>
    </table>
    <p style="color:#64748b;font-size:13px;">Questions? Email us at <a href="mailto:{{support_email}}" style="color:#2563eb;">{{support_email}}</a>.</p>
  </div>
  <div style="background:#f1f5f9;padding:16px 28px;text-align:center;">
    <p style="color:#94a3b8;font-size:12px;margin:0;">© {{app_name}}. All rights reserved.</p>
  </div>
</div>
</body>
</html>
HTML;

    private const DEFAULT_BOOKING_CANCELLED = <<<HTML
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f8fafc;margin:0;padding:20px;">
<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08);">
  <div style="background:#dc2626;padding:24px 28px;">
    <h1 style="color:#fff;margin:0;font-size:20px;">Booking Cancelled</h1>
  </div>
  <div style="padding:28px;">
    <p style="color:#334155;margin-top:0;">Hi <strong>{{customer_name}}</strong>,</p>
    <p style="color:#334155;">Your booking <strong>{{booking_code}}</strong> has been cancelled.</p>
    <p style="color:#334155;"><strong>Reason:</strong> {{cancellation_reason}}</p>
    <p style="color:#64748b;font-size:13px;">If you have any questions, please contact us at <a href="mailto:{{support_email}}" style="color:#2563eb;">{{support_email}}</a>. We apologise for any inconvenience.</p>
  </div>
  <div style="background:#f1f5f9;padding:16px 28px;text-align:center;">
    <p style="color:#94a3b8;font-size:12px;margin:0;">© {{app_name}}. All rights reserved.</p>
  </div>
</div>
</body>
</html>
HTML;

    private const DEFAULT_WELCOME = <<<HTML
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f8fafc;margin:0;padding:20px;">
<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08);">
  <div style="background:#2563eb;padding:24px 28px;">
    <h1 style="color:#fff;margin:0;font-size:20px;">Welcome to {{app_name}}!</h1>
  </div>
  <div style="padding:28px;">
    <p style="color:#334155;margin-top:0;">Hi <strong>{{customer_name}}</strong>,</p>
    <p style="color:#334155;">Welcome aboard! Your account has been created successfully. You can now book rides quickly and easily with <strong>{{app_name}}</strong>.</p>
    <p style="color:#64748b;font-size:13px;">Need help getting started? Reach out at <a href="mailto:{{support_email}}" style="color:#2563eb;">{{support_email}}</a>.</p>
  </div>
  <div style="background:#f1f5f9;padding:16px 28px;text-align:center;">
    <p style="color:#94a3b8;font-size:12px;margin:0;">© {{app_name}}. All rights reserved.</p>
  </div>
</div>
</body>
</html>
HTML;
}
