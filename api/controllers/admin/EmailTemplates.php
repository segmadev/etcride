<?php
require_once ROOT . 'functions/BaseController.php';
require_once ROOT . 'functions/mailer.php';

class EmailTemplates extends BaseController
{
    // ── Template registry ──────────────────────────────────────────────────────
    // default_body stores INNER HTML only — the branded header/footer wrapper is
    // applied automatically by BaseController::sendTemplateEmail() at send time.
    // Admins who store a full <!DOCTYPE ...> body in settings get it sent as-is.
    private const TEMPLATES = [
        'booking_confirmed' => [
            'label'           => 'Booking Confirmed',
            'description'     => 'Sent to the customer when their booking is confirmed.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{pickup_address}}', '{{destination_address}}', '{{estimated_fare}}', '{{support_email}}'],
            'default_subject' => 'Your {{app_name}} booking {{booking_code}} is confirmed',
        ],
        'driver_assigned' => [
            'label'           => 'Driver Assigned',
            'description'     => 'Sent to the customer when a driver has been assigned to their booking.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{driver_name}}', '{{driver_phone}}', '{{vehicle_type}}', '{{support_email}}'],
            'default_subject' => 'Driver assigned for your {{app_name}} booking {{booking_code}}',
        ],
        'booking_cancelled' => [
            'label'           => 'Booking Cancelled',
            'description'     => 'Sent to the customer when a booking is cancelled.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{booking_code}}', '{{cancellation_reason}}', '{{support_email}}'],
            'default_subject' => 'Your {{app_name}} booking {{booking_code}} has been cancelled',
        ],
        'welcome' => [
            'label'           => 'Welcome / Registration',
            'description'     => 'Sent to a new customer when their email is verified.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{support_email}}'],
            'default_subject' => 'Welcome to {{app_name}}!',
        ],
        'driver_login' => [
            'label'           => 'Driver Login Notification',
            'description'     => 'Sent to a driver whenever a new login is detected on their account.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{driver_name}}', '{{login_time}}', '{{device}}', '{{ip}}', '{{support_email}}'],
            'default_subject' => 'New login detected on your {{app_name}} driver account',
        ],
        'email_verification' => [
            'label'           => 'Email Verification (OTP)',
            'description'     => 'Sent to a new customer with a 6-digit code to verify their email address.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{code}}', '{{support_email}}'],
            'default_subject' => 'Verify your {{app_name}} account',
        ],
        'password_reset' => [
            'label'           => 'Customer Password Reset',
            'description'     => 'Sent to a customer who requested a password reset code.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{customer_name}}', '{{code}}', '{{support_email}}'],
            'default_subject' => 'Password reset code - {{app_name}}',
        ],
        'driver_password_reset' => [
            'label'           => 'Driver Password Reset',
            'description'     => 'Sent to a driver who requested a password reset code.',
            'accent_color'    => '#0f172a',
            'variables'       => ['{{app_name}}', '{{driver_name}}', '{{code}}', '{{support_email}}'],
            'default_subject' => 'Password reset code - {{app_name}}',
        ],
    ];

    // ── Static helper for BaseController::sendTemplateEmail() ─────────────────
    public static function getDefaults(string $key): array
    {
        $meta = self::TEMPLATES[$key] ?? null;
        if ($meta === null) return ['subject' => '', 'body' => ''];
        return [
            'subject' => $meta['default_subject'],
            'body'    => self::staticDefaultBody($key),
        ];
    }

    // ── GET /admin/email-templates ─────────────────────────────────────────────
    public function index(): void
    {
        $result = [];
        foreach (self::TEMPLATES as $key => $meta) {
            $subject = $this->setting("tpl_{$key}_subject", $meta['default_subject']);
            $body    = $this->setting("tpl_{$key}_body",    $this->defaultBody($key));
            $result[] = [
                'key'          => $key,
                'label'        => $meta['label'],
                'description'  => $meta['description'],
                'accent_color' => $meta['accent_color'],
                'variables'    => $meta['variables'],
                'subject'      => $subject,
                'body'         => $body,
            ];
        }
        echo utilities::apiMessage('Email templates retrieved.', 200, $result);
    }

    // ── POST /admin/email-templates/test ──────────────────────────────────────
    // Body: { to: "test@example.com", template_key: "booking_confirmed" }
    public function test(): void
    {
        $payload     = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $to          = trim($payload['to'] ?? '');
        $templateKey = trim($payload['template_key'] ?? 'booking_confirmed');

        if (empty($to) || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
            echo utilities::apiMessage('A valid recipient email is required.', 422);
            return;
        }

        if (!isset(self::TEMPLATES[$templateKey])) {
            echo utilities::apiMessage('Unknown template key.', 422);
            return;
        }

        $meta    = self::TEMPLATES[$templateKey];
        $appName = $this->setting('app_name', 'EtcRide');
        $subject = $this->setting("tpl_{$templateKey}_subject", $meta['default_subject']);
        $bodyTpl = $this->setting("tpl_{$templateKey}_body",    $this->defaultBody($templateKey));

        $sampleVars = [
            '{{app_name}}'              => $appName,
            '{{customer_name}}'         => 'John Doe',
            '{{driver_name}}'           => 'Ahmed Musa',
            '{{booking_code}}'          => 'BK-DEMO123',
            '{{pickup_address}}'        => '12 Sample Street, Ilorin',
            '{{destination_address}}'   => '45 Demo Avenue, Ilorin',
            '{{estimated_fare}}'        => '&#8358;1,500',
            '{{driver_phone}}'          => '+234 801 234 5678',
            '{{vehicle_type}}'          => 'Economy',
            '{{cancellation_reason}}'   => 'No driver available at this time.',
            '{{login_time}}'            => date('D, d M Y \a\t g:i A'),
            '{{device}}'                => 'Chrome on Windows',
            '{{ip}}'                    => '127.0.0.1',
            '{{support_email}}'         => $this->setting('support_email', 'support@etcride.com'),
        ];

        $renderedSubject = str_replace(array_keys($sampleVars), array_values($sampleVars), $subject);
        $renderedBody    = str_replace(array_keys($sampleVars), array_values($sampleVars), $bodyTpl);

        // Wrap inner content with the branded layout if not already full HTML
        $isFullHtml = stripos(ltrim($renderedBody), '<!DOCTYPE') === 0 || stripos(ltrim($renderedBody), '<html') === 0;
        if (!$isFullHtml) {
            $renderedBody = Mymailer::layout(
                $meta['label'],
                $meta['accent_color'],
                $renderedBody,
                $appName,
                $sampleVars['{{support_email}}']
            );
        }

        Mymailer::setDb($this->db);
        $mailer = new Mymailer();
        $sent   = $mailer->send_email($to, "[TEST] $renderedSubject", $renderedBody, 'Test Recipient');

        if ($sent) {
            echo utilities::apiMessage("Test email sent to $to.", 200);
        } else {
            echo utilities::apiMessage('Failed to send. Check SMTP settings and logs/mail.log.', 500, [
                'error' => $mailer->getLastError(),
            ]);
        }
    }

    // ── Default inner-HTML bodies ──────────────────────────────────────────────
    // These are the CONTENT sections only — the branded header/footer wrapper is
    // added automatically. Admins can override these in settings with either inner
    // HTML (gets wrapped) or a full <!DOCTYPE html> document (sent as-is).

    private function defaultBody(string $key): string { return self::staticDefaultBody($key); }

    public static function staticDefaultBody(string $key): string
    {
        return match ($key) {
            'booking_confirmed'    => self::innerBookingConfirmed(),
            'driver_assigned'      => self::innerDriverAssigned(),
            'booking_cancelled'    => self::innerBookingCancelled(),
            'welcome'              => self::innerWelcome(),
            'driver_login'         => self::innerDriverLogin(),
            'email_verification'   => self::innerEmailVerification(),
            'password_reset'       => self::innerPasswordReset(),
            'driver_password_reset'=> self::innerDriverPasswordReset(),
            default                => '',
        };
    }

    private static function innerBookingConfirmed(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 24px;color:#334155;font-size:15px;line-height:1.6;">Your booking with <strong>{{app_name}}</strong> has been received and confirmed. Here are your trip details:</p>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 24px;background:#f8fafc;border-radius:10px;overflow:hidden;border:1px solid #e2e8f0;">
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #e2e8f0;width:38%;">Booking Code</td>
    <td style="padding:14px 18px;font-weight:700;color:#0f172a;font-size:14px;border-bottom:1px solid #e2e8f0;letter-spacing:0.5px;">{{booking_code}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #e2e8f0;">Pickup</td>
    <td style="padding:14px 18px;color:#0f172a;font-size:14px;border-bottom:1px solid #e2e8f0;">{{pickup_address}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #e2e8f0;">Destination</td>
    <td style="padding:14px 18px;color:#0f172a;font-size:14px;border-bottom:1px solid #e2e8f0;">{{destination_address}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;">Estimated Fare</td>
    <td style="padding:14px 18px;font-weight:700;color:#16a34a;font-size:15px;">{{estimated_fare}}</td>
  </tr>
</table>
<p style="margin:0;color:#64748b;font-size:13px;line-height:1.6;">We will notify you as soon as a driver is on the way. Thank you for choosing <strong>{{app_name}}</strong>!</p>
HTML; }

    private static function innerDriverAssigned(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 8px;color:#334155;font-size:15px;line-height:1.6;">Great news! A driver has been assigned to your booking <strong>{{booking_code}}</strong> and is on the way.</p>
<div style="margin:0 0 24px;padding:20px;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;">
  <p style="margin:0 0 4px;color:#15803d;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;">Your Driver</p>
  <p style="margin:0 0 12px;color:#0f172a;font-size:20px;font-weight:700;">{{driver_name}}</p>
  <table role="presentation" cellpadding="0" cellspacing="0">
    <tr>
      <td style="color:#64748b;font-size:13px;padding-right:8px;padding-bottom:6px;">Phone</td>
      <td style="color:#0f172a;font-size:13px;font-weight:600;padding-bottom:6px;">{{driver_phone}}</td>
    </tr>
    <tr>
      <td style="color:#64748b;font-size:13px;padding-right:8px;">Vehicle</td>
      <td style="color:#0f172a;font-size:13px;font-weight:600;">{{vehicle_type}}</td>
    </tr>
  </table>
</div>
<p style="margin:0;color:#64748b;font-size:13px;line-height:1.6;">Please be ready at your pickup location. Safe travels!</p>
HTML; }

    private static function innerBookingCancelled(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 20px;color:#334155;font-size:15px;line-height:1.6;">We are sorry to let you know that your booking has been cancelled.</p>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 24px;background:#fff5f5;border:1px solid #fecaca;border-radius:10px;overflow:hidden;">
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #fecaca;width:38%;">Booking Code</td>
    <td style="padding:14px 18px;font-weight:700;color:#0f172a;font-size:14px;border-bottom:1px solid #fecaca;">{{booking_code}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;">Reason</td>
    <td style="padding:14px 18px;color:#7f1d1d;font-size:14px;">{{cancellation_reason}}</td>
  </tr>
</table>
<p style="margin:0;color:#64748b;font-size:13px;line-height:1.6;">We apologise for any inconvenience. You are welcome to book again at any time.</p>
HTML; }

    private static function innerWelcome(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 20px;color:#334155;font-size:15px;line-height:1.6;">Welcome to <strong>{{app_name}}</strong>! Your account is now fully verified and ready to use.</p>
<div style="margin:0 0 24px;padding:20px 24px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;">
  <p style="margin:0 0 10px;color:#1e40af;font-size:14px;font-weight:700;">What you can do now:</p>
  <ul style="margin:0;padding:0 0 0 18px;color:#334155;font-size:14px;line-height:1.8;">
    <li>Book a ride from anywhere to anywhere</li>
    <li>Track your driver in real time</li>
    <li>Pay securely online or with cash</li>
    <li>View your trip history at any time</li>
  </ul>
</div>
<p style="margin:0;color:#64748b;font-size:13px;line-height:1.6;">If you have any questions or need help getting started, we are always here for you.</p>
HTML; }

    private static function innerEmailVerification(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 24px;color:#334155;font-size:15px;line-height:1.6;">Thanks for signing up! Please verify your email address using the code below. It expires in <strong>30 minutes</strong>.</p>
<div style="text-align:center;margin:0 0 28px;">
  <span style="display:inline-block;background:#f0f9ff;border:2px solid #bae6fd;border-radius:12px;padding:20px 40px;font-size:38px;font-weight:800;letter-spacing:10px;color:#0c4a6e;font-family:'Courier New',monospace;">{{code}}</span>
</div>
<p style="margin:0;color:#94a3b8;font-size:13px;line-height:1.5;">If you did not create a {{app_name}} account, you can safely ignore this email.</p>
HTML; }

    private static function innerPasswordReset(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{customer_name}}</strong>,</p>
<p style="margin:0 0 24px;color:#334155;font-size:15px;line-height:1.6;">You requested a password reset. Use the code below to set a new password. It expires in <strong>15 minutes</strong>.</p>
<div style="text-align:center;margin:0 0 28px;">
  <span style="display:inline-block;background:#fefce8;border:2px solid #fde68a;border-radius:12px;padding:20px 40px;font-size:38px;font-weight:800;letter-spacing:10px;color:#78350f;font-family:'Courier New',monospace;">{{code}}</span>
</div>
<p style="margin:0;color:#94a3b8;font-size:13px;line-height:1.5;">If you did not request a password reset, please ignore this email. Your account is safe.</p>
HTML; }

    private static function innerDriverPasswordReset(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{driver_name}}</strong>,</p>
<p style="margin:0 0 24px;color:#334155;font-size:15px;line-height:1.6;">You requested a password reset for your driver account. Use the code below. It expires in <strong>15 minutes</strong>.</p>
<div style="text-align:center;margin:0 0 28px;">
  <span style="display:inline-block;background:#fefce8;border:2px solid #fde68a;border-radius:12px;padding:20px 40px;font-size:38px;font-weight:800;letter-spacing:10px;color:#78350f;font-family:'Courier New',monospace;">{{code}}</span>
</div>
<p style="margin:0;color:#94a3b8;font-size:13px;line-height:1.5;">If you did not request this, please ignore this email.</p>
HTML; }

    private static function innerDriverLogin(): string { return <<<HTML
<p style="margin:0 0 16px;color:#334155;font-size:15px;line-height:1.6;">Hi <strong>{{driver_name}}</strong>,</p>
<p style="margin:0 0 20px;color:#334155;font-size:15px;line-height:1.6;">A new login was detected on your <strong>{{app_name}}</strong> driver account.</p>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 24px;background:#faf5ff;border:1px solid #e9d5ff;border-radius:10px;overflow:hidden;">
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #e9d5ff;width:38%;">Time</td>
    <td style="padding:14px 18px;color:#0f172a;font-size:14px;border-bottom:1px solid #e9d5ff;">{{login_time}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;border-bottom:1px solid #e9d5ff;">Device</td>
    <td style="padding:14px 18px;color:#0f172a;font-size:14px;border-bottom:1px solid #e9d5ff;">{{device}}</td>
  </tr>
  <tr>
    <td style="padding:14px 18px;color:#64748b;font-size:13px;font-weight:600;">IP Address</td>
    <td style="padding:14px 18px;color:#0f172a;font-size:14px;">{{ip}}</td>
  </tr>
</table>
<div style="padding:16px 20px;background:#fef3c7;border:1px solid #fcd34d;border-radius:10px;">
  <p style="margin:0;color:#92400e;font-size:14px;line-height:1.6;"><strong>Was this you?</strong> If you did not log in, please contact support immediately to secure your account.</p>
</div>
HTML; }
}
