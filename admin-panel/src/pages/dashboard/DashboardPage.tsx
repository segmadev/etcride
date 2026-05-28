import { useQuery } from '@tanstack/react-query';
import { BookOpen, Car, TrendingUp, CheckCircle, XCircle, ArrowRight } from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts';
import { Link } from 'react-router-dom';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { StatCard, Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { reportsApi, bookingsApi } from '../../api';
import { formatCurrency, formatDate, formatDateTime } from '../../utils';

export function DashboardPage() {
  const today = new Date();
  const fromDate = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
  const toDate = today.toISOString().split('T')[0];

  const { data: bookingReport } = useQuery({
    queryKey: ['reports', 'bookings', fromDate, toDate],
    queryFn: () => reportsApi.bookings({ from: fromDate, to: toDate }),
  });
  const { data: revenueReport } = useQuery({
    queryKey: ['reports', 'revenue', fromDate, toDate],
    queryFn: () => reportsApi.revenue({ from: fromDate, to: toDate }),
  });
  const { data: recentBookings } = useQuery({
    queryKey: ['bookings', 'recent'],
    queryFn: () => bookingsApi.list({ page: 1 }),
    refetchInterval: 30_000,
  });

  const summary = bookingReport?.summary;
  const revenue = revenueReport?.summary;

  const chartData = (bookingReport?.daily ?? [])
    .slice(0, 14).reverse()
    .map(d => ({
      date:      formatDate(d.date).split(' ').slice(0, 2).join(' '),
      total:     d.total,
      completed: d.completed,
      revenue:   parseFloat(d.revenue),
    }));

  return (
    <PageWrapper
      title="Dashboard"
      subtitle={`Overview for ${new Date().toLocaleDateString('en-NG', { month: 'long', year: 'numeric' })}`}
    >
      {/* ── Primary stat cards ──────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 md:gap-4 xl:grid-cols-4 mb-4 md:mb-6">
        <StatCard
          title="Total Bookings"
          value={summary?.total ?? '—'}
          sub="This month"
          icon={<BookOpen size={20} />}
          color="bg-blue-50 text-blue-600"
        />
        <StatCard
          title="Completed"
          value={summary?.completed ?? '—'}
          sub={`${summary ? Math.round((summary.completed / (summary.total || 1)) * 100) : 0}% rate`}
          icon={<CheckCircle size={20} />}
          color="bg-green-50 text-green-600"
        />
        <StatCard
          title="Revenue"
          value={revenue ? formatCurrency(parseFloat(revenue.total_revenue)) : '—'}
          sub={`${revenue?.paid_bookings ?? 0} paid`}
          icon={<TrendingUp size={20} />}
          color="bg-brand-50 text-brand-600"
        />
        <StatCard
          title="Cancellations"
          value={summary?.cancelled ?? '—'}
          sub={`${summary ? Math.round((summary.cancelled / (summary.total || 1)) * 100) : 0}% rate`}
          icon={<XCircle size={20} />}
          color="bg-red-50 text-red-600"
        />
      </div>

      {/* ── Secondary stats ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 md:gap-4 sm:grid-cols-4 mb-4 md:mb-6">
        {[
          { label: 'Pending',     value: summary?.pending     ?? 0, status: 'pending' },
          { label: 'In Progress', value: summary?.in_progress ?? 0, status: 'in_progress' },
          { label: 'Rides',       value: summary?.rides       ?? 0, status: 'assigned' },
          { label: 'Deliveries',  value: summary?.deliveries  ?? 0, status: 'accepted' },
        ].map(item => (
          <Card key={item.label} className="flex flex-col items-center py-4 md:py-5 gap-2">
            <span className="text-2xl font-bold text-slate-900">{item.value}</span>
            <Badge status={item.status}>{item.label}</Badge>
          </Card>
        ))}
      </div>

      {/* ── Chart + Revenue ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-4 md:gap-6 lg:grid-cols-3 mb-4 md:mb-6">
        <Card padding={false} className="lg:col-span-2">
          <div className="px-4 pt-4 pb-2 md:px-6 md:pt-5">
            <h3 className="text-sm font-semibold text-slate-900">Booking Trend (Last 14 days)</h3>
            <p className="text-xs text-slate-400 mt-0.5">Daily bookings and completions</p>
          </div>
          <div className="h-48 px-2 pb-3 md:h-64 md:pb-4">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} barSize={10} barGap={2}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                <YAxis tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e2e8f0' }} cursor={{ fill: '#f8fafc' }} />
                <Bar dataKey="total"     name="Total"     fill="#dbeafe" radius={[4,4,0,0]} />
                <Bar dataKey="completed" name="Completed" fill="#16a34a" radius={[4,4,0,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <h3 className="text-sm font-semibold text-slate-900 mb-4">Revenue Breakdown</h3>
          <div className="space-y-3">
            {[
              { label: 'Total Revenue',   value: revenue ? formatCurrency(parseFloat(revenue.total_revenue)) : '—' },
              { label: 'Average Fare',    value: revenue ? formatCurrency(parseFloat(revenue.avg_fare)) : '—' },
              { label: 'Failed Payments', value: revenue?.failed_payments ?? '—' },
            ].map(item => (
              <div key={item.label} className="flex items-center justify-between py-2 border-b border-slate-100 last:border-0">
                <span className="text-xs text-slate-500">{item.label}</span>
                <span className="text-sm font-semibold text-slate-900">{item.value}</span>
              </div>
            ))}
            {revenueReport?.providers?.map(p => (
              <div key={p.provider} className="flex items-center justify-between py-2 border-b border-slate-100 last:border-0">
                <span className="text-xs text-slate-500 capitalize">{p.provider}</span>
                <div className="text-right">
                  <p className="text-sm font-semibold text-slate-900">{formatCurrency(parseFloat(p.total))}</p>
                  <p className="text-[10px] text-slate-400">{p.transactions} txns</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* ── Recent bookings ─────────────────────────────────────────────────── */}
      <Card padding={false}>
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-200 md:px-6 md:py-4">
          <h3 className="text-sm font-semibold text-slate-900">Recent Bookings</h3>
          <Link to="/bookings" className="flex items-center gap-1 text-xs text-brand-600 hover:text-brand-700 font-medium transition-colors">
            View all <ArrowRight size={12} />
          </Link>
        </div>
        <div className="divide-y divide-slate-100">
          {(recentBookings?.data ?? []).slice(0, 6).map(b => (
            <div key={b.id} className="flex items-center gap-3 px-4 py-3 hover:bg-slate-50 transition-colors md:gap-4 md:px-6">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                {b.booking_type === 'delivery' ? <Car size={14} /> : <BookOpen size={14} />}
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium text-slate-900 truncate">{b.customer_name ?? b.id}</p>
                <p className="text-xs text-slate-400 truncate">{b.pickup_address} → {b.dropoff_address}</p>
              </div>
              <div className="shrink-0 text-right">
                <Badge status={b.status} dot />
                <p className="text-[10px] text-slate-400 mt-1 hidden sm:block">{formatDateTime(b.created_at)}</p>
              </div>
            </div>
          ))}
          {(recentBookings?.data ?? []).length === 0 && (
            <div className="flex items-center justify-center py-10 text-sm text-slate-400">No bookings yet.</div>
          )}
        </div>
      </Card>
    </PageWrapper>
  );
}
