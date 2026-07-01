import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, RefreshCw, Eye, RotateCcw } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { Button } from '../../components/ui/Button';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { paymentsApi, getApiErrorMessage } from '../../api';
import { formatCurrency, formatDateTime } from '../../utils';
import type { Payment } from '../../api';

const STATUS_OPTIONS = [
  { value: '',         label: 'All Statuses' },
  { value: 'pending',  label: 'Pending' },
  { value: 'paid',     label: 'Paid' },
  { value: 'failed',   label: 'Failed' },
  { value: 'refunded', label: 'Refunded' },
];

export default function PaymentsPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [page, setPage]     = useState(1);
  const [status, setStatus] = useState('');
  const [search, setSearch] = useState('');
  const [detail, setDetail] = useState<Payment | null>(null);
  const [refundTarget, setRefundTarget] = useState<Payment | null>(null);

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ['admin-payments', page, status, search],
    queryFn: () => paymentsApi.list({ page, status: status || undefined, search: search || undefined }),
  });

  const refundMutation = useMutation({
    mutationFn: (id: string) => paymentsApi.refund(id),
    onSuccess: () => {
      toast('Payment marked as refunded.', 'success');
      setRefundTarget(null);
      qc.invalidateQueries({ queryKey: ['admin-payments'] });
    },
    onError: (e) => toast(getApiErrorMessage(e), 'error'),
  });

  const payments = data?.data ?? [];
  const total    = data?.total ?? 0;

  return (
    <PageWrapper title="Payments" subtitle="Transaction history and payment management">
      {/* ── Filters ──────────────────────────────────────────────────────── */}
      <Card className="mb-4 p-4">
        <div className="flex flex-wrap gap-3 items-center">
          <div className="relative flex-1 min-w-48">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search ref, provider ref, customer…"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              className="w-full pl-9 pr-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-amber-400"
            />
          </div>
          <select
            value={status}
            onChange={(e) => { setStatus(e.target.value); setPage(1); }}
            className="border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            {STATUS_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
          <Button variant="ghost" size="sm" onClick={() => refetch()} disabled={isFetching}>
            <RefreshCw className={`w-4 h-4 ${isFetching ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </Card>

      {/* ── Table (desktop) ──────────────────────────────────────────────── */}
      <Card className="overflow-hidden">
        {isLoading ? (
          <div className="p-10 text-center text-slate-400">Loading…</div>
        ) : payments.length === 0 ? (
          <div className="p-10 text-center text-slate-400">No payments found.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 border-b border-slate-100">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-slate-500">Reference</th>
                  <th className="px-4 py-3 text-left font-medium text-slate-500">Customer</th>
                  <th className="px-4 py-3 text-left font-medium text-slate-500">Provider</th>
                  <th className="px-4 py-3 text-right font-medium text-slate-500">Amount</th>
                  <th className="px-4 py-3 text-left font-medium text-slate-500">Status</th>
                  <th className="px-4 py-3 text-left font-medium text-slate-500">Date</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {payments.map((p) => (
                  <tr key={p.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="px-4 py-3">
                      <p className="font-mono text-xs text-slate-700">{p.reference}</p>
                      {p.booking_code && (
                        <p className="text-xs text-slate-400 mt-0.5">{p.booking_code}</p>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-medium text-slate-800">{p.customer_name ?? '—'}</p>
                      <p className="text-xs text-slate-400">{p.customer_phone ?? ''}</p>
                    </td>
                    <td className="px-4 py-3 capitalize">{p.provider}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-800">
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge status={p.status}>{p.status}</Badge>
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">{formatDateTime(p.created_at)}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => setDetail(p)}
                          className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500"
                          title="View details"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        {p.status === 'paid' && (
                          <button
                            onClick={() => setRefundTarget(p)}
                            className="p-1.5 rounded-lg hover:bg-red-50 text-red-500"
                            title="Refund"
                          >
                            <RotateCcw className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!isLoading && total > 0 && (
          <div className="px-4 py-3 border-t border-slate-100">
            <Pagination page={page} total={total} perPage={data?.per_page ?? 25} onChange={setPage} />
          </div>
        )}
      </Card>

      {/* ── Detail modal ─────────────────────────────────────────────────── */}
      {detail && (
        <Modal open onClose={() => setDetail(null)} title="Payment Detail" size="md">
          <div className="space-y-3 text-sm">
            <Row label="Reference"    value={detail.reference} mono />
            {detail.provider_ref && <Row label="Provider Ref" value={detail.provider_ref} mono />}
            <Row label="Provider"     value={detail.provider} className="capitalize" />
            <Row label="Amount"       value={formatCurrency(detail.amount)} />
            <Row label="Status"       value={<Badge status={detail.status}>{detail.status}</Badge>} />
            <Row label="Customer"     value={`${detail.customer_name ?? '—'} · ${detail.customer_phone ?? ''}`} />
            {detail.booking_code && <Row label="Booking" value={detail.booking_code} />}
            {detail.booking_status && <Row label="Trip Status" value={detail.booking_status} className="capitalize" />}
            {detail.distance_km != null && (
              <Row label="Distance" value={`${Number(detail.distance_km).toFixed(2)} km`} />
            )}
            {detail.final_fare != null && <Row label="Final Fare" value={formatCurrency(detail.final_fare)} />}
            {detail.pickup_address && <Row label="Pickup" value={detail.pickup_address} />}
            {detail.destination_address && <Row label="Drop-off" value={detail.destination_address} />}
            <Row label="Date" value={formatDateTime(detail.created_at)} />
          </div>
        </Modal>
      )}

      {/* ── Refund confirm ───────────────────────────────────────────────── */}
      <ConfirmModal
        open={!!refundTarget}
        onClose={() => setRefundTarget(null)}
        onConfirm={() => refundTarget && refundMutation.mutate(refundTarget.id)}
        loading={refundMutation.isPending}
        title="Mark as Refunded"
        message={`Mark payment ${refundTarget?.reference} (${formatCurrency(refundTarget?.amount ?? 0)}) as refunded? This does not automatically process the refund through the gateway.`}
        confirmLabel="Mark Refunded"
      />
    </PageWrapper>
  );
}

function Row({
  label, value, mono, className,
}: {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
  className?: string;
}) {
  return (
    <div className="flex gap-3 justify-between items-start border-b border-slate-50 pb-2 last:border-0">
      <span className="text-slate-400 shrink-0 w-32">{label}</span>
      <span className={`text-slate-800 text-right ${mono ? 'font-mono text-xs' : ''} ${className ?? ''}`}>
        {value}
      </span>
    </div>
  );
}
