import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Send, Eye, EyeOff } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input, Select, Textarea } from '../../components/ui/Input';
import { InfoTooltip } from '../../components/ui/InfoTooltip';
import { useToast } from '../../components/ui/Toast';
import { settingsApi } from '../../api';
import { emailTemplatesApi } from '../../api/emailTemplates';

type SettingValues = Record<string, string>;

// ── Section definitions ────────────────────────────────────────────────────────

const SECTIONS = [
  {
    title: 'General',
    keys: ['app_name', 'support_email', 'support_phone', 'currency', 'currency_symbol'],
  },
  {
    title: 'Booking & Fare',
    keys: ['calc_method', 'pay_mode', 'payment_provider', 'min_booking_fare'],
  },
  {
    title: 'Driver Assignment',
    keys: ['auto_assign_enabled', 'driver_search_radius_km'],
  },
  {
    title: 'Cancellation Rules',
    keys: [
      'cancellation_allowed_by',
      'cancellation_window_minutes',
      'cancellation_fee_enabled',
      'cancellation_fee_amount',
      'cancellation_fee_after_assignment',
    ],
  },
  {
    title: 'Notifications',
    keys: ['email_notifications_enabled', 'fcm_enabled'],
  },
];

const APP_CONTENT_SECTION = {
  title: 'App Content',
  keys: ['app_tagline', 'about_text'],
};

const LEGAL_SECTION = {
  title: 'Terms & Privacy',
  keys: ['terms_and_conditions', 'privacy_policy'],
};

const SMTP_SECTION = {
  title: 'SMTP / Email',
  keys: [
    'smtp_enabled', 'smtp_host', 'smtp_port', 'smtp_username',
    'smtp_password', 'smtp_encryption', 'smtp_from_name', 'smtp_from_email',
  ],
};

// ── Field type classifiers ─────────────────────────────────────────────────────

