import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Eye, UserPlus, XCircle, Search, RefreshCw } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { Button } from '../../components/ui/Button';
import { Select } from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { bookingsApi, driversApi } from '../../api';
import { formatCurrency, formatDateTime } from '../../utils';
import type { Booking } from '../../types';

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

const ACTIVE_STATUSES = new Set(['pending', 'assigned', 'accepted', 'arrived', 'in_progress', 'payment_pending']);

const TYPE_OPTIONS = [
  { value: '',         label: 'All Types' },
  { value: 'ride',     label: 'Ride' },
  { value: 'delivery', label: 'Delivery' },
];

export function BookingsPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [page, setPage] = useState(1);
  const [search, setSearch]   = useState('');
  const [status, setStatus]   = useState('');
  const [type, setType]       = useState('');
  const [from, setFrom]       = useState('');
  const [to, setTo]           = useState('');

  const [selected, setSelected]     = useState<Booking | null>(null);
  const [assignOpen, setAssignOpen] = useState(false);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [assignId, setAssignId]     = useState('');

  // Auto-refresh every 12 seconds when viewing active bookings
  const isActiveView = !status || ACTIVE_STATUSES.has(status);

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ['bookings', page, search, status, type, from, to],
    queryFn: () => bookingsApi.list({ page, search, status, type, from, to }),
    refetchInterval: isActiveView ? 12_000 : false,
  });

  const { data: driverList } = useQuery({
    queryKey: ['drivers-all'],
    queryFn: () => driversApi.list({ status: 'active' }),
    enabled: assignOpen,
  });

  const assignMutation = useMutation({
    mutationFn: () => bookingsApi.assign(selected!.id, assignId),
    onSuccess: () => {
      toast('Driver assigned successfully.', 'success');
      qc.invalidateQueries({ queryKey: ['bookings'] });
      setAssignOpen(false);
    },
    onError: (e: Error) => toast(e.message, 'error'),
  });

  const cancelMutation = useMutation({
    mutationFn: () => bookingsApi.cancel(selected!.id),
    onSuccess: () => {
      toast('Booking cancelled.', 'success');
      qc.invalidateQueries({ queryKey: ['bookings'] });
      setCancelOpen(false);
    },
    onError: (e: Error) => toast(e.message, 'error'),
  });

  const canAssign  = (b: Booking) => ['pending', 'assigned'].includes(b.status);
  const canCancel  = (b: Booking) => !['completed', 'cancelled'].includes(b.status);

  const columns = [
    {
      key: 'id',
      header: 'Booking ID',
      render: (b: Booking) => (
        <span className="font-mono text-xs text-slate-500">{b.id}</span>
      ),
    },
    {
      key: 'customer',
      header: 'Customer',
      render: (b: Booking) => (
        <div>
          <p className="font-medium text-slate-800 text-sm">{b.customer_name ?? '—'}</p>
          <p className="text-xs text-slate-400">{b.customer_phone}</p>
        </div>
      ),
    },
    {
      key: 'route',
      header: 'Route',
      render: (b: Booking) => (
        <div className="max-w-xs">
          <p className="text-xs text-slate-700 truncate">{b.pickup_address}</p>
          <p className="text-xs text-slate-400 truncate">→ {b.dropoff_address}</p>
        </div>
      ),
    },
    {
      key: 'booking_type',
      header: 'Type',
      render: (b: Booking) => <Badge status={b.booking_type}>{b.booking_type}</Badge>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (b: Booking) => <Badge status={b.status} dot />,
    },
    {
      key: 'fare',
      header: 'Fare',
      render: (b: Booking) => (
        <span className="font-medium text-slate-800">
          {formatCurrency(b.final_fare ?? b.estimated_fare)}
        </span>
      ),
    },
    {
      key: 'created_at',
      header: 'Date',
      render: (b: Booking) => (
        <span className="text-xs text-slate-500">{formatDateTime(b.created_at)}</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (b: Booking) => (
        <div className="flex items-center gap-1">
          <button
            onClick={e => { e.stopPropagation(); setSelected(b); }}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 hover:text-brand-600 transition-colors"
            title="View detail"
          >
            <Eye size={14} />
          </button>
          {canAssign(b) && (
            <button
              onClick={e => { e.stopPropagation(); setSelected(b); setAssignOpen(true); }}
              className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
              title="Assign driver"
            >
              <UserPlus size={14} />
            </button>
          )}
          {canCancel(b) && (
            <button
              onClick={e => { e.stopPropagation(); setSelected(b); setCancelOpen(true); }}
              className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 hover:bg-red-50 hover:text-red-600 transition-colors"
              title="Cancel booking"
            >
              <XCircle size={14} />
            </button>
          )}
        </div>
      ),
    },
  ];

  const pendingCount = (data?.data ?? []).filter(b => b.status === 'pending').length;

  return (
    <PageWrapper
      title="Bookings"
      subtitle="Manage all customer bookings"
      action={
        <div className="flex items-center gap-3">
          {pendingCount > 0 && (
            <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-700">
              {pendingCount} pending assignment{pendingCount > 1 ? 's' : ''}
            </span>
          )}
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-50 disabled:opacity-40 transition-colors"
            title="Refresh now"
          >
            <RefreshCw size={12} className={isFetching ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>
      }
    >
      {/* Filters */}
      <Card className="mb-5">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div className="relative lg:col-span-1">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 z-10" />
            <input
              placeholder="Search customer…"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
              className="w-full rounded-lg border border-slate-300 bg-white pl-8 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>
          <Select
            options={STATUS_OPTIONS}
            value={status}
            onChange={e => { setStatus(e.target.value); setPage(1); }}
            placeholder="All Statuses"
          />
          <Select
            options={TYPE_OPTIONS}
            value={type}
            onChange={e => { setType(e.target.value); setPage(1); }}
            placeholder="All Types"
          />
          <input
            type="date"
            value={from}
            onChange={e => { setFrom(e.target.value); setPage(1); }}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
          <input
            type="date"
            value={to}
            onChange={e => { setTo(e.target.value); setPage(1); }}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
      </Card>

      {/* Auto-refresh note */}
      {isActiveView && (
        <p className="mb-3 text-[11px] text-slate-400 flex items-center gap-1">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-green-400 animate-pulse" />
          Auto-refreshing every 12 seconds
        </p>
      )}

      {/* Table */}
      <Card padding={false}>
        <Table
          columns={columns}
          data={data?.data ?? []}
          loading={isLoading}
          keyExtractor={b => b.id}
          emptyMessage="No bookings found."
          rowClassName={(b: Booking) =>
            b.status === 'pending' ? 'bg-amber-50/60' : ''
          }
        />
        <Pagination
          page={page}
          total={data?.total ?? 0}
          perPage={data?.per_page ?? 20}
          onChange={setPage}
        />
      </Card>

      {/* Detail modal */}
      <Modal
        open={!!selected && !assignOpen && !cancelOpen}
        onClose={() => setSelected(null)}
        title={`Booking ${selected?.id}`}
        size="lg"
      >
        {selected && <BookingDetail booking={selected} />}
      </Modal>

      {/* Assign driver modal */}
      <Modal
        open={assignOpen}
        onClose={() => setAssignOpen(false)}
        title="Assign Driver"
        size="sm"
        footer={
          <>
            <Button variant="outline" onClick={() => setAssignOpen(false)}>Cancel</Button>
            <Button
              loading={assignMutation.isPending}
              disabled={!assignId}
              onClick={() => assignMutation.mutate()}
            >
              Assign
            </Button>
          </>
        }
      >
        <Select
          label="Select Driver"
          value={assignId}
          onChange={e => setAssignId(e.target.value)}
          placeholder="Choose a driver…"
          options={(driverList?.data ?? [])
            .filter(d => d.is_active && d.is_online)
            .map(d => ({ value: d.id, label: `${d.name} — ${d.phone}` }))}
        />
        <p className="mt-2 text-xs text-slate-400">Only online, active drivers are shown.</p>
      </Modal>

      {/* Cancel confirm */}
      <ConfirmModal
        open={cancelOpen}
        onClose={() => setCancelOpen(false)}
        onConfirm={() => cancelMutation.mutate()}
        title="Cancel Booking"
        message={`Are you sure you want to cancel booking ${selected?.id}? This cannot be undone.`}
        confirmLabel="Yes, Cancel"
        danger
        loading={cancelMutation.isPending}
      />
    </PageWrapper>
  );
}

function BookingDetail({ booking }: { booking: Booking }) {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        {[
          { label: 'Status',      value: <Badge status={booking.status} dot /> },
          { label: 'Type',        value: <Badge status={booking.booking_type}>{booking.booking_type}</Badge> },
          { label: 'Payment',     value: <Badge status={booking.payment_status}>{booking.payment_status}</Badge> },
          { label: 'Driver',      value: booking.driver_name ?? 'Unassigned' },
          { label: 'Est. Fare',   value: formatCurrency(booking.estimated_fare) },
          { label: 'Final Fare',  value: booking.final_fare ? formatCurrency(booking.final_fare) : '—' },
          { label: 'Distance',    value: booking.distance_km ? `${booking.distance_km} km` : '—' },
          { label: 'Created',     value: formatDateTime(booking.created_at) },
        ].map(({ label, value }) => (
          <div key={label} className="rounded-lg bg-slate-50 p-3">
            <p className="text-xs text-slate-400 mb-0.5">{label}</p>
            <div className="text-sm font-medium text-slate-800">{value}</div>
          </div>
        ))}
      </div>

      <div className="rounded-lg bg-slate-50 p-3">
        <p className="text-xs text-slate-400 mb-1">Pickup</p>
        <p className="text-sm text-slate-800">{booking.pickup_address}</p>
      </div>
      <div className="rounded-lg bg-slate-50 p-3">
        <p className="text-xs text-slate-400 mb-1">Dropoff</p>
        <p className="text-sm text-slate-800">{booking.dropoff_address}</p>
      </div>

      {booking.stops && booking.stops.length > 0 && (
        <div className="rounded-lg bg-slate-50 p-3">
          <p className="text-xs text-slate-400 mb-2">Stops</p>
          {booking.stops.map((s, i) => (
            <p key={s.id} className="text-sm text-slate-700">
              {i + 1}. {s.address}
              {s.reached_at && <span className="text-xs text-green-600 ml-2">✓ reached</span>}
            </p>
          ))}
        </div>
      )}

      {booking.note && (
        <div className="rounded-lg bg-amber-50 border border-amber-200 p-3">
          <p className="text-xs text-amber-600 font-medium mb-0.5">Customer Note</p>
          <p className="text-sm text-amber-800">{booking.note}</p>
        </div>
      )}
    </div>
  );
}
