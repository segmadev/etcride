import { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Eye, UserPlus, UserMinus, XCircle, Search, RefreshCw, AlertTriangle,
  MapPin, Car, Phone, User, SlidersHorizontal, ChevronDown,
  Clock, CreditCard, FileText,
} from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { Button } from '../../components/ui/Button';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { bookingsApi, driversApi, getApiErrorMessage } from '../../api';
import { formatCurrency, formatDateTime, cn } from '../../utils';
import type { Booking } from '../../types';

// ── Status helpers ─────────────────────────────────────────────────────────────
const STATUS_OPTIONS = [
  { value: '', label: 'All Statuses' },
  { value: 'pending',         label: 'Pending' },
  { value: 'assigned',        label: 'Assigned' },
  { value: 'accepted',        label: 'Accepted' },
  { value: 'arrived',         label: 'Driver Arrived' },
  { value: 'in_progress',     label: 'In Progress' },
  { value: 'payment_pending', label: 'Payment Pending' },
  { value: 'completed',       label: 'Completed' },
  { value: 'cancelled',       label: 'Cancelled' },
];

const TYPE_OPTIONS = [
  { value: '',         label: 'All Types' },
  { value: 'ride',     label: 'Ride' },
  { value: 'delivery', label: 'Delivery' },
];

const ACTIVE_STATUSES = new Set(['pending', 'assigned', 'accepted', 'arrived', 'in_progress', 'payment_pending']);

// ── Route mini-visual ──────────────────────────────────────────────────────────
function RouteSnippet({ pickup, dropoff, className }: { pickup: string; dropoff: string; className?: string }) {
  return (
    <div className={cn('space-y-1', className)}>
      <div className="flex items-start gap-1.5">
        <span className="mt-0.5 h-2 w-2 shrink-0 rounded-full bg-green-400" />
        <p className="text-xs text-slate-700 leading-snug line-clamp-1">{pickup}</p>
      </div>
      <div className="ml-[3px] h-2.5 border-l border-dashed border-slate-300" />
      <div className="flex items-start gap-1.5">
        <span className="mt-0.5 h-2 w-2 shrink-0 rounded-full bg-red-400" />
        <p className="text-xs text-slate-500 leading-snug line-clamp-1">{dropoff}</p>
      </div>
    </div>
  );
}

// ── Driver chip — inline in rows / cards ───────────────────────────────────────
function DriverChip({ name, phone, onClick }: { name?: string | null; phone?: string | null; onClick?: () => void }) {
  if (!name) {
    return <span className="text-xs text-slate-400 italic">No driver</span>;
  }
  return (
    <button
      onClick={e => { e.stopPropagation(); onClick?.(); }}
      className="flex items-center gap-1.5 group text-left"
    >
      <span className={cn(
        'flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-slate-200 text-[10px] font-bold text-slate-600',
        onClick && 'group-hover:bg-brand-100 group-hover:text-brand-700 transition-colors',
      )}>
        {name.charAt(0).toUpperCase()}
      </span>
      <div>
        <p className={cn('text-xs font-medium text-slate-800 leading-tight', onClick && 'group-hover:text-brand-700 transition-colors')}>{name}</p>
        {phone && <p className="text-[10px] text-slate-400">{phone}</p>}
      </div>
    </button>
  );
}

// ── Customer chip — clickable ──────────────────────────────────────────────────
function CustomerChip({ name, phone, onClick }: { name?: string; phone?: string; onClick: () => void }) {
  return (
    <button onClick={e => { e.stopPropagation(); onClick(); }} className="flex items-center gap-1.5 group text-left">
      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-100 text-[10px] font-bold text-brand-700 group-hover:bg-brand-200 transition-colors">
        {(name ?? '?').charAt(0).toUpperCase()}
      </span>
      <div>
        <p className="text-xs font-semibold text-slate-900 group-hover:text-brand-700 transition-colors leading-tight">{name ?? '—'}</p>
        {phone && <p className="text-[10px] text-slate-400">{phone}</p>}
      </div>
    </button>
  );
}

// ── Customer quick-view modal ──────────────────────────────────────────────────
function CustomerModal({ name, phone, onClose }: { name: string; phone: string; onClose: () => void }) {
  const { data, isLoading } = useQuery({
    queryKey: ['customer-bookings', phone],
    queryFn: () => bookingsApi.list({ search: phone, page: 1 }),
    enabled: !!phone,
  });

  const bookings = data?.data ?? [];
  const completed = bookings.filter(b => b.status === 'completed').length;

  return (
    <Modal open onClose={onClose} title="Customer" size="md">
      {/* Customer header */}
      <div className="flex items-center gap-4 mb-5 pb-4 border-b border-slate-100">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-brand-100 text-xl font-bold text-brand-700">
          {name.charAt(0).toUpperCase()}
        </div>
        <div>
          <p className="text-base font-semibold text-slate-900">{name}</p>
          <a href={`tel:${phone}`} className="flex items-center gap-1.5 text-sm text-brand-600 hover:underline mt-0.5">
            <Phone size={12} /> {phone}
          </a>
        </div>
        {!isLoading && (
          <div className="ml-auto text-right shrink-0">
            <p className="text-xl font-bold text-slate-900">{data?.total ?? 0}</p>
            <p className="text-xs text-slate-400">bookings</p>
            {completed > 0 && <p className="text-[10px] text-green-600 font-medium">{completed} completed</p>}
          </div>
        )}
      </div>

      {/* Recent bookings */}
      <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400 mb-3">Recent Bookings</p>
      {isLoading ? (
        <div className="flex justify-center py-8 text-sm text-slate-400">Loading…</div>
      ) : bookings.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-8 gap-2 text-slate-400">
          <FileText size={24} className="opacity-30" />
          <p className="text-sm">No bookings found for this customer.</p>
        </div>
      ) : (
        <div className="space-y-2 max-h-72 overflow-y-auto pr-1 scrollbar-thin">
          {bookings.slice(0, 8).map(b => (
            <div key={b.id} className="flex items-start gap-3 rounded-xl bg-slate-50 p-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <Badge status={b.status} dot />
                  <span className="text-[10px] text-slate-400">{formatDateTime(b.created_at)}</span>
                </div>
                <RouteSnippet pickup={b.pickup_address} dropoff={b.dropoff_address} />
              </div>
              <div className="shrink-0 text-right">
                <p className="text-xs font-bold text-slate-800">{formatCurrency(b.final_fare ?? b.estimated_fare)}</p>
                {b.driver_name && <p className="text-[10px] text-slate-400 mt-0.5">{b.driver_name}</p>}
              </div>
            </div>
          ))}
        </div>
      )}
    </Modal>
  );
}

