import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  MapPin,
  Phone,
  Mail,
  AlertCircle,
  CheckCircle,
  XCircle,
  Car,
  DollarSign,
  User,
  MessageSquare,
  X,
  Filter,
} from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Textarea } from '../../components/ui/Input';
import { useToast } from '../../components/ui/Toast';
import { getApiErrorMessage } from '../../api';
import { tripReportsApi, type TripReport } from '../../api/tripReports';

export default function TripReportsPage() {
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedReport, setSelectedReport] = useState<TripReport | null>(null);
  const [adminNotes, setAdminNotes] = useState('');
  const [detailsTab, setDetailsTab] = useState<'overview' | 'payment' | 'notes'>('overview');
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showFilters, setShowFilters] = useState(false);

  // Filter states
  const [filters, setFilters] = useState({
    reportReason: '',
    bookingStatus: '',
    minFare: '',
    maxFare: '',
    startDate: '',
    endDate: '',
    driverName: '',
  });

  const { toast } = useToast();
  const qc = useQueryClient();

  const { data: reports = [], isLoading } = useQuery({
    queryKey: ['trip-reports', activeTab, searchTerm, filters],
    queryFn: () =>
      tripReportsApi.list({
        status: activeTab === 'all' ? undefined : (activeTab as any),
        search: searchTerm || undefined,
      }),
  });

  const approveMutation = useMutation({
    mutationFn: (reportId: number) =>
      tripReportsApi.approveCancellation(reportId, adminNotes),
    onSuccess: () => {
      toast('Cancellation approved', 'success');
      qc.invalidateQueries({ queryKey: ['trip-reports'] });
      setSelectedReport(null);
      setAdminNotes('');
      setShowDetailsModal(false);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const rejectMutation = useMutation({
    mutationFn: (reportId: number) =>
      tripReportsApi.rejectCancellation(reportId, adminNotes),
    onSuccess: () => {
      toast('Cancellation rejected', 'success');
      qc.invalidateQueries({ queryKey: ['trip-reports'] });
      setSelectedReport(null);
      setAdminNotes('');
      setShowDetailsModal(false);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  // Apply client-side filtering
  const filteredReports = reports.filter((report) => {
    if (filters.reportReason && report.report_reason !== filters.reportReason) return false;
    if (filters.bookingStatus && report.booking_status !== filters.bookingStatus) return false;
    if (filters.minFare && report.final_fare && report.final_fare < parseFloat(filters.minFare)) return false;
    if (filters.maxFare && report.final_fare && report.final_fare > parseFloat(filters.maxFare)) return false;
    if (filters.driverName && !report.driver_name?.toLowerCase().includes(filters.driverName.toLowerCase())) return false;

    if (filters.startDate) {
      const startDate = new Date(filters.startDate);
      const reportDate = new Date(report.created_at);
      if (reportDate < startDate) return false;
    }

    if (filters.endDate) {
      const endDate = new Date(filters.endDate);
      const reportDate = new Date(report.created_at);
      if (reportDate > endDate) return false;
    }

    return true;
  });

  const getStatusColor = (status?: string) => {
    if (!status) return 'text-slate-500 bg-slate-100';
    if (status === 'approved') return 'text-green-700 bg-green-100';
    if (status === 'rejected') return 'text-red-700 bg-red-100';
    return 'text-yellow-700 bg-yellow-100';
  };

  const getStatusIcon = (status?: string) => {
    if (status === 'approved')
      return <CheckCircle size={16} className="text-green-600" />;
    if (status === 'rejected') return <XCircle size={16} className="text-red-600" />;
    return <AlertCircle size={16} className="text-yellow-600" />;
  };

  const pendingCount = reports.filter(
    (r) => r.cancellation_status === 'pending'
  ).length;

  const approvedCount = reports.filter(
    (r) => r.cancellation_status === 'approved'
  ).length;

  const rejectedCount = reports.filter(
    (r) => r.cancellation_status === 'rejected'
  ).length;

  const handleSelectReport = (report: TripReport) => {
    setSelectedReport(report);
    setDetailsTab('overview');
    setAdminNotes('');
    const isMobile = window.innerWidth < 1024;
    if (isMobile) {
      setShowDetailsModal(true);
    }
  };

  const resetFilters = () => {
    setFilters({
      reportReason: '',
      bookingStatus: '',
      minFare: '',
      maxFare: '',
      startDate: '',
      endDate: '',
      driverName: '',
    });
  };

  const hasActiveFilters = Object.values(filters).some(value => value !== '');

  return (
    <PageWrapper title="Trip Reports">
      {/* Tabs */}
      <div className="flex flex-wrap gap-2 mb-6 border-b border-slate-200 overflow-x-auto">
        {[
          { id: 'pending', label: `Pending (${pendingCount})` },
          { id: 'approved', label: `Approved (${approvedCount})` },
          { id: 'rejected', label: `Rejected (${rejectedCount})` },
          { id: 'all', label: 'All Reports' },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`px-3 md:px-4 py-2 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
              activeTab === tab.id
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-slate-600 hover:text-slate-900'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Search and Filter Bar */}
      <div className="mb-6 space-y-4">
        <div className="flex gap-2">
          <div className="flex-1">
            <Input
              placeholder="Search by booking ID or customer name..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`px-4 py-2 rounded-lg border transition-colors flex items-center gap-2 whitespace-nowrap ${
              hasActiveFilters || showFilters
                ? 'bg-blue-50 border-blue-300 text-blue-700'
                : 'border-slate-300 text-slate-700 hover:bg-slate-50'
            }`}
          >
            <Filter size={18} />
            <span className="hidden sm:inline">Filters</span>
            {hasActiveFilters && <span className="text-xs bg-blue-600 text-white rounded-full px-2 py-0.5">{Object.values(filters).filter(v => v).length}</span>}
          </button>
        </div>

        {/* Filter Panel */}
        {showFilters && (
          <Card className="p-4 md:p-6 space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-slate-900 flex items-center gap-2">
                <Filter size={18} />
                Filter Options
              </h3>
              {hasActiveFilters && (
                <button
                  onClick={resetFilters}
                  className="text-sm text-blue-600 hover:text-blue-700 font-medium"
                >
                  Reset All
                </button>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Report Reason Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Report Reason
                </label>
                <select
                  value={filters.reportReason}
                  onChange={(e) => setFilters({ ...filters, reportReason: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">All Reasons</option>
                  <option value="Driver behavior">Driver behavior</option>
                  <option value="Wrong route">Wrong route</option>
                  <option value="Vehicle condition">Vehicle condition</option>
                  <option value="Safety concern">Safety concern</option>
                  <option value="Other">Other</option>
                </select>
              </div>

              {/* Booking Status Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Booking Status
                </label>
                <select
                  value={filters.bookingStatus}
                  onChange={(e) => setFilters({ ...filters, bookingStatus: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">All Statuses</option>
                  <option value="completed">Completed</option>
                  <option value="cancelled">Cancelled</option>
                  <option value="pending">Pending</option>
                  <option value="in_progress">In Progress</option>
                </select>
              </div>

              {/* Driver Name Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Driver Name
                </label>
                <Input
                  placeholder="Search driver..."
                  value={filters.driverName}
                  onChange={(e) => setFilters({ ...filters, driverName: e.target.value })}
                />
              </div>

              {/* Min Fare Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Min Fare (₦)
                </label>
                <Input
                  type="number"
                  placeholder="0"
                  value={filters.minFare}
                  onChange={(e) => setFilters({ ...filters, minFare: e.target.value })}
                />
              </div>

              {/* Max Fare Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Max Fare (₦)
                </label>
                <Input
                  type="number"
                  placeholder="∞"
                  value={filters.maxFare}
                  onChange={(e) => setFilters({ ...filters, maxFare: e.target.value })}
                />
              </div>

              {/* Start Date Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  Start Date
                </label>
                <Input
                  type="date"
                  value={filters.startDate}
                  onChange={(e) => setFilters({ ...filters, startDate: e.target.value })}
                />
              </div>

              {/* End Date Filter */}
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">
                  End Date
                </label>
                <Input
                  type="date"
                  value={filters.endDate}
                  onChange={(e) => setFilters({ ...filters, endDate: e.target.value })}
                />
              </div>
            </div>

            <div className="flex gap-2 pt-4 border-t border-slate-200">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowFilters(false)}
                className="flex-1"
              >
                Close
              </Button>
              {hasActiveFilters && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={resetFilters}
                  className="flex-1"
                >
                  Clear All
                </Button>
              )}
            </div>
          </Card>
        )}
      </div>

      {/* Results Summary */}
      <div className="mb-4 text-sm text-slate-600">
        Showing <span className="font-semibold text-slate-900">{filteredReports.length}</span> of{' '}
        <span className="font-semibold text-slate-900">{reports.length}</span> reports
        {hasActiveFilters && ' (filtered)'}
      </div>

      {/* Main Grid - Responsive */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 lg:gap-6">
        {/* Reports List */}
        <div className="lg:col-span-2 space-y-3">
          {isLoading ? (
            <Card className="h-64 flex items-center justify-center">
              <div className="animate-spin w-8 h-8 border-2 border-blue-200 border-t-blue-600 rounded-full" />
            </Card>
          ) : filteredReports.length === 0 ? (
            <Card className="p-6 text-center text-slate-500">
              <AlertCircle size={32} className="mx-auto mb-2 text-slate-300" />
              <p>{hasActiveFilters ? 'No reports match your filters' : 'No reports found'}</p>
            </Card>
          ) : (
            filteredReports.map((report) => (
              <Card
                key={report.id}
                className={`p-4 cursor-pointer hover:shadow-md transition-all ${
                  selectedReport?.id === report.id ? 'border-2 border-blue-500 bg-blue-50' : 'border border-slate-200'
                }`}
                onClick={() => handleSelectReport(report)}
              >
                <div className="space-y-3">
                  {/* Header */}
                  <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-slate-900 text-lg">
                        #{report.booking_id.slice(-6)}
                      </span>
                      <span className="text-xs px-2 py-1 bg-red-100 text-red-700 rounded font-medium">
                        {report.report_reason}
                      </span>
                    </div>
                    {report.cancellation_status && (
                      <div className={`flex items-center gap-1 px-3 py-1 rounded-full text-xs font-semibold ${getStatusColor(report.cancellation_status)}`}>
                        {getStatusIcon(report.cancellation_status)}
                        {report.cancellation_status}
                      </div>
                    )}
                  </div>

                  {/* Customer & Trip Info */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                    <div>
                      <p className="text-slate-600">Customer</p>
                      <p className="font-semibold text-slate-900">{report.customer_name}</p>
                      <p className="text-slate-500 text-xs">{report.customer_phone}</p>
                    </div>
                    <div>
                      <p className="text-slate-600">Driver</p>
                      <p className="font-semibold text-slate-900">{report.driver_name || 'N/A'}</p>
                      <p className="text-slate-500 text-xs">{report.driver_phone || 'N/A'}</p>
                    </div>
                  </div>

                  {/* Route */}
                  <div className="text-sm bg-slate-50 p-3 rounded">
                    <div className="flex items-start gap-2">
                      <MapPin size={16} className="text-blue-600 mt-0.5 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-slate-600 text-xs">Route</p>
                        <p className="text-slate-900 font-medium truncate">{report.pickup_address}</p>
                        <p className="text-slate-400 text-xs my-1">↓</p>
                        <p className="text-slate-900 font-medium truncate">{report.destination_address}</p>
                      </div>
                    </div>
                  </div>

                  {/* Footer */}
                  <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 pt-2 border-t border-slate-200">
                    {report.final_fare && (
                      <div className="text-sm">
                        <span className="text-slate-600">Fare: </span>
                        <span className="font-semibold text-slate-900">₦{report.final_fare.toLocaleString()}</span>
                      </div>
                    )}
                    <p className="text-xs text-slate-400">
                      {new Date(report.created_at).toLocaleDateString()} {new Date(report.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>

        {/* Details Panel - Hidden on Mobile, Visible on Desktop */}
        <div className="hidden lg:block">
          {selectedReport ? (
            <DetailsPanel
              report={selectedReport}
              detailsTab={detailsTab}
              setDetailsTab={setDetailsTab}
              adminNotes={adminNotes}
              setAdminNotes={setAdminNotes}
              approveMutation={approveMutation}
              rejectMutation={rejectMutation}
            />
          ) : (
            <Card className="p-6 text-center text-slate-500 h-96 lg:h-auto flex items-center justify-center">
              <div>
                <AlertCircle size={32} className="mx-auto mb-2 text-slate-300" />
                <p>Select a report to view details</p>
              </div>
            </Card>
          )}
        </div>
      </div>

      {/* Mobile Details Modal */}
      {showDetailsModal && selectedReport && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div
            className="absolute inset-0 bg-black bg-opacity-50"
            onClick={() => setShowDetailsModal(false)}
          />

          <div className="absolute bottom-0 left-0 right-0 bg-white rounded-t-lg max-h-[90vh] overflow-y-auto shadow-lg">
            <div className="sticky top-0 bg-white border-b border-slate-200 px-4 py-3 flex items-center justify-between">
              <div className="flex-1 flex justify-center">
                <div className="w-12 h-1 bg-slate-300 rounded-full" />
              </div>
              <button
                onClick={() => setShowDetailsModal(false)}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X size={20} className="text-slate-600" />
              </button>
            </div>

            <div className="p-4">
              <DetailsPanel
                report={selectedReport}
                detailsTab={detailsTab}
                setDetailsTab={setDetailsTab}
                adminNotes={adminNotes}
                setAdminNotes={setAdminNotes}
                approveMutation={approveMutation}
                rejectMutation={rejectMutation}
              />
            </div>
          </div>
        </div>
      )}
    </PageWrapper>
  );
}

// Details Panel Component (Reused for both desktop and mobile)
function DetailsPanel({
  report,
  detailsTab,
  setDetailsTab,
  adminNotes,
  setAdminNotes,
  approveMutation,
  rejectMutation,
}: {
  report: TripReport;
  detailsTab: 'overview' | 'payment' | 'notes';
  setDetailsTab: (tab: 'overview' | 'payment' | 'notes') => void;
  adminNotes: string;
  setAdminNotes: (notes: string) => void;
  approveMutation: any;
  rejectMutation: any;
}) {
  return (
    <div className="space-y-4">
      {/* Details Tabs */}
      <Card className="p-0">
        <div className="flex border-b border-slate-200 overflow-x-auto">
          {[
            { id: 'overview', label: 'Overview' },
            { id: 'payment', label: 'Payment' },
            { id: 'notes', label: 'Notes' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setDetailsTab(tab.id as any)}
              className={`flex-1 px-3 md:px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
                detailsTab === tab.id
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-slate-600 hover:text-slate-900'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Overview Tab */}
        {detailsTab === 'overview' && (
          <div className="p-4 md:p-6 space-y-6">
            {/* Report Info */}
            <div>
              <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                <AlertCircle size={18} className="text-red-600" />
                Report Details
              </h4>
              <div className="space-y-3 text-sm">
                <DetailRow label="Booking ID" value={report.booking_id} />
                <DetailRow label="Status" value={report.booking_status} />
                <DetailRow label="Report Reason" value={report.report_reason} />
                <div>
                  <p className="text-slate-600 font-medium">Description</p>
                  <p className="text-slate-700 mt-1 leading-relaxed text-sm break-words">{report.description}</p>
                </div>
              </div>
            </div>

            {/* Customer Info */}
            <div className="pt-4 border-t border-slate-200">
              <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                <User size={18} className="text-blue-600" />
                Customer Information
              </h4>
              <div className="space-y-2 text-sm">
                <DetailRow label="Name" value={report.customer_name} />
                <div className="flex items-center gap-2">
                  <Phone size={16} className="text-slate-400 flex-shrink-0" />
                  <a href={`tel:${report.customer_phone}`} className="text-blue-600 hover:underline break-all">
                    {report.customer_phone}
                  </a>
                </div>
                <div className="flex items-center gap-2">
                  <Mail size={16} className="text-slate-400 flex-shrink-0" />
                  <a href={`mailto:${report.customer_email}`} className="text-blue-600 hover:underline truncate">
                    {report.customer_email}
                  </a>
                </div>
              </div>
            </div>

            {/* Driver Info */}
            <div className="pt-4 border-t border-slate-200">
              <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                <Car size={18} className="text-green-600" />
                Driver Information
              </h4>
              <div className="space-y-2 text-sm">
                <DetailRow label="Name" value={report.driver_name || 'N/A'} />
                {report.driver_phone && (
                  <div className="flex items-center gap-2">
                    <Phone size={16} className="text-slate-400 flex-shrink-0" />
                    <a href={`tel:${report.driver_phone}`} className="text-blue-600 hover:underline break-all">
                      {report.driver_phone}
                    </a>
                  </div>
                )}
              </div>
            </div>

            {/* Trip Details */}
            <div className="pt-4 border-t border-slate-200">
              <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                <MapPin size={18} className="text-purple-600" />
                Trip Details
              </h4>
              <div className="space-y-3 text-sm">
                <div>
                  <p className="text-slate-600">Pickup Location</p>
                  <p className="text-slate-700 font-medium break-words">{report.pickup_address}</p>
                </div>
                <div>
                  <p className="text-slate-600">Dropoff Location</p>
                  <p className="text-slate-700 font-medium break-words">{report.destination_address}</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Payment Tab */}
        {detailsTab === 'payment' && (
          <div className="p-4 md:p-6 space-y-6">
            <div>
              <h4 className="font-semibold text-slate-900 mb-3 flex items-center gap-2">
                <DollarSign size={18} className="text-green-600" />
                Payment Information
              </h4>
              <div className="space-y-3 text-sm">
                {report.final_fare ? (
                  <>
                    <div className="bg-slate-50 p-4 rounded">
                      <p className="text-slate-600">Final Fare</p>
                      <p className="text-2xl font-bold text-slate-900">₦{report.final_fare.toLocaleString()}</p>
                    </div>
                    <DetailRow label="Payment Status" value={report.booking_status || 'Pending'} />
                  </>
                ) : (
                  <p className="text-slate-500">Payment information not available</p>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Notes Tab */}
        {detailsTab === 'notes' && (
          <div className="p-4 md:p-6 space-y-4">
            {report.admin_notes && (
              <div className="bg-blue-50 border border-blue-200 p-4 rounded">
                <h5 className="font-semibold text-blue-900 mb-2 flex items-center gap-2">
                  <MessageSquare size={16} />
                  Previous Admin Notes
                </h5>
                <p className="text-blue-800 text-sm break-words">{report.admin_notes}</p>
              </div>
            )}

            {report.cancellation_status === 'pending' && (
              <div className="space-y-3">
                <div>
                  <p className="text-slate-600 font-medium mb-2 flex items-center gap-2">
                    <AlertCircle size={16} className="text-yellow-600" />
                    Cancellation Request
                  </p>
                  <p className="text-sm text-slate-700">
                    <strong>Reason:</strong> {report.cancellation_reason || 'Not specified'}
                  </p>
                </div>

                <Textarea
                  label="Add Admin Notes"
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  placeholder="Enter notes for approval/rejection..."
                  className="text-sm"
                />

                <div className="flex gap-2 pt-4 border-t border-slate-200">
                  <Button
                    variant="danger"
                    size="sm"
                    loading={rejectMutation.isPending}
                    onClick={() => rejectMutation.mutate(report.id)}
                    className="flex-1"
                  >
                    Reject
                  </Button>
                  <Button
                    size="sm"
                    loading={approveMutation.isPending}
                    onClick={() => approveMutation.mutate(report.id)}
                    className="flex-1"
                  >
                    Approve
                  </Button>
                </div>
              </div>
            )}

            {report.cancellation_status !== 'pending' && (
              <div className="bg-slate-50 p-4 rounded text-center">
                <p className="text-slate-600 text-sm">
                  This cancellation request has already been{' '}
                  <span className="font-semibold capitalize">{report.cancellation_status}</span>
                </p>
              </div>
            )}
          </div>
        )}
      </Card>
    </div>
  );
}

// Helper component for detail rows
function DetailRow({ label, value }: { label: string; value: string | number }) {
  return (
    <div>
      <p className="text-slate-600">{label}</p>
      <p className="text-slate-900 font-medium break-words">{value}</p>
    </div>
  );
}
