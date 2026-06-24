import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ToastProvider } from './components/ui/Toast';
import { ProtectedRoute } from './components/layout/ProtectedRoute';

// ── Lazy page bundles ─────────────────────────────────────────────────────────
// Each page is a separate Vite chunk — downloaded only on first visit.
// The heavy @react-google-maps/api bundle is isolated to the /map chunk.
const LoginPage        = lazy(() => import('./pages/auth/LoginPage').then(m => ({ default: m.LoginPage })));
const DashboardPage    = lazy(() => import('./pages/dashboard/DashboardPage').then(m => ({ default: m.DashboardPage })));
const BookingsPage     = lazy(() => import('./pages/bookings/BookingsPage').then(m => ({ default: m.BookingsPage })));
const DriversPage      = lazy(() => import('./pages/drivers/DriversPage').then(m => ({ default: m.DriversPage })));
const VehiclesPage     = lazy(() => import('./pages/vehicles/VehiclesPage').then(m => ({ default: m.VehiclesPage })));
const VehicleTypesPage = lazy(() => import('./pages/vehicleTypes/VehicleTypesPage').then(m => ({ default: m.VehicleTypesPage })));
const ZonesPage        = lazy(() => import('./pages/zones/ZonesPage').then(m => ({ default: m.ZonesPage })));
const SettingsPage     = lazy(() => import('./pages/settings/SettingsPage').then(m => ({ default: m.SettingsPage })));
const ReportsPage      = lazy(() => import('./pages/reports/ReportsPage').then(m => ({ default: m.ReportsPage })));
const TripReportsPage  = lazy(() => import('./pages/trip-reports/TripReportsPage'));
const MapSettingsPage  = lazy(() => import('./pages/map/MapSettingsPage').then(m => ({ default: m.MapSettingsPage })));
const ProfilePage         = lazy(() => import('./pages/profile/ProfilePage').then(m => ({ default: m.ProfilePage })));
const EmailTemplatesPage  = lazy(() => import('./pages/emailTemplates/EmailTemplatesPage').then(m => ({ default: m.EmailTemplatesPage })));
const PaymentsPage        = lazy(() => import('./pages/payments/PaymentsPage'));
const LiveChatPage        = lazy(() => import('./pages/settings/LiveChatPage').then(m => ({ default: m.default })));

// ── React Query client ────────────────────────────────────────────────────────
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry:                1,
      staleTime:       60_000,   // 1 min before background refetch
      gcTime:      5 * 60_000,   // keep unused cache for 5 min
      refetchOnWindowFocus: false,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <BrowserRouter future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
          <Routes>

            {/* Public — LoginPage has its own Suspense (no AppShell around it) */}
            <Route
              path="/login"
              element={
                <Suspense fallback={
                  <div className="flex h-screen items-center justify-center bg-slate-50">
                    <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-brand-600" />
                  </div>
                }>
                  <LoginPage />
                </Suspense>
              }
            />

            {/* Protected — Suspense lives inside AppShell so the sidebar
                stays mounted while page chunks are downloading */}
            <Route element={<ProtectedRoute />}>
              <Route path="/"              element={<DashboardPage />} />
              <Route path="/bookings"      element={<BookingsPage />} />
              <Route path="/drivers"       element={<DriversPage />} />
              <Route path="/vehicles"      element={<VehiclesPage />} />
              <Route path="/vehicle-types" element={<VehicleTypesPage />} />
              <Route path="/zones"         element={<ZonesPage />} />
              <Route path="/settings"      element={<SettingsPage />} />
              <Route path="/reports"       element={<ReportsPage />} />
              <Route path="/trip-reports"  element={<TripReportsPage />} />
              <Route path="/map"              element={<MapSettingsPage />} />
              <Route path="/email-templates" element={<EmailTemplatesPage />} />
              <Route path="/profile"         element={<ProfilePage />} />
              <Route path="/payments"        element={<PaymentsPage />} />
              <Route path="/live-chat"       element={<LiveChatPage />} />
            </Route>

            {/* Fallback */}
            <Route path="*" element={<Navigate to="/" replace />} />

          </Routes>
        </BrowserRouter>
      </ToastProvider>
    </QueryClientProvider>
  );
}
