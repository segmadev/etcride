import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { User, Lock, Save, Eye, EyeOff, ShieldCheck } from 'lucide-react';
import { Header } from '../../components/layout/Header';
import { useToast } from '../../components/ui/Toast';
import { useAuthStore } from '../../store/authStore';
import { profileApi } from '../../api/profile';
import { getApiErrorMessage } from '../../api';

// ── Shared UI helpers ─────────────────────────────────────────────────────────
function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
      {children}
    </div>
  );
}
function CardHeader({ icon: Icon, title, subtitle }: { icon: React.ElementType; title: string; subtitle: string }) {
  return (
    <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-100">
      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
        <Icon size={18} />
      </div>
      <div>
        <p className="text-sm font-semibold text-slate-900">{title}</p>
        <p className="text-xs text-slate-500">{subtitle}</p>
      </div>
    </div>
  );
}
function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-xs font-medium text-slate-600 mb-1.5">{label}</label>
      {children}
    </div>
  );
}
function Input({ ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className="w-full rounded-lg border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 disabled:bg-slate-50 disabled:text-slate-400"
    />
  );
}

// ── Avatar ────────────────────────────────────────────────────────────────────
function Avatar({ name }: { name: string }) {
  const initials = name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  return (
    <div className="flex h-20 w-20 items-center justify-center rounded-full bg-brand-600 text-white text-2xl font-bold shadow-lg">
      {initials}
    </div>
  );
}

// ── Profile info section ──────────────────────────────────────────────────────
function ProfileInfo() {
  const { admin, login } = useAuthStore();
  const { toast } = useToast();
  const qc = useQueryClient();

  const [name,  setName]  = useState(admin?.name  ?? '');
  const [email, setEmail] = useState(admin?.email ?? '');

  const { mutate, isPending } = useMutation({
    mutationFn: () => profileApi.update({ name: name.trim(), email: email.trim() }),
    onSuccess: (updated) => {
      // Sync the auth store so sidebar/header reflects the new name instantly
      const token = localStorage.getItem('etcride_admin_token') ?? '';
      login(token, updated);
      qc.invalidateQueries({ queryKey: ['admin-profile'] });
      toast('Profile updated.', 'success');
    },
    onError: (err: unknown) => toast(getApiErrorMessage(err), 'error'),
  });

  const dirty = name.trim() !== admin?.name || email.trim() !== admin?.email;

  return (
    <Card>
      <CardHeader icon={User} title="Profile Information" subtitle="Update your name and email address" />
      <div className="p-6">
        {/* Avatar + role badge */}
        <div className="flex items-center gap-4 mb-6">
          <Avatar name={name || 'A'} />
          <div>
            <p className="text-base font-semibold text-slate-900">{admin?.name}</p>
            <span className="inline-flex items-center gap-1 mt-1 rounded-full bg-brand-50 px-2.5 py-0.5 text-xs font-medium text-brand-700 capitalize">
              <ShieldCheck size={11} />
              {admin?.role}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Full name">
            <Input
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Your full name"
            />
          </Field>
          <Field label="Email address">
            <Input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="you@example.com"
            />
          </Field>
          <Field label="Role">
            <Input value={admin?.role ?? ''} disabled />
          </Field>
        </div>

        <div className="mt-5 flex justify-end">
          <button
            type="button"
            onClick={() => mutate()}
            disabled={isPending || !dirty}
            className="flex items-center gap-2 rounded-xl bg-brand-600 hover:bg-brand-500 disabled:opacity-50 text-white text-sm font-semibold px-5 py-2.5 transition-colors"
          >
            <Save size={14} />
            {isPending ? 'Saving…' : 'Save Changes'}
          </button>
        </div>
      </div>
    </Card>
  );
}

// ── Change password section ───────────────────────────────────────────────────
function ChangePassword() {
  const { toast } = useToast();
  const [current,  setCurrent]  = useState('');
  const [next,     setNext]     = useState('');
  const [confirm,  setConfirm]  = useState('');
  const [showCur,  setShowCur]  = useState(false);
  const [showNew,  setShowNew]  = useState(false);

  const { mutate, isPending } = useMutation({
    mutationFn: () => profileApi.changePassword({
      current_password: current,
      new_password:     next,
    }),
    onSuccess: () => {
      toast('Password changed successfully.', 'success');
      setCurrent(''); setNext(''); setConfirm('');
    },
    onError: (err: unknown) => toast(getApiErrorMessage(err), 'error'),
  });

  const mismatch = next !== '' && confirm !== '' && next !== confirm;
  const tooShort = next !== '' && next.length < 6;
  const canSubmit = current && next && confirm && next === confirm && next.length >= 6;

  return (
    <Card>
      <CardHeader icon={Lock} title="Change Password" subtitle="Use a strong password you don't use elsewhere" />
      <div className="p-6 space-y-4">
        <Field label="Current password">
          <div className="relative">
            <Input
              type={showCur ? 'text' : 'password'}
              value={current}
              onChange={e => setCurrent(e.target.value)}
              placeholder="Enter current password"
            />
            <button type="button" onClick={() => setShowCur(s => !s)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
              {showCur ? <EyeOff size={14} /> : <Eye size={14} />}
            </button>
          </div>
        </Field>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="New password">
            <div className="relative">
              <Input
                type={showNew ? 'text' : 'password'}
                value={next}
                onChange={e => setNext(e.target.value)}
                placeholder="At least 6 characters"
              />
              <button type="button" onClick={() => setShowNew(s => !s)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                {showNew ? <EyeOff size={14} /> : <Eye size={14} />}
              </button>
            </div>
            {tooShort && <p className="text-xs text-red-500 mt-1">Minimum 6 characters</p>}
          </Field>

          <Field label="Confirm new password">
            <Input
              type="password"
              value={confirm}
              onChange={e => setConfirm(e.target.value)}
              placeholder="Repeat new password"
            />
            {mismatch && <p className="text-xs text-red-500 mt-1">Passwords don't match</p>}
          </Field>
        </div>

        {/* Strength hint */}
        {next.length >= 6 && (
          <div className="rounded-xl bg-slate-50 border border-slate-200 px-4 py-3 text-xs text-slate-600 space-y-1">
            <p className="font-medium text-slate-700">Password tips</p>
            <ul className="list-disc list-inside space-y-0.5 text-slate-500">
              <li className={next.length >= 8 ? 'text-green-600' : ''}>At least 8 characters</li>
              <li className={/[A-Z]/.test(next) ? 'text-green-600' : ''}>One uppercase letter</li>
              <li className={/\d/.test(next) ? 'text-green-600' : ''}>One number</li>
            </ul>
          </div>
        )}

        <div className="flex justify-end pt-1">
          <button
            type="button"
            onClick={() => mutate()}
            disabled={isPending || !canSubmit}
            className="flex items-center gap-2 rounded-xl bg-brand-600 hover:bg-brand-500 disabled:opacity-50 text-white text-sm font-semibold px-5 py-2.5 transition-colors"
          >
            <Lock size={14} />
            {isPending ? 'Changing…' : 'Change Password'}
          </button>
        </div>
      </div>
    </Card>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────
export function ProfilePage() {
  return (
    <div className="flex flex-col h-full overflow-hidden">
      <Header title="My Profile" subtitle="Manage your account information and password" />
      <div className="flex-1 overflow-y-auto p-6">
        <div className="max-w-2xl mx-auto space-y-6">
          <ProfileInfo />
          <ChangePassword />
        </div>
      </div>
    </div>
  );
}
