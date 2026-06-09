import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip,
  ResponsiveContainer, CartesianGrid, Legend, PieChart, Pie, Cell,
} from 'recharts';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { reportsApi } from '../../api';
import { formatCurrency, formatDate } from '../../utils';
import { cn } from '../../utils';
import type { DriverReportRow } from '../../types';

const COLORS = ['#f97316', '#3b82f6', '#10b981', '#8b5cf6'];

export function ReportsPage() {
  const today    = new Date().toISOString().split('T')[0];
  const firstDay = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0];

  const [from, setFrom] = useState(firstDay);
  const [to,   setTo]   = useState(today);
  const [tab,  setTab]  = useState<'bookings' | 'revenue' | 'drivers'>('bookings');

  const { data: bookingReport } = useQuery({
    queryKey: ['report-bookings', from, to],
    queryFn: () => reportsApi.bookings({ from, to }),
  });
  const { data: revenueReport } = useQuery({
    queryKey: ['report-revenue', from, to],
    queryFn: () => reportsApi.revenue({ from, to }),
  });
  const { data: driverReport, isLoading: dLoading } = useQuery({
    queryKey: ['report-drivers', from, to],
    queryFn: () => reportsApi.drivers({ from, to }),
  });

  const bSummary = bookingReport?.summary;
  const rSummary = revenueReport?.summary;

  const dailyChartData = (bookingReport?.daily ?? [])
    .slice(0, 30).reverse()
    .map(d => ({
      date:      formatDate(d.date).slice(0, 6),
      total:     d.total,
      completed: d.completed,
      cancelled: d.cancelled,
      revenue:   parseFloat(d.revenue),
    }));

  const providerPieData = (revenueReport?.providers ?? []).map((p, i) => ({
    name:  p.provider.charAt(0).toUpperCase() + p.provider.slice(1),
    value: parseFloat(p.total),
    color: COLORS[i % COLORS.length],
  }));

  const driverColumns = [
    { key: 'name',         header: 'Driver',       render: (d: DriverReportRow) => <span className="font-medium text-slate-900">{d.name}</span> },
    { key: 'phone',        header: 'Phone',        render: (d: DriverReportRow) => <span className="text-xs text-slate-500">{d.phone}</span> },
    { key: 'total_jobs',   header: 'Total',        render: (d: DriverReportRow) => <span className="font-semibold">{d.total_jobs}</span> },
    { key: 'completed',    header: 'Done',         render: (d: DriverReportRow) => <span className="text-green-700 font-medium">{d.completed}</span> },
    { key: 'cancelled',    header: 'Cancelled',    render: (d: DriverReportRow) => <span className="text-red-600">{d.cancelled}</span> },
    { key: 'total_earned', header: 'Earned',       render: (d: DriverReportRow) => <span className="font-semibold">{formatCurrency(parseFloat(d.total_earned))}</span> },
  ];

  const quickRanges = [
    { label: 'This Month', fn: () => { setFrom(firstDay); setTo(today); } },
    { label: '7 days',     fn: () => { const d = new Date(); d.setDate(d.getDate() - 7); setFrom(d.toISOString().split('T')[0]); setTo(today); } },
    { label: '30 days',    fn: () => { const d = new Date(); d.setDate(d.getDate() - 30); setFrom(d.toISOString().split('T')[0]); setTo(today); } },
  ];

  return (
    <PageWrapper title="Reports" subtitle="Analytics and performance metrics">
      {/* ── Date range picker ────────────────────────────────────────────────── */}
      <div className="mb-4 rounded-xl border border-slate-200 bg-white p-3 md:p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:flex-wrap">
          <div className="flex gap-2 flex-1 min-w-0">
            <div className="flex flex-col gap-1 flex-1">
              <label className="text-xs text-slate-500 font-medium">From</label>
              <input type="date" value={from} onChange={e => setFrom(e.target.value)}
                className="rounded-xl border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 w-full" />
            </div>
            <div className="flex flex-col gap-1 flex-1">
              <label className="text-xs text-slate-500 font-medium">To</label>
              <input type="date" value={to} onChange={e => setTo(e.target.value)}
                className="rounded-xl border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 w-full" />
            </div>
          </div>
          <div className="flex gap-2 flex-wrap">
            {quickRanges.map(({ label, fn }) => (
              <button key={label} onClick={fn}
                className="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-xs font-medium text-slate-600 hover:bg-slate-100 hover:border-slate-300 transition-colors whitespace-nowrap">
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ── Tab selector ─────────────────────────────────────────────────────── */}
      <div className="mb-4 md:mb-5">
        <div className="flex bg-white border border-slate-200 rounded-xl p-1 w-full sm:w-fit">
          {(['bookings', 'revenue', 'drivers'] as const).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className={cn(
                'flex-1 sm:flex-none rounded-lg px-4 py-1.5 text-sm font-medium capitalize transition-colors',
                tab === t ? 'bg-brand-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100',
              )}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* ── BOOKINGS TAB ─────────────────────────────────────────────────────── */}
      {tab === 'bookings' && (
        <>
          <div className="grid grid-cols-2 gap-3 md:gap-4 sm:grid-cols-4 mb-4 md:mb-5">
            {[
              { title: 'Total',       value: bSummary?.total       ?? '—', color: 'text-blue-600 bg-blue-50' },
              { title: 'Completed',   value: bSummary?.completed   ?? '—', color: 'text-green-700 bg-green-50' },
              { title: 'Cancelled',   value: bSummary?.cancelled   ?? '—', color: 'text-red-600 bg-red-50' },
              { title: 'In Progress', value: bSummary?.in_progress ?? '—', color: 'text-purple-700 bg-purple-50' },
            ].map(s => (
              <Card key={s.title} className="text-center py-4 md:py-5">
                <p className="text-2xl font-bold text-slate-900">{s.value}</p>
                <p className="text-xs text-slate-500 mt-1">{s.title}</p>
              </Card>
            ))}
          </div>

          <Card padding={false} className="mb-4">
            <div className="px-4 pt-4 pb-2 md:px-6 md:pt-5">
              <h3 className="text-sm font-semibold text-slate-900">Daily Booking Trend</h3>
            </div>
            <div className="h-52 px-2 pb-3 md:h-72 md:pb-4">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={dailyChartData} barSize={7} barGap={2}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} cursor={{ fill: '#f8fafc' }} />
                  <Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="total"     name="Total"     fill="#dbeafe" radius={[3,3,0,0]} />
                  <Bar dataKey="completed" name="Completed" fill="#16a34a" radius={[3,3,0,0]} />
                  <Bar dataKey="cancelled" name="Cancelled" fill="#ef4444" radius={[3,3,0,0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>

          <div className="grid grid-cols-2 gap-3 md:gap-4">
            <Card className="text-center py-4 md:py-5">
              <p className="text-2xl font-bold text-slate-900">{bSummary?.rides ?? '—'}</p>
              <p className="text-xs text-slate-500 mt-1">Rides</p>
            </Card>
            <Card className="text-center py-4 md:py-5">
              <p className="text-2xl font-bold text-slate-900">{bSummary?.deliveries ?? '—'}</p>
              <p className="text-xs text-slate-500 mt-1">Deliveries</p>
            </Card>
          </div>
        </>
      )}

      {/* ── REVENUE TAB ──────────────────────────────────────────────────────── */}
      {tab === 'revenue' && (
        <>
          <div className="grid grid-cols-1 gap-3 md:gap-4 sm:grid-cols-3 mb-4 md:mb-5">
            {[
              { title: 'Total Revenue',   value: rSummary ? formatCurrency(parseFloat(rSummary.total_revenue)) : '—' },
              { title: 'Average Fare',    value: rSummary ? formatCurrency(parseFloat(rSummary.avg_fare))      : '—' },
              { title: 'Failed Payments', value: rSummary?.failed_payments ?? '—' },
            ].map(s => (
              <Card key={s.title} className="text-center py-5 md:py-6">
                <p className="text-2xl font-bold text-slate-900">{s.value}</p>
                <p className="text-xs text-slate-500 mt-1">{s.title}</p>
              </Card>
            ))}
          </div>

          <div className="grid grid-cols-1 gap-4 md:gap-5 lg:grid-cols-3">
            <Card padding={false} className="lg:col-span-2">
              <div className="px-4 pt-4 pb-2 md:px-6 md:pt-5">
                <h3 className="text-sm font-semibold text-slate-900">Revenue Trend</h3>
              </div>
              <div className="h-48 px-2 pb-3 md:h-64 md:pb-4">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={dailyChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                    <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                    <YAxis tick={{ fontSize: 10, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                    <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }}
                      formatter={(v: unknown) => [formatCurrency(Number(v)), 'Revenue']} />
                    <Line dataKey="revenue" stroke="#f97316" strokeWidth={2} dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </Card>

            <Card>
              <h3 className="text-sm font-semibold text-slate-900 mb-4">By Provider</h3>
              {providerPieData.length > 0 ? (
                <>
                  <div className="h-36 md:h-40">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={providerPieData} dataKey="value" cx="50%" cy="50%" outerRadius={60} paddingAngle={3}>
                          {providerPieData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                        </Pie>
                        <Tooltip formatter={(v: unknown) => formatCurrency(Number(v))} contentStyle={{ fontSize: 12, borderRadius: 8 }} />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="space-y-2 mt-3">
                    {providerPieData.map(p => (
                      <div key={p.name} className="flex items-center justify-between text-sm">
                        <div className="flex items-center gap-2">
                          <span className="h-2 w-2 rounded-full shrink-0" style={{ background: p.color }} />
                          <span className="text-slate-700">{p.name}</span>
                        </div>
                        <span className="font-semibold text-slate-800">{formatCurrency(p.value)}</span>
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <p className="text-sm text-slate-400 text-center py-8">No payment data.</p>
              )}
            </Card>
          </div>
        </>
      )}

      {/* ── DRIVERS TAB ──────────────────────────────────────────────────────── */}
      {tab === 'drivers' && (
        <Card padding={false}>
          <div className="px-4 py-3 border-b border-slate-200 md:px-6 md:py-4">
            <h3 className="text-sm font-semibold text-slate-900">Driver Performance</h3>
          </div>
          <Table
            columns={driverColumns}
            data={driverReport?.data ?? []}
            loading={dLoading}
            keyExtractor={d => d.id}
            emptyMessage="No driver data for this period."
          />
        </Card>
      )}
    </PageWrapper>
  );
}