const SELECT_FIELDS: Record<string, { value: string; label: string }[]> = {
  calc_method:              [{ value: 'server', label: 'Server (Haversine)' }, { value: 'app', label: 'App (Client-provided)' }],
  pay_mode:                 [{ value: 'pay_on_booking', label: 'Pay on Booking' }, { value: 'pay_on_completion', label: 'Pay on Completion' }],
  payment_provider:         [{ value: 'flutterwave', label: 'Flutterwave' }, { value: 'monnify', label: 'Monnify' }],
  cancellation_allowed_by:  [{ value: 'customer', label: 'Customer' }, { value: 'driver', label: 'Driver' }, { value: 'both', label: 'Both' }, { value: 'none', label: 'None' }],
  auto_assign_enabled:      [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  cancellation_fee_enabled: [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  cancellation_fee_after_assignment: [{ value: '1', label: 'Only after driver assigned' }, { value: '0', label: 'Always' }],
  email_notifications_enabled: [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  fcm_enabled:              [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  smtp_enabled:             [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  smtp_encryption:          [{ value: 'tls', label: 'TLS (STARTTLS) — recommended' }, { value: 'ssl', label: 'SSL (SMTPS)' }, { value: 'none', label: 'None — not recommended' }],
};

const TEXTAREA_FIELDS = new Set(['about_text', 'terms_and_conditions', 'privacy_policy']);
const PASSWORD_FIELDS = new Set(['smtp_password']);

// ── Help text ──────────────────────────────────────────────────────────────────

const HELP: Record<string, string> = {
  app_name:                          'The name displayed to customers in the mobile app and on receipts.',
  support_email:                     'Customers see this email when they need help. Used in automated notification emails.',
  support_phone:                     'Support phone number shown in the app. Not used for automated calls.',
  currency:                          'ISO 4217 currency code, e.g. NGN for Nigerian Naira. Used in API responses.',
  currency_symbol:                   'Symbol shown in the UI, e.g. ₦. Does not affect calculations.',
  calc_method:                       'Server: distance is calculated on the server using the Haversine formula (more accurate). App: the mobile app sends the distance it calculated (faster, less server load).',
  pay_mode:                          'Pay on Booking: customer pays before the ride starts. Pay on Completion: customer pays after the ride ends.',
  payment_provider:                  'Which payment gateway handles card/transfer payments. Make sure the corresponding API keys are set in .env.',
  min_booking_fare:                  'The lowest possible fare for any trip. Even if the calculated fare is lower, this amount is charged.',
  auto_assign_enabled:               'When enabled, the system automatically finds and notifies the nearest available driver. When disabled, you must assign drivers manually from the Bookings page.',
  driver_search_radius_km:           'How far (in kilometres) the system searches for an available driver from the pickup point. Increase if drivers are scarce; decrease for denser areas.',
  cancellation_allowed_by:           'Controls who can cancel a booking after it is confirmed. "None" disables cancellations entirely.',
  cancellation_window_minutes:       'How many minutes after booking the customer/driver can cancel for free. Cancellations after this window may incur a fee.',
  cancellation_fee_enabled:          'When enabled, a fixed fee is charged for late cancellations.',
  cancellation_fee_amount:           'The flat fee charged when a booking is cancelled outside the free window.',
  cancellation_fee_after_assignment: 'When ON, the fee only applies once a driver has been assigned. Cancellations before driver assignment are always free.',
  email_notifications_enabled:       'Sends email confirmations and status updates to customers. Requires SMTP to be configured below.',
  fcm_enabled:                       'Enables push notifications to the driver and customer mobile apps via Firebase Cloud Messaging. Requires FCM_SERVER_KEY in .env.',
  // App content
  app_tagline:        'A short marketing tagline shown on the app splash screen and website (e.g. "Your ride, your way").',
  about_text:         'About Us text shown in the app\'s About screen. Supports plain text. Keep it concise.',
  terms_and_conditions: 'Full Terms & Conditions text shown in the app. Customers must accept this during registration.',
  privacy_policy:     'Full Privacy Policy text shown in the app. Required for app store compliance.',
  // SMTP
  smtp_enabled:       'Enable or disable sending transactional emails (booking confirmations, cancellations, etc.).',
  smtp_host:          'Your email server hostname (e.g. smtp.gmail.com, mail.your-domain.com). Provided by your email host.',
  smtp_port:          'SMTP port. Typically 587 for TLS (STARTTLS) or 465 for SSL. Port 25 is usually blocked by hosts.',
  smtp_username:      'SMTP authentication username — usually your full email address.',
  smtp_password:      'SMTP authentication password. This is stored in the database; ensure your server is on HTTPS.',
  smtp_encryption:    'Encryption method for the SMTP connection. TLS (STARTTLS) on port 587 is recommended for most providers.',
  smtp_from_name:     'Display name shown as the sender in outgoing emails (e.g. "EtcRide Support").',
  smtp_from_email:    'The "From" email address for outgoing emails. Must match the SMTP account or be an authorised alias.',
};

const LABELS: Record<string, string> = {
  app_name:                        'App Name',
  support_email:                   'Support Email',
  support_phone:                   'Support Phone',
  currency:                        'Currency Code',
  currency_symbol:                 'Currency Symbol',
  calc_method:                     'Distance Calculation',
  pay_mode:                        'Payment Mode',
  payment_provider:                'Payment Provider',
  min_booking_fare:                'Minimum Booking Fare (₦)',
  auto_assign_enabled:             'Auto-Assign Driver',
  driver_search_radius_km:         'Driver Search Radius (km)',
  cancellation_allowed_by:         'Who Can Cancel',
  cancellation_window_minutes:     'Free Cancellation Window (minutes)',
  cancellation_fee_enabled:        'Cancellation Fee',
  cancellation_fee_amount:         'Cancellation Fee Amount (₦)',
  cancellation_fee_after_assignment: 'Charge Fee Only After Assignment',
  email_notifications_enabled:     'Email Notifications',
  fcm_enabled:                     'Push Notifications (FCM)',
  // App content
  app_tagline:          'App Tagline',
  about_text:           'About Us Text',
  terms_and_conditions: 'Terms & Conditions',
  privacy_policy:       'Privacy Policy',
  // SMTP
  smtp_enabled:     'SMTP Emails',
  smtp_host:        'SMTP Host',
  smtp_port:        'SMTP Port',
  smtp_username:    'SMTP Username',
  smtp_password:    'SMTP Password',
  smtp_encryption:  'Encryption',
  smtp_from_name:   'From Name',
  smtp_from_email:  'From Email',
};

// ── Component ──────────────────────────────────────────────────────────────────

export function SettingsPage() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [values, setValues] = useState<SettingValues>({});
  const [dirty, setDirty]   = useState<SettingValues>({});
  const [showSmtpPassword, setShowSmtpPassword] = useState(false);
  const [testEmailTo, setTestEmailTo]           = useState('');
  const [testingEmail, setTestingEmail]         = useState(false);

  const { data: settings, isLoading } = useQuery({
    queryKey: ['settings'],
    queryFn: () => settingsApi.list(),
  });

  useEffect(() => {
    if (!settings) return;
    const flat: SettingValues = {};
    Object.entries(settings).forEach(([k, v]) => { flat[k] = v.value; });
    setValues(flat);
    setDirty({});
  }, [settings]);

  const set = (key: string, val: string) => {
    setValues(prev => ({ ...prev, [key]: val }));
    setDirty(prev => ({ ...prev, [key]: val }));
  };

  const saveMutation = useMutation({
    mutationFn: () => settingsApi.update(dirty),
    onSuccess: data => {
      toast(`Saved: ${data.updated.join(', ')}`, 'success');
      qc.invalidateQueries({ queryKey: ['settings'] });
      setDirty({});
    },
    onError: (e: Error) => toast(e.message, 'error'),
  });

  const handleTestEmail = async () => {
    if (!testEmailTo) { toast('Enter a recipient email first.', 'error'); return; }
    setTestingEmail(true);
    try {
      const res = await emailTemplatesApi.test(testEmailTo, 'booking_confirmed');
      toast(res.message, 'success');
    } catch (e: unknown) {
      toast((e as Error).message ?? 'Test email failed.', 'error');
    } finally {
      setTestingEmail(false);
    }
  };

  const hasDirty = Object.keys(dirty).length > 0;

  const renderField = (key: string) => {
    const label   = LABELS[key] ?? key;
    const current = values[key] ?? '';
    const desc    = settings?.[key]?.description;
    const help    = HELP[key];
    const options = SELECT_FIELDS[key];
    const isArea  = TEXTAREA_FIELDS.has(key);
    const isPass  = PASSWORD_FIELDS.has(key);

    const labelNode = (
      <span className="flex items-center gap-1.5">
        {label}
        {help && <InfoTooltip content={help} position="top" />}
      </span>
    );

    if (options) {
      return (
        <Select
          key={key}
          label={labelNode as unknown as string}
          value={current}
          onChange={e => set(key, e.target.value)}
          options={options}
          helper={desc}
        />
      );
    }

    if (isArea) {
      return (
        <div key={key} className="sm:col-span-2">
          <Textarea
            label={labelNode as unknown as string}
            value={current}
            onChange={e => set(key, e.target.value)}
            rows={8}
            placeholder={`Enter ${label.toLowerCase()}…`}
          />
          {desc && <p className="mt-1 text-xs text-slate-500">{desc}</p>}
        </div>
      );
    }

    if (isPass) {
      return (
        <div key={key} className="flex flex-col gap-1">
          <label className="text-sm font-medium text-slate-700 flex items-center gap-1.5">
            {label}
            {help && <InfoTooltip content={help} position="top" />}
          </label>
          <div className="relative">
            <input
              type={showSmtpPassword ? 'text' : 'password'}
              value={current}
              onChange={e => set(key, e.target.value)}
              placeholder="Enter SMTP password"
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 pr-10 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
            />
            <button
              type="button"
              onClick={() => setShowSmtpPassword(p => !p)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            >
              {showSmtpPassword ? <EyeOff size={15} /> : <Eye size={15} />}
            </button>
          </div>
          {desc && <p className="text-xs text-slate-500">{desc}</p>}
        </div>
      );
    }

    return (
      <Input
        key={key}
        label={labelNode as unknown as string}
        value={current}
        onChange={e => set(key, e.target.value)}
        helper={desc}
      />
    );
  };

  return (
    <PageWrapper
      title="Settings"
      subtitle="Configure platform-wide behaviour"
      actions={
        <Button
          icon={<Save size={14} />}
          loading={saveMutation.isPending}
          disabled={!hasDirty}
          onClick={() => saveMutation.mutate()}
        >
          Save Changes {hasDirty ? `(${Object.keys(dirty).length})` : ''}
        </Button>
      }
    >
      {isLoading ? (
        <div className="space-y-4">
          {[1,2,3].map(i => <div key={i} className="h-32 rounded-xl bg-white border border-slate-200 animate-pulse" />)}
        </div>
      ) : (
        <div className="space-y-6">

          {/* Standard sections */}
          {SECTIONS.map(section => (
            <Card key={section.title}>
              <h2 className="text-sm font-semibold text-slate-900 mb-4 pb-3 border-b border-slate-100">
                {section.title}
              </h2>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                {section.keys.map(key => renderField(key))}
              </div>
            </Card>
          ))}

          {/* App Content */}
          <Card>
            <h2 className="text-sm font-semibold text-slate-900 mb-1 pb-3 border-b border-slate-100">
              {APP_CONTENT_SECTION.title}
            </h2>
            <p className="text-xs text-slate-500 mb-4">
              These details are served to the mobile app and displayed to customers.
            </p>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              {APP_CONTENT_SECTION.keys.map(key => renderField(key))}
            </div>
          </Card>

          {/* Terms & Privacy */}
          <Card>
            <h2 className="text-sm font-semibold text-slate-900 mb-1 pb-3 border-b border-slate-100">
              {LEGAL_SECTION.title}
            </h2>
            <p className="text-xs text-slate-500 mb-4">
              Customers must accept the Terms & Conditions during registration. Both are served via the public API.
            </p>
            <div className="grid grid-cols-1 gap-4">
              {LEGAL_SECTION.keys.map(key => renderField(key))}
            </div>
          </Card>

          {/* SMTP */}
          <Card>
            <h2 className="text-sm font-semibold text-slate-900 mb-1 pb-3 border-b border-slate-100">
              {SMTP_SECTION.title}
            </h2>
            <p className="text-xs text-slate-500 mb-4">
              Configure your outgoing mail server for booking confirmations, driver assignments, and cancellation notices.
              Go to <strong>Email Templates</strong> in the sidebar to customise the email content.
            </p>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              {SMTP_SECTION.keys.map(key => renderField(key))}
            </div>

            {/* Test email */}
            <div className="mt-5 pt-4 border-t border-slate-100">
              <p className="text-xs font-medium text-slate-700 mb-2 flex items-center gap-1.5">
                Send Test Email
                <InfoTooltip
                  content="Sends a sample Booking Confirmed email using the SMTP settings above. Save your settings first before testing."
                  position="top"
                />
              </p>
              <div className="flex items-center gap-2">
                <input
                  type="email"
                  value={testEmailTo}
                  onChange={e => setTestEmailTo(e.target.value)}
                  placeholder="recipient@example.com"
                  className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
                />
                <Button
                  size="sm"
                  variant="secondary"
                  icon={<Send size={13} />}
                  loading={testingEmail}
                  onClick={handleTestEmail}
                >
                  Send Test
                </Button>
              </div>
            </div>
          </Card>

        </div>
      )}

      {/* Sticky save bar when dirty */}
      {hasDirty && (
        <div className="fixed bottom-6 right-6 z-40">
          <div className="flex items-center gap-3 rounded-xl bg-slate-900 px-4 py-3 shadow-xl text-white text-sm">
            <span>{Object.keys(dirty).length} unsaved change{Object.keys(dirty).length > 1 ? 's' : ''}</span>
            <Button
              size="sm"
              loading={saveMutation.isPending}
              onClick={() => saveMutation.mutate()}
              className="bg-brand-500 hover:bg-brand-400"
            >
              Save now
            </Button>
          </div>
        </div>
      )}
    </PageWrapper>
  );
}
