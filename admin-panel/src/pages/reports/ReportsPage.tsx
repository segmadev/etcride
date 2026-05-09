import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip,
  ResponsiveContainer, CartesianGrid, Legend, PieChart, Pie, Cell,
} from 'recharts';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { Button } from '../../components/ui/Button';
import { reportsApi } from '../../api';
import { formatCurrency, formatDate } from '../../utils';
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
    { key: 'name',         header: 'Driver',       render: (d: DriverReportRow) => <span className="font-medium">{d.name}</span> },
    { key: 'phone',        header: 'Phone',        render: (d: DriverReportRow) => <span className="text-xs text-slate-500">{d.phone}</span> },
    { key: 'total_jobs',   header: 'Total Jobs',   render: (d: DriverReportRow) => <span className="font-semibold">{d.total_jobs}</span> },
    { key: 'completed',    header: 'Completed',    render: (d: DriverReportRow) => <span className="text-green-700 font-medium">{d.completed}</span> },
    { key: 'cancelled',    header: 'Cancelled',    render: (d: DriverReportRow) => <span className="text-red-600">{d.cancelled}</span> },
    { key: 'total_earned', header: 'Total Earned', render: (d: DriverReportRow) => <span className="font-semibold">{formatCurrency(parseFloat(d.total_earned))}</span> },
  ];

  return (
    <PageWrapper
      title="Reports"
      subtitle="Analytics and performance metrics"
    >
      {/* Date range picker */}
      <Card className="mb-5">
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex flex-col gap-1">
            <label className="text-xs text-slate-500 font-medium">From</label>
            <input type="date" value={from} onChange={e => setFrom(e.target.value)}
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs text-slate-500 font-medium">To</label>
            <input type="date" value={to} onChange={e => setTo(e.target.value)}
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
          </div>
          {[
            { label: 'This Month', fn: () => { setFrom(firstDay); setTo(today); }},
            { label: 'Last 7 Days', fn: () => {
              const d = new Date(); d.setDate(d.getDate() - 7);
              setFrom(d.toISOString().split('T')[0]); setTo(today);
            }},
            { label: 'Last 30 Days', fn: () => {
              const d = new Date(); d.setDate(d.getDate() - 30);
              setFrom(d.toISOString().split('T')[0]); setTo(today);
            }},
          ].map(({ label, fn }) => (
            <Button key={label} variant="outline" size="sm" onClick={fn}>{label}</Button>
          ))}
        </div>
      </Card>

      {/* Tab selector */}
      <div className="flex gap-1 mb-5 bg-white border border-slate-200 rounded-xl p-1 w-fit">
        {(['bookings', 'revenue', 'drivers'] as const).map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`rounded-lg px-4 py-1.5 text-sm font-medium capitalize transition-colors ${
              tab === t ? 'bg-brand-600 text-white' : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* BOOKINGS TAB */}
      {tab === 'bookings' && (
        <>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4 mb-5">
            {[
              { title: 'Total',      value: bSummary?.total      ?? '—', color: 'bg-blue-50 text-blue-600' },
              { title: 'Completed',  value: bSummary?.completed  ?? '—', color: 'bg-green-50 text-green-600' },
              { title: 'Cancelled',  value: bSummary?.cancelled  ?? '—', color: 'bg-red-50 text-red-600' },
              { title: 'In Progress',value: bSummary?.in_progress ?? '—', color: 'bg-purple-50 text-purple-600' },
            ].map(s => (
              <Card key={s.title} className="text-center py-5">
                <p className="text-2xl font-bold text-slate-900">{s.value}</p>
                <p className="text-xs text-slate-500 mt-1">{s.title}</p>
              </Card>
            ))}
          </div>

          <Card padding={false}>
            <div className="px-6 pt-5 pb-2">
              <h3 className="text-sm font-semibold text-slate-900">Daily Booking Trend</h3>
            </div>
            <div className="h-72 px-4 pb-4">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={dailyChartData} barSize={8} barGap={2}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 11, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} cursor={{ fill: '#f8fafc' }} />
                  <Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="total"     name="Total"     fill="#dbeafe" radius={[3,3,0,0]} />
                  <Bar dataKey="completed" name="Completed" fill="#16a34a" radius={[3,3,0,0]} />
                  <Bar dataKey="cancelled" name="Cancelled" fill="#ef4444" radius={[3,3,0,0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>

          <div className="grid grid-cols-2 gap-4 mt-5">
            <Card className="text-center py-5">
              <p className="text-2xl font-bold text-slate-900">{bSummary?.rides ?? '—'}</p>
              <p className="text-xs text-slate-500 mt-1">Rides</p>
            </Card>
            <Card className="text-center py-5">
              <p className="text-2xl font-bold text-slate-900">{bSummary?.deliveries ?? '—'}</p>
              <p className="text-xs text-slate-500 mt-1">Deliveries</p>
            </Card>
          </div>
        </>
      )}

      {/* REVENUE TAB */}
      {tab === 'revenue' && (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3 mb-5">
            {[
              { title: 'Total Revenue',    value: rSummary ? formatCurrency(parseFloat(rSummary.total_revenue)) : '—' },
              { title: 'Average Fare',     value: rSummary ? formatCurrency(parseFloat(rSummary.avg_fare))      : '—' },
              { title: 'Failed Payments',  value: rSummary?.failed_payments ?? '—' },
            ].map(s => (
              <Card key={s.title} className="text-center py-6">
                <p className="text-2xl font-bold text-slate-900">{s.value}</p>
                <p className="text-xs text-slate-500 mt-1">{s.title}</p>
              </Card>
            ))}
          </div>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
            <Card padding={false} className="lg:col-span-2">
              <div className="px-6 pt-5 pb-2">
                <h3 className="text-sm font-semibold text-slate-900">Revenue Trend</h3>
              </div>
              <div className="h-64 px-4 pb-4">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={dailyChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                    <XAxis dataKey="date" tick={{ fontSize: 11, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} tickLine={false} axisLine={false} />
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
                  <div className="h-40">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={providerPieData} dataKey="value" cx="50%" cy="50%" outerRadius={60} paddingAngle={3}>
                          {providerPieData.map((entry, i) => (
                            <Cell key={i} fill={entry.color} />
                          ))}
                        </Pie>
                        <Tooltip formatter={(v: unknown) => formatCurrency(Number(v))} contentStyle={{ fontSize: 12, borderRadius: 8 }} />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="space-y-2 mt-3">
                    {providerPieData.map(p => (
                      <div key={p.name} className="flex items-center justify-between text-sm">
                        <div className="flex items-center gap-2">
                          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
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

      {/* DRIVERS TAB */}
      {tab === 'drivers' && (
        <Card padding={false}>
          <div className="px-6 py-4 border-b border-slate-200">
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
