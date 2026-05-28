import { Bell, Menu } from 'lucide-react';
import { useAuthStore } from '../../store/authStore';
import { getInitials } from '../../utils';
import { useSidebar } from './SidebarContext';

interface HeaderProps {
  title: string;
  subtitle?: string;
}

export function Header({ title, subtitle }: HeaderProps) {
  const { admin } = useAuthStore();
  const { setMobileOpen } = useSidebar();

  return (
    <header className="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 shrink-0 md:px-6 md:py-4">
      <div className="flex items-center gap-3 min-w-0">
        {/* Hamburger — mobile only */}
        <button
          onClick={() => setMobileOpen(true)}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 transition-colors md:hidden"
          aria-label="Open menu"
        >
          <Menu size={18} />
        </button>

        <div className="min-w-0">
          <h1 className="text-base font-semibold text-slate-900 leading-tight md:text-lg truncate">{title}</h1>
          {subtitle && <p className="text-xs text-slate-500 md:text-sm truncate">{subtitle}</p>}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 transition-colors">
          <Bell size={16} />
        </button>
        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-600 text-sm font-semibold text-white">
          {admin ? getInitials(admin.name) : 'A'}
        </div>
      </div>
    </header>
  );
}
