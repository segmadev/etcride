import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Send, Eye, Code } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { InfoTooltip } from '../../components/ui/InfoTooltip';
import { useToast } from '../../components/ui/Toast';
import { emailTemplatesApi, type EmailTemplate } from '../../api/emailTemplates';
import { settingsApi, getApiErrorMessage } from '../../api';

// ── Preview modal ──────────────────────────────────────────────────────────────

function PreviewModal({ html, onClose }: { html: string; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="w-full max-w-2xl max-h-[80vh] overflow-auto rounded-xl bg-white shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-3 border-b border-slate-200">
          <span className="text-sm font-semibold text-slate-800">Email Preview</span>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 text-lg leading-none">×</button>
        </div>
        <iframe
          srcDoc={html}
          title="Email Preview"
          className="w-full"
          style={{ height: '600px', border: 'none' }}
        />
      </div>
    </div>
  );
}

// ── Variable chip list ─────────────────────────────────────────────────────────

function VariableChips({ variables }: { variables: string[] }) {
  return (
    <div className="flex flex-wrap gap-1.5 mt-2">
      {variables.map(v => (
        <code
          key={v}
          className="rounded bg-slate-100 px-2 py-0.5 text-xs font-mono text-slate-700 border border-slate-200 select-all cursor-copy"
          title="Click to copy"
          onClick={() => navigator.clipboard.writeText(v)}
        >
          {v}
        </code>
      ))}
    </div>
  );
}

// ── Single template editor ─────────────────────────────────────────────────────

