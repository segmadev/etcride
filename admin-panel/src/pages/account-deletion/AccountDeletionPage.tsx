import { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { CheckCircle2, Clock, XCircle, MessageCircle } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input, Select, Textarea } from '../../components/ui/Input';
import { useToast } from '../../components/ui/Toast';
import { getApiErrorMessage } from '../../api';
import { cn } from '../../utils';

interface DeletionRequest {
  id: string;
  customer_id?: string;
  driver_id?: string;
  name: string;
  phone?: string;
  email?: string;
  deletion_reason?: string;
  request_status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  reviewed_at?: string;
  admin_notes?: string;
  deleted_at?: string;
}

interface ListResponse {
  type: 'customer' | 'driver';
  requests: DeletionRequest[];
  count: number;
}

export function AccountDeletionPage() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [type, setType] = useState<'customer' | 'driver'>('customer');
  const [status, setStatus] = useState<'' | 'pending' | 'approved' | 'rejected'>('pending');
  const [search, setSearch] = useState('');
  const [selectedRequest, setSelectedRequest] = useState<DeletionRequest | null>(null);
  const [actionType, setActionType] = useState<'approve' | 'reject' | null>(null);
  const [notes, setNotes] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['account-deletion-requests', type, status, search],
    queryFn: async () => {
      const params = new URLSearchParams({
        type,
        ...(status && { status }),
        ...(search && { search }),
      });
      const res = await fetch(`/api/admin/account-deletion-requests?${params}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('adminToken')}` },
      });
      if (!res.ok) throw new Error(await res.text());
      return res.json() as { data: ListResponse };
    },
  });

  const requests = data?.data?.requests || [];

  const approveMutation = useMutation({
    mutationFn: async () => {
      if (!selectedRequest) return;
      const url = type === 'customer'
        ? `/api/admin/customer-deletion/${selectedRequest.id}/approve`
        : `/api/admin/driver-deletion/${selectedRequest.id}/approve`;
      const res = await fetch(url, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${localStorage.getItem('adminToken')}`,
        },
        body: JSON.stringify({ notes }),
      });
      if (!res.ok) throw new Error(await res.text());
      return res.json();
    },
    onSuccess: () => {
      toast('Deletion request approved', 'success');
      qc.invalidateQueries({ queryKey: ['account-deletion-requests'] });
      setSelectedRequest(null);
      setActionType(null);
      setNotes('');
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const rejectMutation = useMutation({
    mutationFn: async () => {
      if (!selectedRequest) return;
      const url = type === 'customer'
        ? `/api/admin/customer-deletion/${selectedRequest.id}/reject`
        : `/api/admin/driver-deletion/${selectedRequest.id}/reject`;
      const res = await fetch(url, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${localStorage.getItem('adminToken')}`,
        },
        body: JSON.stringify({ notes }),
      });
      if (!res.ok) throw new Error(await res.text());
      return res.json();
    },
    onSuccess: () => {
      toast('Deletion request rejected', 'success');
      qc.invalidateQueries({ queryKey: ['account-deletion-requests'] });
      setSelectedRequest(null);
      setActionType(null);
      setNotes('');
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const statusIcon = (status: string) => {
    switch (status) {
      case 'pending': return <Clock className="text-amber-500" size={16} />;
      case 'approved': return <CheckCircle2 className="text-green-600" size={16} />;
      case 'rejected': return <XCircle className="text-red-600" size={16} />;
      default: return null;
    }
  };

  const statusLabel = (status: string) => {
    switch (status) {
      case 'pending': return 'Pending Review';
      case 'approved': return 'Approved (Deleted)';
      case 'rejected': return 'Rejected';
      default: return status;
    }
  };

  return (
    <PageWrapper
      title="Account Deletion Requests"
      subtitle="Review and manage customer & driver account deletion requests"
    >
      <div className="space-y-6">
        {/* Filters */}
        <Card>
          <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
            <Select
              label="User Type"
              value={type}
              onChange={(e) => setType(e.target.value as 'customer' | 'driver')}
              options={[
                { value: 'customer', label: 'Customers' },
                { value: 'driver', label: 'Drivers' },
              ]}
            />
            <Select
              label="Status"
              value={status}
              onChange={(e) => setStatus(e.target.value as any)}
              options={[
                { value: '', label: 'All Statuses' },
                { value: 'pending', label: 'Pending' },
                { value: 'approved', label: 'Approved' },
                { value: 'rejected', label: 'Rejected' },
              ]}
            />
            <Input
              label="Search"
              placeholder="Name or phone..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <div className="flex items-end">
              <Button
                variant="secondary"
                onClick={() => {
                  setStatus('pending');
                  setSearch('');
                }}
              >
                Reset Filters
              </Button>
            </div>
          </div>
        </Card>

        {/* Requests List */}
        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-20 bg-slate-100 animate-pulse rounded-lg" />
            ))}
          </div>
        ) : (
          <div className="space-y-3">
            {requests.length === 0 ? (
              <Card className="py-8 text-center">
                <p className="text-slate-500">No deletion requests found</p>
              </Card>
            ) : (
              requests.map(req => (
                <Card
                  key={req.id}
                  className={cn(
                    'flex items-start gap-4 p-4 cursor-pointer transition-colors',
                    selectedRequest?.id === req.id && 'bg-blue-50 border-blue-300',
                    'hover:bg-slate-50'
                  )}
                  onClick={() => setSelectedRequest(req)}
                >
                  {/* Status */}
                  <div className="pt-1 shrink-0">
                    {statusIcon(req.request_status)}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="font-semibold text-slate-900">{req.name}</p>
                      <span className="text-xs font-medium text-slate-500 uppercase">
                        {req.request_status}
                      </span>
                    </div>
                    <p className="text-sm text-slate-600 mt-1">
                      {req.phone || req.email || 'No contact'}
                    </p>
                    <p className="text-xs text-slate-500 mt-1">
                      Requested: {new Date(req.created_at).toLocaleDateString()}
                    </p>
                    {req.deletion_reason && (
                      <p className="text-xs text-slate-600 mt-2 italic">
                        "{req.deletion_reason}"
                      </p>
                    )}
                  </div>

                  {/* Type badge */}
                  <div className="shrink-0">
                    <span
                      className={cn(
                        'text-xs font-semibold px-2 py-1 rounded',
                        type === 'customer'
                          ? 'bg-blue-100 text-blue-700'
                          : 'bg-purple-100 text-purple-700'
                      )}
                    >
                      {type === 'customer' ? 'Customer' : 'Driver'}
                    </span>
                  </div>
                </Card>
              ))
            )}
          </div>
        )}

        {/* Detail & Action Panel */}
        {selectedRequest && (
          <Card className="bg-blue-50 border-blue-200">
            <div className="space-y-4">
              {/* Header */}
              <div className="flex items-center justify-between pb-3 border-b border-blue-200">
                <div>
                  <h3 className="font-semibold text-slate-900">{selectedRequest.name}</h3>
                  <p className="text-sm text-slate-600">
                    {selectedRequest.phone || selectedRequest.email}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {statusIcon(selectedRequest.request_status)}
                  <span className="text-sm font-medium">
                    {statusLabel(selectedRequest.request_status)}
                  </span>
                </div>
              </div>

              {/* Details */}
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-slate-600">Requested</p>
                  <p className="font-medium">{new Date(selectedRequest.created_at).toLocaleDateString()}</p>
                </div>
                {selectedRequest.reviewed_at && (
                  <div>
                    <p className="text-slate-600">Reviewed</p>
                    <p className="font-medium">{new Date(selectedRequest.reviewed_at).toLocaleDateString()}</p>
                  </div>
                )}
                {selectedRequest.deletion_reason && (
                  <div className="col-span-2">
                    <p className="text-slate-600">User's Reason</p>
                    <p className="font-medium">{selectedRequest.deletion_reason}</p>
                  </div>
                )}
              </div>

              {/* Admin Notes */}
              {selectedRequest.request_status === 'pending' && !actionType && (
                <>
                  <Textarea
                    label="Admin Review Notes (Audit Trail)"
                    placeholder="e.g., 'All payments cleared. No pending jobs. Clearance approved.'"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    rows={3}
                  />

                  <div className="flex gap-2 pt-2">
                    <button
                      onClick={() => setActionType('approve')}
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 font-medium text-sm transition-colors"
                    >
                      ✓ Approve Deletion
                    </button>
                    <button
                      onClick={() => setActionType('reject')}
                      className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium text-sm transition-colors"
                    >
                      ✗ Reject Request
                    </button>
                  </div>
                </>
              )}

              {actionType && (
                <div className="bg-white p-3 rounded-lg border border-slate-200">
                  <p className="text-sm font-medium mb-3">
                    {actionType === 'approve' ? 'Approve Deletion' : 'Reject Request'}
                  </p>
                  <Textarea
                    label="Admin Notes"
                    placeholder={actionType === 'approve'
                      ? 'e.g., All payments cleared, no pending transactions'
                      : 'e.g., Pending payments still exist, please settle first'
                    }
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    rows={2}
                  />
                  <div className="flex gap-2 mt-3">
                    <button
                      onClick={() => {
                        setActionType(null);
                        setNotes('');
                      }}
                      className="flex-1 px-3 py-2 bg-slate-200 text-slate-900 rounded-lg hover:bg-slate-300 text-sm font-medium transition-colors"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={() => {
                        if (actionType === 'approve') {
                          approveMutation.mutate();
                        } else {
                          rejectMutation.mutate();
                        }
                      }}
                      disabled={approveMutation.isPending || rejectMutation.isPending}
                      className={cn(
                        'flex-1 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                        actionType === 'approve'
                          ? 'bg-green-600 hover:bg-green-700 text-white'
                          : 'bg-red-600 hover:bg-red-700 text-white',
                        (approveMutation.isPending || rejectMutation.isPending) && 'opacity-50 cursor-not-allowed'
                      )}
                    >
                      {approveMutation.isPending || rejectMutation.isPending ? 'Processing...' : 'Confirm'}
                    </button>
                  </div>
                </div>
              )}

              {selectedRequest.admin_notes && selectedRequest.request_status !== 'pending' && (
                <div className="bg-white p-3 rounded-lg border border-slate-200">
                  <div className="flex gap-2 items-start">
                    <MessageCircle size={16} className="text-slate-500 mt-0.5 shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-slate-600">Admin Notes</p>
                      <p className="text-sm text-slate-700 mt-1">{selectedRequest.admin_notes}</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </Card>
        )}
      </div>
    </PageWrapper>
  );
}
