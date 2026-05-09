import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, BookOpen, Users, Car, Settings,
  BarChart2, MapPin, Map, Layers, LogOut, ChevronLeft,
  ChevronRight, Truck, Mail,
} from 'lucide-react';
import { cn } from '../../utils';
import { useAuthStore } from '../../store/authStore';

const navItems = [
  { to: '/',               icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/bookings',       icon: BookOpen,        label: 'Bookings' },
  { to: '/drivers',        icon: Users,           label: 'Drivers' },
  { to: '/vehicles',       icon: Truck,           label: 'Vehicles' },
  { to: '/vehicle-types',  icon: Car,             label: 'Vehicle Types' },
  { to: '/zones',          icon: MapPin,          label: 'Zones' },
  { to: '/map',              icon: Map,      label: 'Map Settings' },
  { to: '/settings',         icon: Settings, label: 'Settings' },
  { to: '/email-templates',  icon: Mail,     label: 'Email Templates' },
  { to: '/reports',          icon: BarChart2, label: 'Reports' },
];

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const { admin, logout } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <aside
      className={cn(
        'relative flex flex-col bg-slate-900 text-white transition-all duration-300 shrink-0',
        collapsed ? 'w-16' : 'w-60',
      )}
    >
      {/* Logo */}
      <div className={cn('flex items-center gap-3 px-4 py-5 border-b border-slate-700/50', collapsed && 'justify-center px-0')}>
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand-500">
          <Layers size={16} className="text-white" />
        </div>
        {!collapsed && (
          <div>
            <p className="text-sm font-bold text-white leading-tight">EtcRide</p>
            <p className="text-[10px] text-slate-400">Admin Panel</p>
          </div>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-4 scrollbar-thin">
        <ul className="space-y-0.5 px-2">
          {navItems.map(({ to, icon: Icon, label }) => (
            <li key={to}>
              <NavLink
                to={to}
                end={to === '/'}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors group',
                    isActive
                      ? 'bg-brand-600 text-white'
                      : 'text-slate-400 hover:bg-slate-800 hover:text-white',
                    collapsed && 'justify-center px-0',
                  )
                }
                title={collapsed ? label : undefined}
              >
                <Icon size={17} className="shrink-0" />
                {!collapsed && <span>{label}</span>}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* User + logout */}
      <div className={cn('border-t border-slate-700/50 p-3', collapsed && 'px-0')}>
        {!collapsed && admin && (
          <NavLink
            to="/profile"
            className="flex items-center gap-2.5 mb-2 rounded-lg bg-slate-800 hover:bg-slate-700 px-3 py-2 transition-colors group"
            title="Edit profile"
          >
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-600 text-white text-xs font-bold">
              {admin.name.split(' ').map((w: string) => w[0]).join('').slice(0, 2).toUpperCase()}
            </div>
            <div className="min-w-0">
              <p className="text-xs font-medium text-white truncate group-hover:text-brand-300 transition-colors">{admin.name}</p>
              <p className="text-[10px] text-slate-400 capitalize">{admin.role}</p>
            </div>
          </NavLink>
        )}
        <button
          onClick={handleLogout}
          className={cn(
            'flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-slate-400 hover:bg-slate-800 hover:text-red-400 transition-colors',
            collapsed && 'justify-center px-0',
          )}
          title={collapsed ? 'Logout' : undefined}
        >
          <LogOut size={16} />
          {!collapsed && <span>Logout</span>}
        </button>
      </div>

      {/* Collapse toggle */}
      <button
        onClick={() => setCollapsed(c => !c)}
        className="absolute -right-3 top-7 z-10 flex h-6 w-6 items-center justify-center rounded-full border border-slate-600 bg-slate-800 text-slate-300 hover:bg-slate-700 transition-colors"
      >
        {collapsed ? <ChevronRight size={12} /> : <ChevronLeft size={12} />}
      </button>
    </aside>
  );
}