function TemplateEditor({
  template,
  isActive,
  onClick,
  onSave,
  isSaving,
}: {
  template: EmailTemplate;
  isActive: boolean;
  onClick: () => void;
  onSave: (key: string, subject: string, body: string) => void;
  isSaving: boolean;
}) {
  const [subject, setSubject] = useState(template.subject);
  const [body, setBody]       = useState(template.body);
  const [preview, setPreview] = useState<string | null>(null);
  const [testTo, setTestTo]   = useState('');
  const [sendingTest, setSendingTest] = useState(false);
  const { toast } = useToast();

  const isDirty = subject !== template.subject || body !== template.body;

  const handlePreview = () => {
    const sampleVars: Record<string, string> = {
      '{{app_name}}':            'EtcRide',
      '{{customer_name}}':       'John Doe',
      '{{booking_code}}':        'BK-DEMO123',
      '{{pickup_address}}':      '12 Sample Street, Ilorin',
      '{{destination_address}}': '45 Demo Avenue, Ilorin',
      '{{estimated_fare}}':      '₦1,500',
      '{{driver_name}}':         'Ahmed Musa',
      '{{driver_phone}}':        '+234 801 234 5678',
      '{{vehicle_type}}':        'Economy',
      '{{cancellation_reason}}': 'Test cancellation',
      '{{support_email}}':       'support@etcride.com',
    };
    let rendered = body;
    Object.entries(sampleVars).forEach(([k, v]) => {
      rendered = rendered.replaceAll(k, v);
    });
    setPreview(rendered);
  };

  const handleSendTest = async () => {
    if (!testTo) { toast('Enter a recipient email first.', 'error'); return; }
    setSendingTest(true);
    try {
      const res = await emailTemplatesApi.test(testTo, template.key);
      toast(res.message, 'success');
    } catch (e: unknown) {
      toast((e as Error).message ?? 'Test email failed.', 'error');
    } finally {
      setSendingTest(false);
    }
  };

  return (
    <>
      {/* Collapsed header (tab-style) */}
      <div
        className={`border rounded-xl overflow-hidden transition-shadow ${isActive ? 'shadow-md border-brand-200' : 'border-slate-200 cursor-pointer hover:border-slate-300'}`}
      >
        <button
          type="button"
          onClick={onClick}
          className={`w-full flex items-center justify-between px-5 py-4 text-left ${isActive ? 'bg-brand-50' : 'bg-white hover:bg-slate-50'}`}
        >
          <div>
            <p className={`text-sm font-semibold ${isActive ? 'text-brand-700' : 'text-slate-900'}`}>
              {template.label}
            </p>
            <p className="text-xs text-slate-500 mt-0.5">{template.description}</p>
          </div>
          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${isActive ? 'bg-brand-100 text-brand-700' : 'bg-slate-100 text-slate-500'}`}>
            {isActive ? 'Editing' : 'Click to edit'}
          </span>
        </button>

        {isActive && (
          <div className="p-5 border-t border-slate-100 space-y-4 bg-white">

            {/* Variables reference */}
            <div className="rounded-lg bg-slate-50 border border-slate-200 p-3">
              <p className="text-xs font-medium text-slate-600 flex items-center gap-1.5 mb-1">
                <Code size={12} />
                Available variables
                <InfoTooltip
                  content="Click any variable to copy it. Paste it into the subject or body — it will be replaced with real data when the email is sent."
                  position="top"
                />
              </p>
              <VariableChips variables={template.variables} />
            </div>

            {/* Subject */}
            <Input
              label="Subject"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              placeholder="Email subject line…"
            />

            {/* Body */}
            <div className="flex flex-col gap-1">
              <label className="text-sm font-medium text-slate-700">Body (HTML)</label>
              <textarea
                value={body}
                onChange={e => setBody(e.target.value)}
                rows={18}
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 font-mono resize-y focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
                placeholder="Enter HTML email body…"
              />
              <p className="text-xs text-slate-500">
                Write standard HTML. Use the variables above as placeholders — they are replaced at send time.
              </p>
            </div>

            {/* Action row */}
            <div className="flex flex-wrap items-center gap-3 pt-1">
              <Button
                icon={<Save size={13} />}
                disabled={!isDirty}
                loading={isSaving}
                onClick={() => onSave(template.key, subject, body)}
              >
                Save Template
              </Button>

              <Button
                variant="secondary"
                icon={<Eye size={13} />}
                onClick={handlePreview}
              >
                Preview
              </Button>

              <div className="flex items-center gap-2 ml-auto">
                <input
                  type="email"
                  value={testTo}
                  onChange={e => setTestTo(e.target.value)}
                  placeholder="test@example.com"
                  className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 w-52"
                />
                <Button
                  size="sm"
                  variant="secondary"
                  icon={<Send size={12} />}
                  loading={sendingTest}
                  onClick={handleSendTest}
                >
                  Send Test
                </Button>
              </div>
            </div>

          </div>
        )}
      </div>

      {preview && <PreviewModal html={preview} onClose={() => setPreview(null)} />}
    </>
  );
}

// ── Page ───────────────────────────────────────────────────────────────────────

export function EmailTemplatesPage() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [activeKey, setActiveKey] = useState<string | null>(null);

  const { data: templates, isLoading } = useQuery({
    queryKey: ['email-templates'],
    queryFn: emailTemplatesApi.list,
  });

  const saveMutation = useMutation({
    mutationFn: ({ key, subject, body }: { key: string; subject: string; body: string }) =>
      settingsApi.update({
        [`tpl_${key}_subject`]: subject,
        [`tpl_${key}_body`]:    body,
      }),
    onSuccess: (data) => {
      toast(`Template saved.`, 'success');
      qc.invalidateQueries({ queryKey: ['email-templates'] });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  return (
    <PageWrapper
      title="Email Templates"
      subtitle="Customise the emails sent to customers during booking events"
    >
      {/* Info banner */}
      <Card className="mb-6 bg-blue-50 border-blue-200">
        <div className="flex gap-3">
          <div className="shrink-0 mt-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-blue-100 text-blue-600 text-xs font-bold">i</div>
          <div className="text-sm text-blue-800 space-y-1">
            <p className="font-medium">How email templates work</p>
            <ul className="list-disc list-inside text-xs text-blue-700 space-y-0.5">
              <li>Templates are written in HTML with <code className="bg-blue-100 px-1 rounded">{'{{variable}}'}</code> placeholders.</li>
              <li>Placeholders are replaced automatically with real booking/driver data when an email is sent.</li>
              <li>Configure your SMTP server in <strong>Settings → SMTP / Email</strong> before emails will be delivered.</li>
              <li>Use the <em>Send Test</em> button to preview how an email looks in an inbox.</li>
            </ul>
          </div>
        </div>
      </Card>

      {isLoading ? (
        <div className="space-y-3">
          {[1,2,3,4].map(i => (
            <div key={i} className="h-20 rounded-xl bg-white border border-slate-200 animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="space-y-3">
          {(templates ?? []).map(template => (
            <TemplateEditor
              key={template.key}
              template={template}
              isActive={activeKey === template.key}
              onClick={() => setActiveKey(prev => prev === template.key ? null : template.key)}
              onSave={(key, subject, body) => saveMutation.mutate({ key, subject, body })}
              isSaving={saveMutation.isPending}
            />
          ))}
        </div>
      )}
    </PageWrapper>
  );
}
