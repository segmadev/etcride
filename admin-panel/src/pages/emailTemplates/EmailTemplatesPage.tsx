import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Send, Eye } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { useToast } from '../../components/ui/Toast';
import { RichTextEditor } from '../../components/ui/RichTextEditor';
import { emailTemplatesApi, type EmailTemplate } from '../../api/emailTemplates';
import { settingsApi, getApiErrorMessage } from '../../api';

// ── Brand assets ───────────────────────────────────────────────────────────────

const LOGO_LIGHT = 'https://etcride.com/images/logo-light.svg';
const EMAIL_HEADER_BG = '#0f172a';

// ── Sample variable values for preview ────────────────────────────────────────

const SAMPLE_VARS: Record<string, string> = {
  '{{app_name}}':            'EtcRide',
  '{{customer_name}}':       'John Doe',
  '{{driver_name}}':         'Ahmed Musa',
  '{{booking_code}}':        'BK-DEMO123',
  '{{pickup_address}}':      '12 Sample Street, Ilorin',
  '{{destination_address}}': '45 Demo Avenue, Ilorin',
  '{{estimated_fare}}':      '₦1,500',
  '{{driver_phone}}':        '+234 801 234 5678',
  '{{vehicle_type}}':        'Economy',
  '{{cancellation_reason}}': 'No driver available at this time.',
  '{{login_time}}':          new Date().toLocaleString('en-GB', { weekday:'short', day:'2-digit', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' }),
  '{{device}}':              'Chrome on Windows',
  '{{ip}}':                  '102.88.xx.xx',
  '{{code}}':                '482 916',
  '{{support_email}}':       'support@etcride.com',
};

function applyVars(text: string): string {
  return Object.entries(SAMPLE_VARS).reduce((t, [k, v]) => t.replaceAll(k, v), text);
}

// ── Layout wrapper (mirrors Mymailer::layout() in PHP) ─────────────────────────

function wrapWithLayout(innerHtml: string, title: string, _accent: string): string {
  const year    = new Date().getFullYear();
  const appName = SAMPLE_VARS['{{app_name}}'];
  const support = SAMPLE_VARS['{{support_email}}'];

  const trimmed = innerHtml.trimStart();
  if (/^<!DOCTYPE/i.test(trimmed) || /^<html/i.test(trimmed)) return innerHtml;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#f1f5f9;padding:48px 16px;">
  <tr><td align="center">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;">
      <tr>
        <td style="padding:0 0 20px;text-align:center;">
          <img src="${LOGO_LIGHT}" alt="${appName}" height="40" style="display:inline-block;max-height:40px;width:auto;">
        </td>
      </tr>
      <tr>
        <td style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.06),0 4px 16px rgba(0,0,0,0.06);">
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="background:${EMAIL_HEADER_BG};padding:28px 40px 24px;">
                <p style="margin:0 0 10px;color:rgba(255,255,255,0.5);font-size:11px;font-weight:600;letter-spacing:1.5px;text-transform:uppercase;">${appName}</p>
                <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;line-height:1.25;letter-spacing:-0.5px;">${title}</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:36px 40px 32px;color:#374151;font-size:15px;line-height:1.7;">
                ${innerHtml}
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr>
        <td style="padding:28px 0 0;text-align:center;">
          <p style="margin:0 0 4px;color:#94a3b8;font-size:12px;"><a href="mailto:${support}" style="color:#64748b;text-decoration:none;">${support}</a></p>
          <p style="margin:0;color:#cbd5e1;font-size:11px;">&copy; ${year} ${appName}. All rights reserved.</p>
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

// ── Preview modal ──────────────────────────────────────────────────────────────

function PreviewModal({ html, onClose }: { html: string; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4" onClick={onClose}>
      <div
        className="w-full max-w-3xl rounded-2xl bg-white shadow-2xl flex flex-col"
        style={{ height: 'min(90vh, 860px)' }}
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200 shrink-0">
          <div>
            <span className="text-sm font-semibold text-slate-800">Email Preview</span>
            <span className="ml-2 text-xs text-slate-400">Exactly as recipients will see it</span>
          </div>
          <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 text-xl leading-none transition-colors">&times;</button>
        </div>
        <iframe srcDoc={html} title="Email Preview" className="w-full flex-1 rounded-b-2xl" style={{ border: 'none' }} />
      </div>
    </div>
  );
}

// ── Template editor ────────────────────────────────────────────────────────────

function TemplateEditor({
  template, isActive, onClick, onSave, isSaving,
}: {
  template: EmailTemplate;
  isActive: boolean;
  onClick: () => void;
  onSave: (key: string, subject: string, body: string) => void;
  isSaving: boolean;
}) {
  const [subject, setSubject] = useState(template.subject);
  const [body,    setBody]    = useState(template.body);
  const [preview, setPreview] = useState<string | null>(null);
  const [testTo,  setTestTo]  = useState('');
  const [sending, setSending] = useState(false);
  const { toast } = useToast();

  // Sync after save+refetch
  useEffect(() => { setSubject(template.subject); }, [template.subject]);
  useEffect(() => { setBody(template.body); },       [template.body]);

  const isDirty = subject !== template.subject || body !== template.body;

  const handlePreview = () => {
    const rendered = applyVars(body);
    const title    = applyVars(subject) || template.label;
    setPreview(wrapWithLayout(rendered, title, template.accent_color || '#2563eb'));
  };

  const handleSendTest = async () => {
    if (!testTo) { toast('Enter a recipient email first.', 'error'); return; }
    setSending(true);
    try {
      const res = await emailTemplatesApi.test(testTo, template.key);
      toast(res.message, 'success');
    } catch (e: unknown) {
      toast((e as Error).message ?? 'Test failed.', 'error');
    } finally {
      setSending(false);
    }
  };

  return (
    <>
      <div className={`border rounded-xl overflow-hidden transition-shadow ${
        isActive ? 'shadow-md border-brand-200' : 'border-slate-200 cursor-pointer hover:border-slate-300'
      }`}>
        {/* Header row */}
        <button
          type="button"
          onClick={onClick}
          className={`w-full flex items-center justify-between px-5 py-4 text-left ${isActive ? 'bg-brand-50' : 'bg-white hover:bg-slate-50'}`}
        >
          <div className="flex items-center gap-3">
            <span className="shrink-0 w-3 h-3 rounded-full" style={{ background: template.accent_color || '#2563eb' }} />
            <div>
              <p className={`text-sm font-semibold ${isActive ? 'text-brand-700' : 'text-slate-900'}`}>{template.label}</p>
              <p className="text-xs text-slate-500 mt-0.5">{template.description}</p>
            </div>
          </div>
          <span className={`text-xs px-2 py-0.5 rounded-full font-medium shrink-0 ml-4 ${
            isActive ? 'bg-brand-100 text-brand-700' : 'bg-slate-100 text-slate-500'
          }`}>
            {isActive ? 'Editing' : 'Click to edit'}
          </span>
        </button>

        {isActive && (
          <div className="p-5 border-t border-slate-100 space-y-4 bg-white">

            {/* Subject */}
            <Input
              label="Subject"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              placeholder="Email subject line…"
            />

            {/* Rich text body */}
            <RichTextEditor
              label="Body"
              value={body}
              onChange={setBody}
              variables={template.variables}
              minHeight={280}
            />

            <p className="text-xs text-slate-400 -mt-2">
              The company logo, branded header, and footer are added automatically around your content.
              Use the <strong>Insert placeholder</strong> bar to drop in dynamic data like customer names or booking codes.
            </p>

            {/* Actions */}
            <div className="flex flex-wrap items-center gap-3 pt-1">
              <Button
                icon={<Save size={13} />}
                disabled={!isDirty}
                loading={isSaving}
                onClick={() => onSave(template.key, subject, body)}
              >
                Save Template
              </Button>

              <Button variant="secondary" icon={<Eye size={13} />} onClick={handlePreview}>
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
                <Button size="sm" variant="secondary" icon={<Send size={12} />} loading={sending} onClick={handleSendTest}>
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
      settingsApi.update({ [`tpl_${key}_subject`]: subject, [`tpl_${key}_body`]: body }),
    onSuccess: () => {
      toast('Template saved.', 'success');
      qc.invalidateQueries({ queryKey: ['email-templates'] });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  return (
    <PageWrapper title="Email Templates" subtitle="Customise every email sent by EtcRide — no coding required">

      <Card className="mb-6 bg-blue-50 border-blue-200">
        <div className="flex gap-3">
          <div className="shrink-0 mt-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-blue-100 text-blue-600 text-xs font-bold">i</div>
          <div className="text-sm text-blue-800 space-y-1">
            <p className="font-medium">How to customise templates</p>
            <ul className="list-disc list-inside text-xs text-blue-700 space-y-0.5">
              <li>Use the rich text editor — <strong>no HTML knowledge needed</strong>. Bold, italics, colours, lists and links all work.</li>
              <li>Click any <strong>placeholder chip</strong> in the editor bar to insert dynamic data (e.g. customer name, booking code).</li>
              <li>The company logo, branded header bar, and footer are <strong>added automatically</strong> — just write the content.</li>
              <li>Click <strong>Preview</strong> to see the complete email exactly as recipients will see it.</li>
              <li>Use <strong>Send Test</strong> to deliver a real test email to any address.</li>
            </ul>
          </div>
        </div>
      </Card>

      {isLoading ? (
        <div className="space-y-3">
          {[1, 2, 3, 4, 5, 6, 7, 8].map(i => (
            <div key={i} className="h-16 rounded-xl bg-white border border-slate-200 animate-pulse" />
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
