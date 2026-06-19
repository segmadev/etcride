import { useState, useEffect, useRef, useCallback } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Send, Eye, EyeOff, Plus, Trash2 } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input, Select, Textarea } from '../../components/ui/Input';
import { InfoTooltip } from '../../components/ui/InfoTooltip';
import { useToast } from '../../components/ui/Toast';
import { settingsApi, getApiErrorMessage } from '../../api';
import { emailTemplatesApi } from '../../api/emailTemplates';
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
    subtitle: 'Outgoing mail server for booking confirmations, driver assignments, and cancellation notices.',
    keys: [
      'smtp_enabled', 'smtp_host', 'smtp_port', 'smtp_username',
      'smtp_password', 'smtp_encryption', 'smtp_from_name', 'smtp_from_email',
    ],
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
  driver_auth_mode:         [{ value: 'both', label: 'Both (Password + OTP)' }, { value: 'password', label: 'Password only' }, { value: 'otp', label: 'OTP only' }],
  time_fare_enabled:        [{ value: '1', label: 'Enabled' }, { value: '0', label: 'Disabled' }],
};

const TEXTAREA_FIELDS = new Set(['about_text', 'terms_and_conditions', 'privacy_policy', 'driver_locations_json']);
const PASSWORD_FIELDS = new Set(['smtp_password', 'flutterwave_secret_key', 'flutterwave_secret_hash']);

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
  flutterwave_public_key:   'Public Key',
  flutterwave_secret_key:   'Secret Key',
  flutterwave_secret_hash:  'Webhook Secret Hash',
};

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
  const [testEmailTo, setTestEmailTo]     = useState('');
  const [testingEmail, setTestingEmail]   = useState(false);
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

  const handleTestEmail = async () => {
    if (!testEmailTo) { toast('Enter a recipient email first.', 'error'); return; }
    setTestingEmail(true);
    try {
      const res = await emailTemplatesApi.test(testEmailTo, 'booking_confirmed') as { message: string };
      toast(res.message, 'success');
    } catch (e: unknown) {
      toast((e as Error).message ?? 'Test email failed.', 'error');
    } finally {
      setTestingEmail(false);
    }
  };

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

                {/* Test email — only on SMTP section */}
                {section.id === 'smtp' && (
                  <div className="mt-5 pt-4 border-t border-slate-100">
                    <p className="text-xs font-medium text-slate-700 mb-2 flex items-center gap-1.5">
                      Send Test Email
                      <InfoTooltip
                        content="Sends a sample Booking Confirmed email using the SMTP settings above. Save your settings first."
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
                )}

                {/* Delivery rules editor — only on delivery section */}
                {section.id === 'delivery' && (
                  <DeliveryRulesEditor
                    value={values['delivery_rules'] ?? '[]'}
                    onChange={val => set('delivery_rules', val)}
                  />
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