// ── Booking detail modal — fetches full data ───────────────────────────────────
function BookingDetailModal({ bookingId, onClose, onAssign, onDeassign, onCancel, canAssign, canDeassign, canCancel }: {
  bookingId: string;
  onClose: () => void;
  onAssign: () => void;
  onDeassign: () => void;
  onCancel: () => void;
  canAssign: boolean;
  canDeassign: boolean;
  canCancel: boolean;
}) {
  const { data: b, isLoading } = useQuery({
    queryKey: ['booking-detail', bookingId],
    queryFn: () => bookingsApi.show(bookingId),
  });

  return (
    <Modal
      open
      onClose={onClose}
      title="Booking Details"
      size="lg"
      footer={
        b && (
          <div className="flex flex-wrap gap-2 w-full">
            {canAssign && (
              <Button onClick={onAssign} icon={<UserPlus size={14} />}>
                {b.status === 'assigned' ? 'Reassign Driver' : 'Assign Driver'}
              </Button>
            )}
            {canDeassign && (
              <button
                onClick={onDeassign}
                className="flex items-center gap-1.5 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm font-medium text-amber-700 hover:bg-amber-100 transition-colors"
              >
                <UserMinus size={14} /> Unassign Driver
              </button>
            )}
            {canCancel && (
              <button
                onClick={onCancel}
                className="flex items-center gap-1.5 rounded-xl border border-red-200 px-3 py-2 text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
              >
                <XCircle size={14} /> Cancel Booking
              </button>
            )}
          </div>
        )
      }
    >
      {isLoading || !b ? (
        <div className="flex justify-center py-12 text-sm text-slate-400">Loading…</div>
      ) : (
        <div className="space-y-5">
          {/* Status + meta row */}
          <div className="flex flex-wrap items-center gap-2">
            <Badge status={b.status} dot />
            <Badge status={b.booking_type}>{b.booking_type}</Badge>
            {b.payment_status && <Badge status={b.payment_status}>{b.payment_status}</Badge>}
            <span className="text-xs text-slate-400 ml-auto">{formatDateTime(b.created_at)}</span>
          </div>

          {/* Customer + Driver side by side */}
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {/* Customer */}
            <div className="rounded-xl bg-slate-50 p-3.5">
              <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400 mb-2">Customer</p>
              <div className="flex items-center gap-2.5">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-100 text-sm font-bold text-brand-700">
                  {(b.customer?.name ?? b.customer_name ?? '?').charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="text-sm font-semibold text-slate-900">{b.customer?.name ?? b.customer_name ?? '—'}</p>
                  <p className="text-xs text-slate-500">{b.customer?.phone ?? b.customer_phone}</p>
                  {b.customer?.email && <p className="text-xs text-slate-400">{b.customer.email}</p>}
                </div>
              </div>
            </div>

            {/* Driver */}
            <div className="rounded-xl bg-slate-50 p-3.5">
              <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400 mb-2">Driver</p>
              {(b.driver ?? b.driver_name) ? (
                <div className="flex items-center gap-2.5">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-green-100 text-sm font-bold text-green-700">
                    {(b.driver?.name ?? b.driver_name ?? '?').charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-slate-900">{b.driver?.name ?? b.driver_name}</p>
                    <p className="text-xs text-slate-500">{b.driver?.phone ?? b.driver_phone ?? '—'}</p>
                    {b.driver?.last_seen && <p className="text-[10px] text-slate-400">Last seen {formatDateTime(b.driver.last_seen)}</p>}
                  </div>
                </div>
              ) : (
                <p className="text-sm text-slate-400 italic">No driver assigned</p>
              )}
            </div>
          </div>

          {/* Route */}
          <div className="rounded-xl bg-slate-50 p-3.5 space-y-2">
            <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400 mb-1">Route</p>
            <div className="flex items-start gap-2">
              <MapPin size={13} className="mt-0.5 shrink-0 text-green-500" />
              <p className="text-sm text-slate-800">{b.pickup_address}</p>
            </div>
            {(b.stops ?? []).map(s => (
              <div key={s.id} className="flex items-start gap-2 ml-1">
                <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-amber-400" />
                <p className="text-xs text-slate-600">{s.address}</p>
                {s.reached_at && <span className="ml-auto text-[10px] text-green-600 shrink-0">✓ reached</span>}
              </div>
            ))}
            <div className="flex items-start gap-2">
              <MapPin size={13} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-sm text-slate-800">{b.dropoff_address}</p>
            </div>
          </div>

          {/* Fare + Vehicle */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { label: 'Est. Fare',  value: formatCurrency(b.estimated_fare) },
              { label: 'Final Fare', value: b.final_fare ? formatCurrency(b.final_fare) : '—' },
              { label: 'Distance',   value: b.distance_km ? `${b.distance_km} km` : '—' },
              { label: 'Vehicle',    value: b.vehicle_type ?? '—' },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-xl bg-slate-50 p-3">
                <p className="text-[10px] text-slate-400 mb-0.5">{label}</p>
                <p className="text-sm font-semibold text-slate-800">{value}</p>
              </div>
            ))}
          </div>

          {/* Payment */}
          {b.payment && (
            <div className="rounded-xl border border-slate-200 p-3.5">
              <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400 mb-2 flex items-center gap-1"><CreditCard size={10} /> Payment</p>
              <div className="flex items-center gap-4 flex-wrap">
                <span className="text-sm font-semibold text-slate-800 capitalize">{b.payment.provider}</span>
                <span className="text-sm text-slate-600">{formatCurrency(b.payment.amount)}</span>
                <Badge status={b.payment.status}>{b.payment.status}</Badge>
                <span className="text-xs text-slate-400 ml-auto">{formatDateTime(b.payment.created_at)}</span>
              </div>
            </div>
          )}

          {/* Status history timeline */}
          {(b.history ?? b.status_history ?? []).length > 0 && (
            <div>
              <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400 mb-3 flex items-center gap-1"><Clock size={10} /> Status History</p>
              <div className="relative space-y-0">
                {(b.history ?? b.status_history ?? []).map((h, i, arr) => (
                  <div key={i} className="flex items-start gap-3 relative">
                    <div className="flex flex-col items-center shrink-0">
                      <span className={cn(
                        'h-2.5 w-2.5 rounded-full mt-0.5 shrink-0',
                        h.status === 'completed'   ? 'bg-green-500' :
                        h.status === 'cancelled'   ? 'bg-red-500' :
                        h.status === 'in_progress' ? 'bg-blue-500' : 'bg-slate-300',
                      )} />
                      {i < arr.length - 1 && <span className="w-px flex-1 bg-slate-200 min-h-[20px] my-0.5" />}
                    </div>
                    <div className="pb-3 flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-medium text-slate-700 capitalize">{(h.status ?? '').replace(/_/g, ' ')}</span>
                        <span className="text-[10px] text-slate-400">{formatDateTime(h.changed_at)}</span>
                      </div>
                      {h.note && <p className="text-[11px] text-slate-500 mt-0.5">{h.note}</p>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {b.note && (
            <div className="rounded-xl border border-amber-200 bg-amber-50 p-3">
              <p className="text-xs font-medium text-amber-700 mb-0.5">Customer Note</p>
              <p className="text-sm text-amber-800">{b.note}</p>
            </div>
          )}

          {b.trip_report && (
            <div className="rounded-xl border border-red-200 bg-red-50 p-3.5">
              <p className="text-xs font-semibold uppercase tracking-wide text-red-600 mb-2 flex items-center gap-1">
                <AlertTriangle size={12} /> Trip Report
              </p>
              <div className="space-y-2 text-sm">
                <div>
                  <p className="text-[10px] text-red-600 font-semibold uppercase tracking-wide">Reason</p>
                  <p className="text-red-900">{b.trip_report.report_reason}</p>
                </div>
                {b.trip_report.description && (
                  <div>
                    <p className="text-[10px] text-red-600 font-semibold uppercase tracking-wide">Description</p>
                    <p className="text-red-800 text-xs">{b.trip_report.description}</p>
                  </div>
                )}
                <div className="flex items-center gap-2 pt-2 border-t border-red-200">
                  <Badge status={b.trip_report.report_status}>{b.trip_report.report_status}</Badge>
                  <span className="text-[10px] text-red-600 ml-auto">{formatDateTime(b.trip_report.created_at)}</span>
                </div>
                {b.trip_report.admin_notes && (
                  <div className="pt-2 mt-2 border-t border-red-200">
                    <p className="text-[10px] text-red-600 font-semibold uppercase tracking-wide mb-1">Admin Notes</p>
                    <p className="text-red-800 text-xs">{b.trip_report.admin_notes}</p>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </Modal>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export function BookingsPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  // Filters
  const [page, setPage]   = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [type, setType]     = useState('');
  const [from, setFrom]     = useState('');
  const [to, setTo]         = useState('');

  // Modal state
  const [detailId, setDetailId]               = useState<string | null>(null);
  const [selected, setSelected]               = useState<Booking | null>(null);
  const [assignOpen, setAssignOpen]           = useState(false);
  const [cancelOpen, setCancelOpen]           = useState(false);
  const [deassignOpen, setDeassignOpen]       = useState(false);
  const [customerModal, setCustomerModal]     = useState<{ name: string; phone: string } | null>(null);

  // Assign form state
  const [assignId, setAssignId]               = useState('');
  const [driverSearch, setDriverSearch]       = useState('');
  const [onlineOnly, setOnlineOnly]           = useState(false);
  const [mismatchConfirmed, setMismatchConfirmed] = useState(false);

  const isActiveView = !status || ACTIVE_STATUSES.has(status);

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ['bookings', page, search, status, type, from, to],
    queryFn: () => bookingsApi.list({ page, search, status, type, from, to }),
    refetchInterval: isActiveView ? 12_000 : false,
  });

  const { data: driverList, isLoading: driversLoading } = useQuery({
    queryKey: ['drivers-assign', driverSearch, onlineOnly],
    queryFn: () => driversApi.list({ status: 'active', search: driverSearch || undefined, is_online: onlineOnly ? 1 : undefined, per_page: 100, sort: 'assign' }),
    enabled: assignOpen,
  });

  const { data: suggestions } = useQuery({
    queryKey: ['suggest-drivers', selected?.id],
    queryFn: () => bookingsApi.suggestDrivers(selected!.id),
    enabled: assignOpen && !!selected?.id,
    staleTime: 30_000,
  });

  const selectedDriver = useMemo(() => (driverList?.data ?? []).find(d => d.id === assignId) ?? null, [driverList, assignId]);

  const hasVehicleMismatch = useMemo(() => {
    if (!selectedDriver || !selected) return false;
    const bvt = selected.vehicle_type_id;
    const dvt = selectedDriver.driver_vehicle_type_id;
    if (!bvt || !dvt) return false;
    return bvt !== dvt;
  }, [selectedDriver, selected]);

  const assignMutation = useMutation({
    mutationFn: () => bookingsApi.assign(selected!.id, assignId),
    onSuccess: () => {
      toast('Driver assigned successfully.', 'success');
      qc.invalidateQueries({ queryKey: ['bookings'] });
      closeAssign();
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const cancelMutation = useMutation({
    mutationFn: () => bookingsApi.cancel(selected!.id),
    onSuccess: () => {
      toast('Booking cancelled.', 'success');
      qc.invalidateQueries({ queryKey: ['bookings'] });
      setCancelOpen(false);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const deassignMutation = useMutation({
    mutationFn: () => bookingsApi.deassign(selected!.id),
    onSuccess: () => {
      toast('Driver unassigned. Booking is now pending.', 'success');
      qc.invalidateQueries({ queryKey: ['bookings'] });
      qc.invalidateQueries({ queryKey: ['booking-detail', selected!.id] });
      setDeassignOpen(false);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const canAssign   = (b: Booking) => ['pending', 'assigned'].includes(b.status);
  const canCancel   = (b: Booking) => !['completed', 'cancelled'].includes(b.status);
  const canDeassign = (b: Booking) => b.status === 'assigned' && !!b.driver_id;

  const openDeassign = (b: Booking) => { setSelected(b); setDeassignOpen(true); setDetailId(null); };

  const openAssign = (b: Booking) => {
    setSelected(b); setAssignId(''); setDriverSearch('');
    setOnlineOnly(false); setMismatchConfirmed(false);
    setAssignOpen(true); setDetailId(null);
  };
  const openCancel = (b: Booking) => {
    setSelected(b); setCancelOpen(true); setDetailId(null);
  };
  const closeAssign = () => {
    setAssignOpen(false); setAssignId(''); setDriverSearch(''); setMismatchConfirmed(false);
  };

  const allBookings  = data?.data ?? [];
  const pendingCount = allBookings.filter(b => b.status === 'pending').length;

  // ── Desktop table columns ───────────────────────────────────────────────────
  const columns = useMemo(() => [
    {
      key: 'booking',
      header: 'Booking',
      render: (b: Booking) => (
        <div>
          <div className="flex items-center gap-1.5 mb-1">
            <Badge status={b.booking_type}>{b.booking_type}</Badge>
            {b.booking_code && <span className="font-mono text-[10px] text-slate-400">{b.booking_code}</span>}
          </div>
          <p className="text-[11px] text-slate-400">{formatDateTime(b.created_at)}</p>
        </div>
      ),
    },
    {
      key: 'customer',
      header: 'Customer',
      render: (b: Booking) => (
        <CustomerChip
          name={b.customer_name}
          phone={b.customer_phone}
          onClick={() => b.customer_name && b.customer_phone && setCustomerModal({ name: b.customer_name, phone: b.customer_phone })}
        />
      ),
    },
    {
      key: 'route',
      header: 'Route',
      render: (b: Booking) => (
        <RouteSnippet pickup={b.pickup_address} dropoff={b.dropoff_address} className="max-w-[220px]" />
      ),
    },
    {
      key: 'driver',
      header: 'Driver',
      render: (b: Booking) => (
        <div className="space-y-1.5">
          {b.driver_name
            ? <DriverChip name={b.driver_name} phone={b.driver_phone} />
            : canAssign(b)
              ? <button
                  onClick={e => { e.stopPropagation(); openAssign(b); }}
                  className="flex items-center gap-1 rounded-lg border border-dashed border-brand-300 px-2 py-1 text-xs text-brand-600 hover:bg-brand-50 transition-colors"
                >
                  <UserPlus size={11} /> Assign
                </button>
              : <span className="text-xs text-slate-400 italic">—</span>
          }
          {canDeassign(b) && (
            <button
              onClick={e => { e.stopPropagation(); openDeassign(b); }}
              className="flex items-center gap-1 rounded-lg border border-amber-200 px-2 py-1 text-[11px] text-amber-600 hover:bg-amber-50 transition-colors"
            >
              <UserMinus size={10} /> Unassign
            </button>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (b: Booking) => (
        <div>
          <div className="flex items-center gap-2">
            <Badge status={b.status} dot />
            {b.report_id && (
              <div className="flex items-center gap-1 px-2 py-1 bg-red-100 text-red-700 rounded text-[10px] font-semibold">
                <AlertTriangle size={10} />
                Report
              </div>
            )}
          </div>
          <p className="text-xs font-semibold text-slate-800 mt-1">{formatCurrency(b.final_fare ?? b.estimated_fare)}</p>
          {b.distance_km ? <p className="text-[10px] text-slate-400">{b.distance_km} km</p> : null}
        </div>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (b: Booking) => (
        <div className="flex items-center gap-1.5">
          <button
            onClick={e => { e.stopPropagation(); setDetailId(b.id); setSelected(b); }}
            className="rounded-xl border border-slate-200 px-2.5 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50 transition-colors whitespace-nowrap"
          >
            View
          </button>
          {canAssign(b) && (
            <button
              onClick={e => { e.stopPropagation(); openAssign(b); }}
              className="rounded-xl bg-brand-600 px-2.5 py-1.5 text-xs font-semibold text-white hover:bg-brand-700 transition-colors whitespace-nowrap"
            >
              {b.status === 'assigned' ? 'Reassign' : 'Assign'}
            </button>
          )}
          {canCancel(b) && (
            <button
              onClick={e => { e.stopPropagation(); openCancel(b); }}
              className="rounded-xl border border-red-200 px-2.5 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50 transition-colors whitespace-nowrap"
            >
              Cancel
            </button>
          )}
        </div>
      ),
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ], []);

  return (
    <PageWrapper
      title="Bookings"
      subtitle="Manage all customer bookings"
      actions={
        <div className="flex items-center gap-2">
          {pendingCount > 0 && (
            <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-700">
              <span className="h-1.5 w-1.5 rounded-full bg-amber-500 animate-pulse" />
              {pendingCount} pending
            </span>
          )}
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-50 disabled:opacity-40 transition-colors"
          >
            <RefreshCw size={12} className={isFetching ? 'animate-spin' : ''} />
            <span className="hidden sm:inline">Refresh</span>
          </button>
        </div>
      }
    >
      <FilterBar
        search={search} onSearch={v => { setSearch(v); setPage(1); }}
        status={status} onStatus={v => { setStatus(v); setPage(1); }}
        type={type}     onType={v => { setType(v); setPage(1); }}
        from={from}     onFrom={v => { setFrom(v); setPage(1); }}
        to={to}         onTo={v => { setTo(v); setPage(1); }}
        isActiveView={isActiveView}
      />

      {/* ── Mobile card list ──────────────────────────────────────────────── */}
      <div className="md:hidden space-y-2.5">
        {isLoading ? (
          <div className="flex items-center justify-center py-16 text-sm text-slate-400">Loading…</div>
        ) : allBookings.length === 0 ? (
          <div className="flex items-center justify-center py-16 text-sm text-slate-400">No bookings found.</div>
        ) : allBookings.map(b => (
          <BookingCard
            key={b.id}
            booking={b}
            onView={() => { setDetailId(b.id); setSelected(b); }}
            onAssign={canAssign(b) ? () => openAssign(b) : undefined}
            onDeassign={canDeassign(b) ? () => openDeassign(b) : undefined}
            onCancel={canCancel(b) ? () => openCancel(b) : undefined}
            onCustomerClick={b.customer_name && b.customer_phone
              ? () => setCustomerModal({ name: b.customer_name!, phone: b.customer_phone! })
              : undefined}
          />
        ))}
        <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
      </div>

      {/* ── Desktop table ─────────────────────────────────────────────────── */}
      <div className="hidden md:block">
        <Card padding={false}>
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50">
                  {columns.map(col => (
                    <th key={col.key} className="px-4 py-3 text-xs font-semibold uppercase tracking-wide text-slate-500 whitespace-nowrap">
                      {col.header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {isLoading ? (
                  <tr><td colSpan={columns.length} className="py-16 text-center text-slate-400">Loading…</td></tr>
                ) : allBookings.length === 0 ? (
                  <tr><td colSpan={columns.length} className="py-16 text-center text-slate-400">No bookings found.</td></tr>
                ) : allBookings.map(b => (
                  <tr
                    key={b.id}
                    onClick={() => { setDetailId(b.id); setSelected(b); }}
                    className={cn(
                      'cursor-pointer hover:bg-slate-50/80 transition-colors',
                      b.status === 'pending' && 'bg-amber-50/40 hover:bg-amber-50/70',
                    )}
                  >
                    {columns.map(col => (
                      <td key={col.key} className="px-4 py-3.5 text-slate-700 align-top">
                        {col.render(b)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
        </Card>
      </div>

      {/* ── Booking detail modal ──────────────────────────────────────────── */}
      {detailId && selected && (
        <BookingDetailModal
          bookingId={detailId}
          onClose={() => { setDetailId(null); }}
          onAssign={() => openAssign(selected)}
          onDeassign={() => openDeassign(selected)}
          onCancel={() => openCancel(selected)}
          canAssign={canAssign(selected)}
          canDeassign={canDeassign(selected)}
          canCancel={canCancel(selected)}
        />
      )}

      {/* ── Assign driver modal ───────────────────────────────────────────── */}
      <Modal
        open={assignOpen}
        onClose={closeAssign}
        title="Assign Driver"
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={closeAssign}>Cancel</Button>
            <Button
              loading={assignMutation.isPending}
              disabled={!assignId || (hasVehicleMismatch && !mismatchConfirmed)}
              onClick={() => assignMutation.mutate()}
            >
              Assign Driver
            </Button>
          </>
        }
      >
        {selected && (
          <div className="flex flex-col gap-4 md:flex-row md:gap-5">
            {/* Booking summary */}
            <div className="md:w-52 md:shrink-0 space-y-2">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Booking</p>
              <div className="rounded-xl bg-slate-50 p-3 space-y-2">
                <div className="flex items-center gap-2">
                  <User size={12} className="shrink-0 text-slate-400" />
                  <div className="min-w-0">
                    <p className="text-xs font-semibold text-slate-700 truncate">{selected.customer_name ?? '—'}</p>
                    <p className="text-[10px] text-slate-400">{selected.customer_phone}</p>
                  </div>
                </div>
                <div className="space-y-1">
                  <div className="flex items-start gap-1.5">
                    <div className="mt-1 h-2 w-2 shrink-0 rounded-full bg-green-400" />
                    <p className="text-[11px] text-slate-600 leading-snug">{selected.pickup_address}</p>
                  </div>
                  <div className="ml-[5px] h-3 border-l border-dashed border-slate-300" />
                  <div className="flex items-start gap-1.5">
                    <div className="mt-1 h-2 w-2 shrink-0 rounded-full bg-red-400" />
                    <p className="text-[11px] text-slate-600 leading-snug">{selected.dropoff_address}</p>
                  </div>
                </div>
              </div>
              <div className="rounded-xl bg-slate-50 p-3 space-y-1">
                {[
                  ['Vehicle', selected.vehicle_type ?? '—'],
                  ['Category', selected.vehicle_type_category ?? '—'],
                  ['Fare', formatCurrency(selected.estimated_fare)],
                  ['Distance', selected.distance_km ? `${selected.distance_km} km` : '—'],
                ].map(([k, v]) => (
                  <div key={k} className="flex items-center justify-between">
                    <span className="text-[10px] text-slate-400">{k}</span>
                    <span className="text-[11px] font-medium text-slate-700 capitalize">{v}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Driver selector */}
            <div className="flex-1 min-w-0 flex flex-col gap-3">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Select Driver</p>

              {/* ── Nearest-driver suggestions ─────────────────────────────── */}
              {(suggestions?.online?.length || suggestions?.offline?.length) ? (
                <div className="rounded-xl border border-brand-100 bg-brand-50 p-2.5 space-y-1.5">
                  <p className="text-[10px] font-bold text-brand-600 uppercase tracking-wide flex items-center gap-1">
                    <MapPin size={10} /> Nearest drivers for this pickup
                  </p>
                  {(suggestions.online ?? []).map(d => (
                    <button key={d.id} onClick={() => { setAssignId(d.id); setMismatchConfirmed(false); }}
                      className={cn(
                        'w-full flex items-center gap-2 rounded-lg px-2.5 py-2 text-left transition-colors text-xs',
                        assignId === d.id ? 'bg-brand-600 text-white' : 'bg-white hover:bg-brand-100 text-slate-700',
                      )}>
                      <span className="h-2 w-2 rounded-full bg-green-400 shrink-0" />
                      <span className="font-semibold">{d.name}</span>
                      <span className={cn('text-[10px]', assignId === d.id ? 'text-brand-100' : 'text-slate-400')}>{d.plate_number}</span>
                      <span className="ml-auto font-mono text-[10px]">{Number(d.distance_km).toFixed(1)} km</span>
                    </button>
                  ))}
                  {(suggestions.offline ?? []).map(d => (
                    <button key={d.id} onClick={() => { setAssignId(d.id); setMismatchConfirmed(false); }}
                      className={cn(
                        'w-full flex items-center gap-2 rounded-lg px-2.5 py-2 text-left transition-colors text-xs border border-dashed',
                        assignId === d.id ? 'bg-brand-600 text-white border-brand-600' : 'bg-white hover:bg-amber-50 text-slate-500 border-slate-200',
                      )}>
                      <span className="h-2 w-2 rounded-full bg-slate-300 shrink-0" />
                      <span className="font-semibold">{d.name}</span>
                      <span className={cn('text-[10px]', assignId === d.id ? 'text-brand-100' : 'text-slate-400')}>{d.plate_number}</span>
                      <span className={cn('text-[10px] ml-1', assignId === d.id ? 'text-brand-200' : 'text-amber-600')}>offline</span>
                      <span className="ml-auto font-mono text-[10px]">{Number(d.distance_km).toFixed(1)} km</span>
                    </button>
                  ))}
                </div>
              ) : null}

              <div className="flex gap-2">
                <div className="relative flex-1">
                  <Search size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search name or phone…"
                    value={driverSearch}
                    onChange={e => { setDriverSearch(e.target.value); setAssignId(''); }}
                    className="w-full rounded-xl border border-slate-300 bg-white pl-7 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                    autoFocus
                  />
                </div>
                <button
                  onClick={() => setOnlineOnly(v => !v)}
                  className={cn(
                    'shrink-0 rounded-xl border px-3 py-2 text-xs font-medium transition-colors',
                    onlineOnly ? 'border-green-300 bg-green-50 text-green-700' : 'border-slate-300 bg-white text-slate-500 hover:bg-slate-50',
                  )}
                >
                  {onlineOnly ? '🟢 Online' : 'All'}
                </button>
              </div>

              <div className="h-56 md:h-64 overflow-y-auto rounded-xl border border-slate-200 divide-y divide-slate-100">
                {driversLoading ? (
                  <div className="flex items-center justify-center h-full text-xs text-slate-400">Loading…</div>
                ) : (driverList?.data ?? []).length === 0 ? (
                  <div className="flex items-center justify-center h-full text-xs text-slate-400">No drivers found.</div>
                ) : (driverList?.data ?? []).map(driver => {
                  const isSel = assignId === driver.id;
                  const vtMismatch = selected.vehicle_type_id && driver.driver_vehicle_type_id
                    ? selected.vehicle_type_id !== driver.driver_vehicle_type_id : false;
                  const vehicleInfo = [driver.vehicle_type, driver.make, driver.model, driver.plate_number].filter(Boolean).join(' · ') || 'No vehicle';
                  return (
                    <button
                      key={driver.id}
                      onClick={() => { setAssignId(driver.id); setMismatchConfirmed(false); }}
                      className={cn(
                        'w-full flex items-center gap-3 px-4 py-3 text-left transition-colors',
                        isSel ? 'bg-brand-50 border-l-[3px] border-brand-500' : 'hover:bg-slate-50 active:bg-slate-100',
                      )}
                    >
                      <span className={cn('shrink-0 h-2.5 w-2.5 rounded-full mt-0.5', Number(driver.is_online) ? 'bg-green-400' : 'bg-slate-300')} />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="text-sm font-semibold text-slate-800">{driver.name}</span>
                          {vtMismatch && (
                            <span className="inline-flex items-center gap-0.5 rounded-full bg-amber-100 px-1.5 py-0.5 text-[9px] font-bold text-amber-700">
                              <AlertTriangle size={8} /> mismatch
                            </span>
                          )}
                        </div>
                        <p className="text-xs text-slate-400 mt-0.5">{driver.phone}</p>
                        <p className="text-[10px] text-slate-400 truncate">{vehicleInfo}</p>
                      </div>
                      {isSel && (
                        <span className="shrink-0 h-5 w-5 rounded-full bg-brand-600 flex items-center justify-center">
                          <svg viewBox="0 0 10 10" className="h-3 w-3"><path d="M1.5 5l2.5 2.5 4.5-4" stroke="white" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>

              {hasVehicleMismatch && selectedDriver && (
                <div className="rounded-xl border border-amber-200 bg-amber-50 p-3">
                  <div className="flex items-start gap-2">
                    <AlertTriangle size={14} className="mt-0.5 shrink-0 text-amber-600" />
                    <div className="flex-1">
                      <p className="text-xs font-semibold text-amber-800">Vehicle type mismatch</p>
                      <p className="text-[11px] text-amber-700 mt-0.5">
                        Booking needs <strong>{selected.vehicle_type ?? 'Unknown'}</strong> but{' '}
                        <strong>{selectedDriver.name}</strong> has <strong>{selectedDriver.vehicle_type ?? 'different type'}</strong>.
                      </p>
                      <label className="mt-2 flex items-center gap-2 cursor-pointer">
                        <input type="checkbox" checked={mismatchConfirmed} onChange={e => setMismatchConfirmed(e.target.checked)} className="h-4 w-4 rounded border-amber-400 text-amber-600 focus:ring-amber-500" />
                        <span className="text-xs font-medium text-amber-800">Yes, assign anyway</span>
                      </label>
                    </div>
                  </div>
                </div>
              )}

              <p className="text-[10px] text-slate-400">
                {driverList?.total ?? 0} active driver{(driverList?.total ?? 0) !== 1 ? 's' : ''}.
                {Number(driverList?.total) > 100 ? ' Use search to narrow results.' : ''}
              </p>
            </div>
          </div>
        )}
      </Modal>

      {/* ── Cancel confirm ────────────────────────────────────────────────── */}
      <ConfirmModal
        open={cancelOpen}
        onClose={() => setCancelOpen(false)}
        onConfirm={() => cancelMutation.mutate()}
        title="Cancel Booking"
        message={`Cancel booking for ${selected?.customer_name ?? selected?.id}? This cannot be undone.`}
        confirmLabel="Yes, Cancel"
        danger
        loading={cancelMutation.isPending}
      />

      {/* ── Deassign confirm ──────────────────────────────────────────────── */}
      <ConfirmModal
        open={deassignOpen}
        onClose={() => setDeassignOpen(false)}
        onConfirm={() => deassignMutation.mutate()}
        title="Unassign Driver"
        message={`Remove ${selected?.driver_name ?? 'the driver'} from this booking? The booking will return to pending.`}
        confirmLabel="Yes, Unassign"
        loading={deassignMutation.isPending}
      />

      {/* ── Customer modal ────────────────────────────────────────────────── */}
      {customerModal && (
        <CustomerModal
          name={customerModal.name}
          phone={customerModal.phone}
          onClose={() => setCustomerModal(null)}
        />
      )}
    </PageWrapper>
  );
}

// ── Filter bar ─────────────────────────────────────────────────────────────────
interface FilterBarProps {
  search: string; onSearch: (v: string) => void;
  status: string; onStatus: (v: string) => void;
  type: string;   onType: (v: string) => void;
  from: string;   onFrom: (v: string) => void;
  to: string;     onTo: (v: string) => void;
  isActiveView: boolean;
}

function FilterBar({ search, onSearch, status, onStatus, type, onType, from, onFrom, to, onTo, isActiveView }: FilterBarProps) {
  const [expanded, setExpanded] = useState(false);
  const hasExtra = type || from || to;

  return (
    <div className="mb-4 space-y-2">
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 z-10" />
          <input
            placeholder="Search customer, phone…"
            value={search}
            onChange={e => onSearch(e.target.value)}
            className="w-full rounded-xl border border-slate-300 bg-white pl-9 pr-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
        <select
          value={status}
          onChange={e => onStatus(e.target.value)}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 min-w-0"
        >
          {STATUS_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <button
          onClick={() => setExpanded(v => !v)}
          className={cn(
            'md:hidden flex items-center gap-1 rounded-xl border px-3 py-2.5 text-sm transition-colors shrink-0',
            (hasExtra || expanded) ? 'border-brand-300 bg-brand-50 text-brand-700' : 'border-slate-300 bg-white text-slate-500',
          )}
        >
          <SlidersHorizontal size={14} />
          <ChevronDown size={12} className={cn('transition-transform', expanded && 'rotate-180')} />
        </button>
      </div>

      <div className={cn('grid grid-cols-3 gap-2', expanded ? 'grid' : 'hidden md:grid')}>
        <select value={type} onChange={e => onType(e.target.value)}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500">
          {TYPE_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <input type="date" value={from} onChange={e => onFrom(e.target.value)}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
        <input type="date" value={to} onChange={e => onTo(e.target.value)}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
      </div>

      {isActiveView && (
        <p className="text-[11px] text-slate-400 flex items-center gap-1.5">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-green-400 animate-pulse" />
          Auto-refreshing every 12 s
        </p>
      )}
    </div>
  );
}

// ── Mobile booking card ─────────────────────────────────────────────────────────
interface BookingCardProps {
  booking: Booking;
  onView: () => void;
  onAssign?: () => void;
  onDeassign?: () => void;
  onCancel?: () => void;
  onCustomerClick?: () => void;
}

function BookingCard({ booking: b, onView, onAssign, onDeassign, onCancel, onCustomerClick }: BookingCardProps) {
  const isPending = b.status === 'pending';
  const isActive  = ACTIVE_STATUSES.has(b.status);

  return (
    <div className={cn(
      'rounded-2xl border bg-white overflow-hidden shadow-sm',
      isPending ? 'border-amber-300' : 'border-slate-200',
    )}>
      {/* Top strip */}
      <div className={cn(
        'flex items-center justify-between px-4 py-2',
        isPending ? 'bg-amber-50' : isActive ? 'bg-slate-50' : 'bg-white',
      )}>
        <div className="flex items-center gap-2">
          <Badge status={b.status} dot />
          <span className="text-[10px] text-slate-400 capitalize">{b.booking_type}</span>
        </div>
        <span className="text-[10px] text-slate-400">{formatDateTime(b.created_at)}</span>
      </div>

      <div className="px-4 pb-3 pt-2 space-y-3">
        {/* Customer row */}
        <div className="flex items-center gap-2">
          {onCustomerClick ? (
            <button onClick={onCustomerClick} className="flex items-center gap-2 flex-1 min-w-0 group text-left">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-100 group-hover:bg-brand-200 transition-colors">
                <span className="text-xs font-bold text-brand-700">{(b.customer_name ?? '?').charAt(0).toUpperCase()}</span>
              </div>
              <div className="min-w-0">
                <p className="text-sm font-semibold text-slate-800 group-hover:text-brand-700 transition-colors leading-tight truncate">{b.customer_name ?? '—'}</p>
                <p className="text-xs text-slate-400">{b.customer_phone}</p>
              </div>
            </button>
          ) : (
            <div className="flex items-center gap-2 flex-1 min-w-0">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-slate-100">
                <User size={14} className="text-slate-500" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-semibold text-slate-800 leading-tight truncate">{b.customer_name ?? '—'}</p>
                <p className="text-xs text-slate-400">{b.customer_phone}</p>
              </div>
            </div>
          )}
          <div className="ml-auto text-right shrink-0">
            <p className="text-sm font-bold text-slate-800">{formatCurrency(b.final_fare ?? b.estimated_fare)}</p>
            {b.distance_km ? <p className="text-[10px] text-slate-400">{b.distance_km} km</p> : null}
          </div>
        </div>

        {/* Route */}
        <div className="rounded-xl bg-slate-50 px-3 py-2.5 space-y-1.5">
          <div className="flex items-start gap-2">
            <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-green-400" />
            <p className="text-xs text-slate-700 leading-snug">{b.pickup_address}</p>
          </div>
          <div className="ml-[5px] h-3 border-l border-dashed border-slate-300" />
          <div className="flex items-start gap-2">
            <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-red-400" />
            <p className="text-xs text-slate-700 leading-snug">{b.dropoff_address}</p>
          </div>
        </div>

        {/* Driver section */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Car size={12} className="shrink-0 text-slate-400" />
            {b.driver_name
              ? <div>
                  <p className="text-xs font-medium text-slate-700 leading-tight">{b.driver_name}</p>
                  {b.driver_phone && <p className="text-[10px] text-slate-400">{b.driver_phone}</p>}
                </div>
              : <span className="text-xs text-slate-400 italic">No driver assigned</span>
            }
          </div>
          {b.vehicle_type && <span className="text-[10px] text-slate-400 bg-slate-100 rounded-full px-2 py-0.5">{b.vehicle_type}</span>}
        </div>

        {/* Action buttons */}
        <div className="space-y-2 pt-1">
          {onAssign && (
            <button onClick={onAssign}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-brand-600 px-4 py-3 text-sm font-semibold text-white shadow-sm active:scale-[0.98] transition-transform hover:bg-brand-700">
              <UserPlus size={16} />
              {b.status === 'assigned' ? 'Reassign Driver' : 'Assign Driver'}
            </button>
          )}
          {onDeassign && (
            <button onClick={onDeassign}
              className="flex w-full items-center justify-center gap-2 rounded-xl border border-amber-200 bg-amber-50 py-2.5 text-sm font-medium text-amber-700 hover:bg-amber-100 active:bg-amber-200 transition-colors">
              <UserMinus size={14} /> Unassign Driver
            </button>
          )}
          <div className="flex gap-2">
            <button onClick={onView}
              className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-slate-200 py-2.5 text-sm font-medium text-slate-600 hover:bg-slate-50 active:bg-slate-100 transition-colors">
              <Eye size={14} /> View
            </button>
            {onCancel && (
              <button onClick={onCancel}
                className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-red-100 py-2.5 text-sm font-medium text-red-500 hover:bg-red-50 active:bg-red-100 transition-colors">
                <XCircle size={14} /> Cancel
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
