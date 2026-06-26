import { useState, useEffect, useRef, useCallback } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Send, Eye, EyeOff, Plus, Trash2, CheckCircle2, Pencil } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input, Select, Textarea } from '../../components/ui/Input';
import { RichTextEditor } from '../../components/ui/RichTextEditor';
import { InfoTooltip } from '../../components/ui/InfoTooltip';
import { useToast } from '../../components/ui/Toast';
import { settingsApi, getApiErrorMessage, smtpConfigsApi } from '../../api';
import type { SmtpConfig, SmtpConfigPayload } from '../../api';
import { cn } from '../../utils';

type SettingValues = Record<string, string>;

// ── Section definitions ────────────────────────────────────────────────────────

interface SectionDef {
  id: string;
  title: string;
  subtitle?: string;
  keys: string[];
  cols?: 1 | 2;
}

const ALL_SECTIONS: SectionDef[] = [
  {
    id: 'general',
    title: 'General',
    subtitle: 'Basic app identity and contact details.',
    keys: ['app_name', 'support_email', 'support_phone', 'currency', 'currency_symbol'],
    cols: 2,
  },
  {
    id: 'booking',
    title: 'Booking & Fare',
    subtitle: 'Control how trips are priced and when payment is collected.',
    keys: ['calc_method', 'pay_mode', 'payment_provider', 'min_booking_fare', 'time_fare_enabled', 'time_fare_per_minute'],
    cols: 2,
  },
  {
    id: 'driver-assignment',
    title: 'Driver Assignment',
    subtitle: 'Configure automatic driver matching behaviour.',
    keys: ['auto_assign_enabled', 'driver_search_radius_km'],
    cols: 2,
  },
  {
    id: 'cancellation',
    title: 'Cancellation Rules',
    subtitle: 'Define who can cancel, within what time window, and any fees that apply.',
    keys: [
      'cancellation_allowed_by',
      'cancellation_window_minutes',
      'cancellation_fee_enabled',
      'cancellation_fee_amount',
      'cancellation_fee_after_assignment',
    ],
    cols: 2,
  },
  {
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Toggle email and push notification channels.',
    keys: ['email_notifications_enabled', 'fcm_enabled'],
    cols: 2,
  },
  {
    id: 'driver-app',
    title: 'Driver App',
    subtitle: 'Driver sign-in behaviour and location picker data.',
    keys: ['driver_auth_mode', 'driver_locations_json'],
    cols: 1,
  },
  {
    id: 'app-content',
    title: 'App Content',
    subtitle: 'These details are served to the mobile app and displayed to customers.',
    keys: ['app_tagline', 'about_text'],
    cols: 2,
  },
  {
    id: 'legal',
    title: 'Terms & Privacy',
    subtitle: 'Customers must accept Terms & Conditions during registration. Both are served via the public API.',
    keys: ['terms_and_conditions', 'privacy_policy'],
    cols: 1,
  },
  {
    id: 'smtp',
    title: 'SMTP / Email',
    subtitle: 'Manage up to 3 outgoing mail server profiles. Mark one active — all transactional emails use it.',
    keys: [],   // rendered by SmtpConfigManager below
    cols: 1,
  },
  {
    id: 'email-provider',
    title: 'OTP Email Provider',
    subtitle: 'Choose how one-time verification codes are emailed to users. Booking and driver emails always use SMTP.',
    keys: ['email_provider', 'termii_email_config_id'],
    cols: 2,
  },
  {
    id: 'flutterwave',
    title: 'Flutterwave',
    subtitle: 'Payment gateway credentials. Prefer setting secret keys in .env — those take priority over values saved here.',
    keys: ['flutterwave_public_key', 'flutterwave_secret_key', 'flutterwave_secret_hash'],
    cols: 1,
  },
  {
    id: 'delivery',
    title: 'Delivery Rules',
    subtitle: 'Rules shown to customers before they confirm a delivery booking.',
    keys: [],
    cols: 1,
  },
  {
    id: 'sms',
    title: 'SMS Provider',
    subtitle: 'Used to send one-time codes when users change their phone number or log in via OTP. Currently supports Termii (Nigerian SMS gateway).',
    keys: ['sms_provider', 'sms_api_key', 'sms_sender_id'],
    cols: 2,
  },
  {
    id: 'contact-verification',
    title: 'Contact Verification',
    subtitle: 'When enabled, users must verify a new phone number or email address with an OTP before the profile change is accepted.',
    keys: ['phone_verification_enabled', 'email_verification_enabled'],
    cols: 2,
  },
];

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
  driver_auth_mode:              [{ value: 'both', label: 'Both (Password + OTP)' }, { value: 'password', label: 'Password only' }, { value: 'otp', label: 'OTP only' }],
  time_fare_enabled:             [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  sms_provider:                  [{ value: '', label: 'Disabled (log only)' }, { value: 'termii', label: 'Termii' }],
  phone_verification_enabled:    [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  email_verification_enabled:    [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
  email_provider:                [{ value: 'smtp', label: 'SMTP (active profile)' }, { value: 'termii', label: 'Termii Email API' }],
};

const TEXTAREA_FIELDS = new Set(['about_text', 'terms_and_conditions', 'privacy_policy', 'driver_locations_json']);
const RICHTEXT_FIELDS = new Set(['terms_and_conditions', 'privacy_policy']);
const PASSWORD_FIELDS = new Set(['flutterwave_secret_key', 'flutterwave_secret_hash', 'sms_api_key']);

// ── Help text ──────────────────────────────────────────────────────────────────

const HELP: Record<string, string> = {
  app_name:                          'The name displayed to customers in the mobile app and on receipts.',
  support_email:                     'Customers see this email when they need help. Used in automated notification emails.',
  support_phone:                     'Support phone number shown in the app. Not used for automated calls.',
  currency:                          'ISO 4217 currency code, e.g. NGN for Nigerian Naira. Used in API responses.',
  currency_symbol:                   'Symbol shown in the UI, e.g. ₦. Does not affect calculations.',
  calc_method:                       'Server: distance calculated on the server via Haversine (more accurate). App: the mobile app sends the distance it calculated (faster, less server load).',
  pay_mode:                          'Pay on Booking: customer pays before the ride starts. Pay on Completion: customer pays after the ride ends.',
  payment_provider:                  'Which payment gateway handles card/transfer payments. Make sure the corresponding API keys are set below or in .env.',
  min_booking_fare:                  'The lowest possible fare for any trip. Even if the calculated fare is lower, this amount is charged.',
  time_fare_enabled:                 'When enabled, the fare includes a per-minute charge for the actual time the trip ran. This is calculated at trip completion using the real duration, not an estimate.',
  time_fare_per_minute:              'How much to charge per minute of trip time. Added on top of the distance fare. Example: ₦5/min on a 20-minute trip adds ₦100 to the bill.',
  auto_assign_enabled:               'When enabled, the system automatically finds and notifies the nearest available driver. When disabled, you must assign drivers manually from the Bookings page.',
  driver_search_radius_km:           'How far (in kilometres) the system searches for an available driver from the pickup point.',
  cancellation_allowed_by:           'Controls who can cancel a booking after it is confirmed. "None" disables cancellations entirely.',
  cancellation_window_minutes:       'How many minutes after booking the customer/driver can cancel for free.',
  cancellation_fee_enabled:          'When enabled, a fixed fee is charged for late cancellations.',
  cancellation_fee_amount:           'The flat fee charged when a booking is cancelled outside the free window.',
  cancellation_fee_after_assignment: 'When ON, the fee only applies once a driver has been assigned.',
  email_notifications_enabled:       'Sends email confirmations and status updates to customers. Requires SMTP configured below.',
  fcm_enabled:                       'Enables push notifications via Firebase Cloud Messaging. Requires FCM_SERVER_KEY in .env.',
  app_tagline:        'A short marketing tagline shown on the splash screen (e.g. "Your ride, your way").',
  about_text:         'About Us text shown in the app\'s About screen. Keep it concise.',
  terms_and_conditions: 'Full Terms & Conditions text. Customers must accept this during registration.',
  privacy_policy:     'Full Privacy Policy text. Required for app store compliance.',
  driver_auth_mode:         'Controls how drivers sign in. "Both" lets them choose between password and OTP.',
  driver_locations_json:    'JSON array of states and LGAs shown during driver registration. Format: [{"state":"Lagos","lgas":["Ikeja","Victoria Island"]}, ...]',
  smtp_enabled:       'Enable or disable sending transactional emails.',
  smtp_host:          'Your email server hostname (e.g. smtp.gmail.com).',
  smtp_port:          'SMTP port — typically 587 for TLS or 465 for SSL.',
  smtp_username:      'SMTP authentication username — usually your full email address.',
  smtp_password:      'SMTP authentication password. Stored in the database; ensure your server uses HTTPS.',
  smtp_encryption:    'Encryption method. TLS (STARTTLS) on port 587 is recommended.',
  smtp_from_name:     'Display name shown as the sender in outgoing emails.',
  smtp_from_email:    'The "From" address for outgoing emails. Must match the SMTP account or an authorised alias.',
  flutterwave_public_key:  'Your Flutterwave public key (starts with FLWPUBK). Used by the mobile app.',
  flutterwave_secret_key:  'Your Flutterwave secret key (starts with FLWSECK). Used server-side. Prefer setting FLUTTERWAVE_SECRET_KEY in .env.',
  flutterwave_secret_hash: 'The webhook hash/secret set in your Flutterwave dashboard. Used to verify incoming webhook signatures.',
  sms_provider:            'The SMS gateway to use for sending OTP codes. Set to "Termii" to enable real SMS, or leave blank to log messages only (useful for testing).',
  sms_api_key:             'Your Termii API key. Found in your Termii dashboard under API Keys. Keep this secret.',
  sms_sender_id:           'The sender name shown on SMS messages (e.g. "ETCRide"). Maximum 11 characters for Termii. Must be approved in your Termii dashboard.',
  phone_verification_enabled: 'When enabled, users must receive and enter an OTP to verify a new phone number before saving it in their profile.',
  email_verification_enabled:  'When enabled, users must receive and enter an OTP to verify a new email address before saving it in their profile.',
  email_provider:              'Which provider to use for OTP verification emails only. "SMTP" uses whichever SMTP profile is marked active. "Termii" uses Termii\'s email OTP API (requires Termii API key and Email Configuration ID below).',
  termii_email_config_id:      'Your Termii Email Configuration ID. Found in your Termii dashboard under the Email section. Required when email_provider = Termii.',
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
  time_fare_enabled:               'Time-Based Fare',
  time_fare_per_minute:            'Rate per Minute (₦)',
  auto_assign_enabled:             'Auto-Assign Driver',
  driver_search_radius_km:         'Driver Search Radius (km)',
  cancellation_allowed_by:         'Who Can Cancel',
  cancellation_window_minutes:     'Free Cancellation Window (min)',
  cancellation_fee_enabled:        'Cancellation Fee',
  cancellation_fee_amount:         'Cancellation Fee Amount (₦)',
  cancellation_fee_after_assignment: 'Fee Only After Assignment',
  email_notifications_enabled:     'Email Notifications',
  fcm_enabled:                     'Push Notifications (FCM)',
  app_tagline:          'App Tagline',
  about_text:           'About Us Text',
  terms_and_conditions: 'Terms & Conditions',
  privacy_policy:       'Privacy Policy',
  driver_auth_mode:       'Driver Sign-In Mode',
  driver_locations_json:  'States & LGAs (JSON)',
  smtp_enabled:     'SMTP Emails',
  smtp_host:        'SMTP Host',
  smtp_port:        'SMTP Port',
  smtp_username:    'SMTP Username',
  smtp_password:    'SMTP Password',
  smtp_encryption:  'Encryption',
  smtp_from_name:   'From Name',
  smtp_from_email:  'From Email',
  flutterwave_public_key:    'Public Key',
  flutterwave_secret_key:    'Secret Key',
  flutterwave_secret_hash:   'Webhook Secret Hash',
  sms_provider:              'SMS Provider',
  sms_api_key:               'API Key',
  sms_sender_id:             'Sender ID / From Name',
  phone_verification_enabled: 'Phone Change Verification',
  email_verification_enabled:  'Email Change Verification',
  email_provider:              'OTP Email Provider',
  termii_email_config_id:      'Termii Email Config ID',
};

// ── SMTP Config Manager ───────────────────────────────────────────────────────

const EMPTY_FORM: SmtpConfigPayload = {
  name: '', host: '', port: 587, username: '', password: '',
  encryption: 'tls', from_name: '', from_email: '',
};

function SmtpConfigManager() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const { data: configs = [], isLoading } = useQuery({
    queryKey: ['smtp-configs'],
    queryFn: () => smtpConfigsApi.list(),
  });

  const [modal, setModal]     = useState<'create' | number | null>(null); // number = editing id
  const [form, setForm]       = useState<SmtpConfigPayload>(EMPTY_FORM);
  const [showPw, setShowPw]   = useState(false);
  const [testTo, setTestTo]   = useState('');
  const [testing, setTesting] = useState<number | 'active' | null>(null);

  const openCreate = () => { setForm(EMPTY_FORM); setShowPw(false); setModal('create'); };
  const openEdit   = (cfg: SmtpConfig) => {
    setForm({
      name: cfg.name, host: cfg.host, port: cfg.port, username: cfg.username,
      password: '', encryption: cfg.encryption, from_name: cfg.from_name, from_email: cfg.from_email,
    });
    setShowPw(false);
    setModal(cfg.id);
  };

  const saveMutation = useMutation({
    mutationFn: () =>
      modal === 'create'
        ? smtpConfigsApi.create(form)
        : smtpConfigsApi.update(modal as number, form),
    onSuccess: () => {
      toast(modal === 'create' ? 'SMTP profile created.' : 'SMTP profile updated.', 'success');
      qc.invalidateQueries({ queryKey: ['smtp-configs'] });
      setModal(null);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const activateMutation = useMutation({
    mutationFn: (id: number) => smtpConfigsApi.activate(id),
    onSuccess: () => {
      toast('Active SMTP profile updated.', 'success');
      qc.invalidateQueries({ queryKey: ['smtp-configs'] });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => smtpConfigsApi.remove(id),
    onSuccess: () => {
      toast('SMTP profile deleted.', 'success');
      qc.invalidateQueries({ queryKey: ['smtp-configs'] });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const handleTest = async (id?: number) => {
    if (!testTo) { toast('Enter a recipient email first.', 'error'); return; }
    setTesting(id ?? 'active');
    try {
      await smtpConfigsApi.test(testTo, id);
      toast('Test email sent!', 'success');
    } catch (e: unknown) {
      toast(getApiErrorMessage(e), 'error');
    } finally {
      setTesting(null);
    }
  };

  const setF = (k: keyof SmtpConfigPayload, v: string | number) =>
    setForm(prev => ({ ...prev, [k]: v }));

  if (isLoading) return <div className="h-24 bg-slate-50 animate-pulse rounded-lg" />;

  return (
    <div className="space-y-3">
      {/* Config cards */}
      {configs.map(cfg => (
        <div
          key={cfg.id}
          className={cn(
            'rounded-xl border p-4 flex items-start gap-3 transition-colors',
            cfg.is_active ? 'border-brand-300 bg-brand-50' : 'border-slate-200 bg-white',
          )}
        >
          {/* Active badge / activate button */}
          <div className="mt-0.5 shrink-0">
            {cfg.is_active ? (
              <span className="flex items-center gap-1 text-xs font-semibold text-brand-700">
                <CheckCircle2 size={15} className="text-brand-600" /> Active
              </span>
            ) : (
              <button
                onClick={() => activateMutation.mutate(cfg.id)}
                disabled={activateMutation.isPending}
                className="text-xs text-slate-400 hover:text-brand-600 font-medium transition-colors whitespace-nowrap"
              >
                Set active
              </button>
            )}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-slate-800">{cfg.name}</p>
            <p className="text-xs text-slate-500 mt-0.5 truncate">
              {cfg.host}:{cfg.port} · {cfg.from_email || cfg.username}
            </p>
            <p className="text-xs text-slate-400 mt-0.5 uppercase tracking-wide">{cfg.encryption}</p>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={() => openEdit(cfg)}
              className="text-slate-400 hover:text-slate-700 p-1 transition-colors"
              title="Edit"
            >
              <Pencil size={14} />
            </button>
            <button
              onClick={() => deleteMutation.mutate(cfg.id)}
              disabled={deleteMutation.isPending}
              className="text-slate-400 hover:text-red-500 p-1 transition-colors"
              title="Delete"
            >
              <Trash2 size={14} />
            </button>
          </div>
        </div>
      ))}

      {/* Add button */}
      {configs.length < 3 && (
        <button
          onClick={openCreate}
          className="flex items-center gap-1.5 text-sm text-brand-600 hover:text-brand-700 font-medium"
        >
          <Plus size={14} /> Add SMTP Profile
        </button>
      )}

      {/* Test email row */}
      <div className="pt-3 border-t border-slate-100">
        <p className="text-xs font-medium text-slate-700 mb-2 flex items-center gap-1.5">
          Send Test Email
          <InfoTooltip content="Tests the active SMTP profile. Save any profile changes first." position="top" />
        </p>
        <div className="flex items-center gap-2">
          <input
            type="email"
            value={testTo}
            onChange={e => setTestTo(e.target.value)}
            placeholder="recipient@example.com"
            className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
          />
          <Button
            size="sm"
            variant="secondary"
            icon={<Send size={13} />}
            loading={testing === 'active'}
            onClick={() => handleTest()}
          >
            Send Test
          </Button>
        </div>
      </div>

      {/* Create / Edit modal */}
      {modal !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg p-6 space-y-4">
            <h3 className="text-base font-semibold text-slate-900">
              {modal === 'create' ? 'Add SMTP Profile' : 'Edit SMTP Profile'}
            </h3>

            <div className="grid grid-cols-2 gap-3">
              <div className="col-span-2">
                <Input label="Profile Name" value={form.name} onChange={e => setF('name', e.target.value)} placeholder="e.g. Primary, Backup" />
              </div>
              <Input label="SMTP Host" value={form.host} onChange={e => setF('host', e.target.value)} placeholder="smtp.gmail.com" />
              <Input label="Port" type="number" value={String(form.port)} onChange={e => setF('port', Number(e.target.value))} />
              <Input label="Username" value={form.username} onChange={e => setF('username', e.target.value)} placeholder="you@example.com" />
              <div className="flex flex-col gap-1">
                <label className="text-sm font-medium text-slate-700">Password</label>
                <div className="relative">
                  <input
                    type={showPw ? 'text' : 'password'}
                    value={form.password}
                    onChange={e => setF('password', e.target.value)}
                    placeholder={modal !== 'create' ? '(unchanged)' : 'SMTP password'}
                    className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 pr-10 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPw(p => !p)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    {showPw ? <EyeOff size={14} /> : <Eye size={14} />}
                  </button>
                </div>
              </div>
              <Select
                label="Encryption"
                value={form.encryption}
                onChange={e => setF('encryption', e.target.value)}
                options={[
                  { value: 'tls', label: 'TLS (port 587) — recommended' },
                  { value: 'ssl', label: 'SSL (port 465)' },
                  { value: 'none', label: 'None — not recommended' },
                ]}
              />
              <Input label="From Name" value={form.from_name} onChange={e => setF('from_name', e.target.value)} placeholder="ETCRide" />
              <div className="col-span-2">
                <Input label="From Email" value={form.from_email} onChange={e => setF('from_email', e.target.value)} placeholder="noreply@yourdomain.com" />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setModal(null)}>Cancel</Button>
              <Button
                icon={<Save size={13} />}
                loading={saveMutation.isPending}
                onClick={() => saveMutation.mutate()}
              >
                {modal === 'create' ? 'Create' : 'Save'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Delivery Rules Editor ─────────────────────────────────────────────────────

function DeliveryRulesEditor({
  value,
  onChange,
}: {
  value: string;
  onChange: (json: string) => void;
}) {
  const rules: string[] = (() => {
    try { const p = JSON.parse(value || '[]'); return Array.isArray(p) ? p : []; }
    catch { return []; }
  })();

  const update = (newRules: string[]) => onChange(JSON.stringify(newRules));
  const setRule = (i: number, v: string) => {
    const next = [...rules]; next[i] = v; update(next);
  };
  const addRule = () => update([...rules, '']);
  const removeRule = (i: number) => update(rules.filter((_, j) => j !== i));

  return (
    <div className="space-y-2">
      {rules.map((rule, i) => (
        <div key={i} className="flex items-center gap-2">
          <span className="text-slate-400 text-sm w-5 shrink-0">{i + 1}.</span>
          <input
            type="text"
            value={rule}
            onChange={e => setRule(i, e.target.value)}
            placeholder={`Rule ${i + 1}`}
            className="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
          />
          <button
            type="button"
            onClick={() => removeRule(i)}
            className="text-slate-400 hover:text-red-500 transition-colors p-1"
          >
            <Trash2 size={15} />
          </button>
        </div>
      ))}
      <button
        type="button"
        onClick={addRule}
        className="flex items-center gap-1.5 text-sm text-brand-600 hover:text-brand-700 font-medium mt-1"
      >
        <Plus size={14} /> Add Rule
      </button>
      {rules.length === 0 && (
        <p className="text-xs text-slate-400 italic">No rules configured. Click "Add Rule" to get started.</p>
      )}
    </div>
  );
}

// ── Component ──────────────────────────────────────────────────────────────────

export function SettingsPage() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [values, setValues]               = useState<SettingValues>({});
  const [dirty, setDirty]                 = useState<SettingValues>({});
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});
  const [activeSection, setActiveSection] = useState(ALL_SECTIONS[0].id);

  const sectionRefs = useRef<Record<string, HTMLElement | null>>({});
  const navRef       = useRef<HTMLDivElement>(null);
  const scrolling    = useRef(false);

  const { data: settings, isLoading } = useQuery({
    queryKey: ['settings'],
    queryFn: () => settingsApi.list(),
  });

  useEffect(() => {
    if (!settings) return;
    const flat: SettingValues = {};
    Object.entries(settings).forEach(([k, v]) => { flat[k] = (v as { value: string }).value; });
    setValues(flat);
    setDirty({});
  }, [settings]);

  // ── Scroll-spy ───────────────────────────────────────────────────────────────
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (scrolling.current) return;
        // pick the topmost visible section
        const visible = entries
          .filter(e => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible.length > 0) {
          setActiveSection(visible[0].target.id);
        }
      },
      { rootMargin: '-10% 0px -60% 0px', threshold: 0 },
    );

    Object.values(sectionRefs.current).forEach(el => { if (el) observer.observe(el); });
    return () => observer.disconnect();
  }, [isLoading]);

  const scrollToSection = useCallback((id: string) => {
    const el = sectionRefs.current[id];
    if (!el) return;
    setActiveSection(id);
    scrolling.current = true;
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setTimeout(() => { scrolling.current = false; }, 800);
  }, []);

  const set = (key: string, val: string) => {
    setValues(prev => ({ ...prev, [key]: val }));
    setDirty(prev => ({ ...prev, [key]: val }));
  };

  const saveMutation = useMutation({
    mutationFn: () => settingsApi.update(dirty),
    onSuccess: data => {
      toast(`Saved: ${(data as { updated: string[] }).updated.join(', ')}`, 'success');
      qc.invalidateQueries({ queryKey: ['settings'] });
      setDirty({});
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

const hasDirty = Object.keys(dirty).length > 0;
  const dirtyCount = Object.keys(dirty).length;

  const renderField = (key: string) => {
    const label   = LABELS[key] ?? key;
    const current = values[key] ?? '';
    const desc    = (settings?.[key] as { description?: string } | undefined)?.description;
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

    if (RICHTEXT_FIELDS.has(key)) {
      return (
        <RichTextEditor
          key={key}
          label={labelNode}
          value={current}
          onChange={v => set(key, v)}
          placeholder={`Enter ${label.toLowerCase()}…`}
          helper={desc}
        />
      );
    }

    if (isArea) {
      return (
        <div key={key} className="col-span-full">
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
      const visible = showPasswords[key] ?? false;
      return (
        <div key={key} className="flex flex-col gap-1">
          <label className="text-sm font-medium text-slate-700 flex items-center gap-1.5">
            {label}
            {help && <InfoTooltip content={help} position="top" />}
          </label>
          <div className="relative">
            <input
              type={visible ? 'text' : 'password'}
              value={current}
              onChange={e => set(key, e.target.value)}
              placeholder={`Enter ${label.toLowerCase()}`}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 pr-10 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
            />
            <button
              type="button"
              onClick={() => setShowPasswords(p => ({ ...p, [key]: !visible }))}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            >
              {visible ? <EyeOff size={15} /> : <Eye size={15} />}
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
          Save Changes {hasDirty ? `(${dirtyCount})` : ''}
        </Button>
      }
    >
      {isLoading ? (
        <div className="space-y-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-32 rounded-xl bg-white border border-slate-200 animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="flex gap-6 items-start">

          {/* ── Left sticky nav ──────────────────────────────────────────── */}
          <nav
            ref={navRef}
            className="hidden lg:flex flex-col w-48 shrink-0 sticky top-6 self-start gap-0.5"
          >
            {ALL_SECTIONS.map(s => (
              <button
                key={s.id}
                onClick={() => scrollToSection(s.id)}
                className={cn(
                  'text-left text-sm px-3 py-2 rounded-lg font-medium transition-colors',
                  activeSection === s.id
                    ? 'bg-brand-50 text-brand-700'
                    : 'text-slate-500 hover:text-slate-800 hover:bg-slate-100',
                )}
              >
                {s.title}
              </button>
            ))}
          </nav>

          {/* ── Section cards ─────────────────────────────────────────────── */}
          <div className="flex-1 min-w-0 space-y-6">
            {ALL_SECTIONS.map(section => (
              <Card
                key={section.id}
                id={section.id}
                ref={(el: HTMLDivElement | null) => { sectionRefs.current[section.id] = el; }}
              >
                <div className="pb-3 mb-4 border-b border-slate-100">
                  <h2 className="text-sm font-semibold text-slate-900">{section.title}</h2>
                  {section.subtitle && (
                    <p className="text-xs text-slate-500 mt-0.5">{section.subtitle}</p>
                  )}
                </div>

                <div className={cn(
                  'grid gap-4',
                  section.cols === 2 ? 'grid-cols-1 sm:grid-cols-2' : 'grid-cols-1',
                )}>
                  {section.keys.map(key => renderField(key))}
                </div>

                {/* SMTP Config Manager — only on SMTP section */}
                {section.id === 'smtp' && <SmtpConfigManager />}

                {/* Delivery rules editor — only on delivery section */}
                {section.id === 'delivery' && (
                  <DeliveryRulesEditor
                    value={values['delivery_rules'] ?? '[]'}
                    onChange={val => set('delivery_rules', val)}
                  />
                )}

                {/* SMS setup instructions — only on SMS section */}
                {section.id === 'sms' && (
                  <div className="mt-5 pt-4 border-t border-slate-100 space-y-2">
                    <p className="text-xs font-semibold text-slate-700">How to get a Termii API key</p>
                    <ol className="text-xs text-slate-500 list-decimal pl-4 space-y-1 leading-relaxed">
                      <li>Go to <span className="font-medium text-slate-700">termii.com</span> and create a free account.</li>
                      <li>In the dashboard, open <span className="font-medium text-slate-700">Settings → API Keys</span> and copy your key.</li>
                      <li>Under <span className="font-medium text-slate-700">Sender ID</span>, request a custom sender ID (e.g. <code className="bg-slate-100 px-1 rounded">ETCRide</code>). Approval takes 1–2 business days.</li>
                      <li>Paste the API key above, set the provider to <span className="font-medium text-slate-700">Termii</span>, and save.</li>
                      <li>Only Nigerian numbers (<code className="bg-slate-100 px-1 rounded">+234</code> / <code className="bg-slate-100 px-1 rounded">07x</code> / <code className="bg-slate-100 px-1 rounded">08x</code> / <code className="bg-slate-100 px-1 rounded">09x</code>) are supported by this platform.</li>
                    </ol>
                  </div>
                )}

                {/* Env note — only on Flutterwave section */}
                {section.id === 'flutterwave' && (
                  <p className="mt-4 text-xs text-slate-400 leading-relaxed">
                    Values in <code className="bg-slate-100 px-1 rounded">.env</code> take priority over what's saved here.
                    Prefer <code className="bg-slate-100 px-1 rounded">FLUTTERWAVE_SECRET_KEY</code> and{' '}
                    <code className="bg-slate-100 px-1 rounded">FLUTTERWAVE_SECRET_HASH</code> in .env for production.
                  </p>
                )}
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* ── Sticky save bar ───────────────────────────────────────────────── */}
      {hasDirty && (
        <div className="fixed bottom-6 right-6 z-40">
          <div className="flex items-center gap-3 rounded-xl bg-slate-900 px-4 py-3 shadow-xl text-white text-sm">
            <span>{dirtyCount} unsaved change{dirtyCount > 1 ? 's' : ''}</span>
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
