import { Bell } from 'lucide-react';
import { useAuthStore } from '../../store/authStore';
import { getInitials } from '../../utils';

interface HeaderProps {
  title: string;
  subtitle?: string;
}

export function Header({ title, subtitle }: HeaderProps) {
  const { admin } = useAuthStore();

  return (
    <header className="flex items-center justify-between border-b border-slate-200 bg-white px-6 py-4 shrink-0">
      <div>
        <h1 className="text-lg font-semibold text-slate-900">{title}</h1>
        {subtitle && <p className="text-sm text-slate-500">{subtitle}</p>}
      </div>

      <div className="flex items-center gap-3">
        {/* Notification bell (visual only — wired to bookings notifications) */}
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 transition-colors">
          <Bell size={16} />
        </button>

        {/* Avatar */}
        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-600 text-sm font-semibold text-white">
          {admin ? getInitials(admin.name) : 'A'}
        </div>
      </div>
    </header>
  );
}
