import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, BookOpen, Users, Car, Settings,
  BarChart2, MapPin, Map, Layers, LogOut, ChevronLeft,
  ChevronRight, Truck, Mail, X, CreditCard, AlertCircle, MessageCircle, Trash2,
} from 'lucide-react';
import { cn } from '../../utils';
import { useAuthStore } from '../../store/authStore';
import { useSidebar } from './SidebarContext';

const navItems = [
  { to: '/',               icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/bookings',       icon: BookOpen,        label: 'Bookings' },
  { to: '/drivers',        icon: Users,           label: 'Drivers' },
  { to: '/vehicles',       icon: Truck,           label: 'Vehicles' },
  { to: '/vehicle-types',  icon: Car,             label: 'Vehicle Types' },
  { to: '/zones',          icon: MapPin,          label: 'Zones' },
  { to: '/map',            icon: Map,             label: 'Map Settings' },
  { to: '/settings',       icon: Settings,        label: 'Settings' },
  { to: '/live-chat',      icon: MessageCircle,   label: 'Live Chat' },
  { to: '/payments',        icon: CreditCard,      label: 'Payments' },
  { to: '/trip-reports',   icon: AlertCircle,     label: 'Trip Reports' },
  { to: '/account-deletion',icon: Trash2,         label: 'Account Deletion' },
  { to: '/email-templates',icon: Mail,            label: 'Email Templates' },
  { to: '/reports',        icon: BarChart2,       label: 'Reports' },
];

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const { admin, logout } = useAuthStore();
  const navigate = useNavigate();
  const { mobileOpen, setMobileOpen } = useSidebar();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const closeMobile = () => setMobileOpen(false);

  return (
    <>
      {/* Mobile backdrop — tap outside to close */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/50 backdrop-blur-sm md:hidden"
          onClick={closeMobile}
        />
      )}

      <aside
        className={cn(
          // Base
          'flex flex-col bg-slate-900 text-white shrink-0',
          // Mobile: fixed overlay drawer, slides in from left
          'fixed inset-y-0 left-0 z-40 w-72 transition-transform duration-300 ease-in-out',
          mobileOpen ? 'translate-x-0' : '-translate-x-full',
          // Desktop: static sidebar in flow, no slide
          'md:relative md:inset-auto md:z-auto md:translate-x-0 md:transition-all md:duration-300',
          collapsed ? 'md:w-16' : 'md:w-60',
        )}
      >
        {/* Logo + mobile close button */}
        <div
          className={cn(
            'flex items-center gap-3 px-4 py-5 border-b border-slate-700/50',
            collapsed && 'md:justify-center md:px-0',
          )}
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand-500">
            <Layers size={16} className="text-white" />
          </div>
          <div className={cn('flex-1', collapsed && 'md:hidden')}>
            <p className="text-sm font-bold text-white leading-tight">EtcRide</p>
            <p className="text-[10px] text-slate-400">Admin Panel</p>
          </div>
          {/* Close button — mobile only */}
          <button
            onClick={closeMobile}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-800 hover:text-white transition-colors md:hidden"
          >
            <X size={16} />
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto py-4 scrollbar-thin">
          <ul className="space-y-0.5 px-2">
            {navItems.map(({ to, icon: Icon, label }) => (
              <li key={to}>
                <NavLink
                  to={to}
                  end={to === '/'}
                  onClick={closeMobile}
                  className={({ isActive }) =>
                    cn(
                      'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                      isActive
                        ? 'bg-brand-600 text-white'
                        : 'text-slate-400 hover:bg-slate-800 hover:text-white',
                      collapsed && 'md:justify-center md:px-0',
                    )
                  }
                  title={collapsed ? label : undefined}
                >
                  <Icon size={17} className="shrink-0" />
                  <span className={cn(collapsed && 'md:hidden')}>{label}</span>
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        {/* User + logout */}
        <div className={cn('border-t border-slate-700/50 p-3', collapsed && 'md:px-0')}>
          {admin && (
            <NavLink
              to="/profile"
              onClick={closeMobile}
              className={cn(
                'flex items-center gap-2.5 mb-2 rounded-lg bg-slate-800 hover:bg-slate-700 px-3 py-2 transition-colors group',
                collapsed && 'md:justify-center md:px-0',
              )}
              title={collapsed ? admin.name : 'Edit profile'}
            >
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-600 text-white text-xs font-bold">
                {admin.name.split(' ').map((w: string) => w[0]).join('').slice(0, 2).toUpperCase()}
              </div>
              <div className={cn('min-w-0', collapsed && 'md:hidden')}>
                <p className="text-xs font-medium text-white truncate group-hover:text-brand-300 transition-colors">{admin.name}</p>
                <p className="text-[10px] text-slate-400 capitalize">{admin.role}</p>
              </div>
            </NavLink>
          )}
          <button
            onClick={handleLogout}
            className={cn(
              'flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-slate-400 hover:bg-slate-800 hover:text-red-400 transition-colors',
              collapsed && 'md:justify-center md:px-0',
            )}
            title={collapsed ? 'Logout' : undefined}
          >
            <LogOut size={16} />
            <span className={cn(collapsed && 'md:hidden')}>Logout</span>
          </button>
        </div>

        {/* Desktop collapse toggle */}
        <button
          onClick={() => setCollapsed(c => !c)}
          className="absolute -right-3 top-7 z-10 hidden md:flex h-6 w-6 items-center justify-center rounded-full border border-slate-600 bg-slate-800 text-slate-300 hover:bg-slate-700 transition-colors"
        >
          {collapsed ? <ChevronRight size={12} /> : <ChevronLeft size={12} />}
        </button>
      </aside>
    </>
  );
}
