import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Power } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { Button } from '../../components/ui/Button';
import { Input, Select } from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { vehiclesApi, vehicleTypesApi } from '../../api';
import type { Vehicle } from '../../types';

export function VehiclesPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [page, setPage]     = useState(1);
  const [status, setStatus] = useState('');
  const [typeId, setTypeId] = useState('');

  const [createOpen, setCreateOpen]   = useState(false);
  const [toggleTarget, setToggleTarget] = useState<Vehicle | null>(null);

  const [form, setForm] = useState({
    vehicle_type_id: '', plate_number: '', make: '',
    model: '', color: '', year: '',
  });
  const setF = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(prev => ({ ...prev, [k]: e.target.value }));

  const { data, isLoading } = useQuery({
    queryKey: ['vehicles', page, status, typeId],
    queryFn: () => vehiclesApi.list({ page, status, vehicle_type_id: typeId }),
  });

  const { data: vehicleTypes } = useQuery({
    queryKey: ['vehicle-types'],
    queryFn: () => vehicleTypesApi.list(),
  });

  const createMutation = useMutation({
    mutationFn: () => vehiclesApi.create(form),
    onSuccess: () => {
      toast('Vehicle added.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      setCreateOpen(false);
      setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '' });
    },
    onError: (e: Error) => toast(e.message, 'error'),
  });

  const toggleMutation = useMutation({
    mutationFn: () => vehiclesApi.toggleStatus(toggleTarget!.id),
    onSuccess: () => {
      toast('Vehicle status updated.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      setToggleTarget(null);
    },
    onError: (e: Error) => toast(e.message, 'error'),
  });

  const typeOptions = [
    { value: '', label: 'All Types' },
    ...(vehicleTypes ?? []).map(t => ({ value: t.id, label: t.name })),
  ];

  const columns = [
    {
      key: 'plate_number',
      header: 'Plate',
      render: (v: Vehicle) => (
        <span className="font-mono font-semibold text-slate-800 text-sm">{v.plate_number}</span>
      ),
    },
    {
      key: 'vehicle',
      header: 'Vehicle',
      render: (v: Vehicle) => (
        <div>
          <p className="text-sm font-medium text-slate-800">{v.make} {v.model}</p>
          <p className="text-xs text-slate-400">{v.color} · {v.year ?? '—'}</p>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (v: Vehicle) => (
        <span className="text-sm text-slate-600">{v.vehicle_type_name ?? '—'}</span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (v: Vehicle) => <Badge status={v.status}>{v.status}</Badge>,
    },
    {
      key: 'driver',
      header: 'Assigned Driver',
      render: (v: Vehicle) => (
        <div>
          {v.driver_name
            ? <><p className="text-sm text-slate-800">{v.driver_name}</p><p className="text-xs text-slate-400">{v.driver_phone}</p></>
            : <span className="text-xs text-slate-400 italic">Unassigned</span>}
        </div>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (v: Vehicle) => (
        <button
          onClick={e => { e.stopPropagation(); setToggleTarget(v); }}
          className={`flex h-7 w-7 items-center justify-center rounded-lg transition-colors ${
            v.status === 'active'
              ? 'text-slate-400 hover:bg-red-50 hover:text-red-600'
              : 'text-slate-400 hover:bg-green-50 hover:text-green-600'
          }`}
          title={v.status === 'active' ? 'Deactivate' : 'Activate'}
        >
          <Power size={14} />
        </button>
      ),
    },
  ];

  return (
    <PageWrapper
      title="Vehicles"
      subtitle="Manage the vehicle fleet"
      actions={
        <Button icon={<Plus size={14} />} onClick={() => setCreateOpen(true)}>Add Vehicle</Button>
      }
    >
      <Card className="mb-5">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <Select options={typeOptions} value={typeId} onChange={e => { setTypeId(e.target.value); setPage(1); }} />
          <Select
            options={[{ value: '', label: 'All Statuses' }, { value: 'active', label: 'Active' }, { value: 'inactive', label: 'Inactive' }]}
            value={status}
            onChange={e => { setStatus(e.target.value); setPage(1); }}
          />
        </div>
      </Card>

      <Card padding={false}>
        <Table columns={columns} data={data?.data ?? []} loading={isLoading} keyExtractor={v => v.id} emptyMessage="No vehicles found." />
        <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
      </Card>

      {/* Create vehicle */}
      <Modal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        title="Add Vehicle"
        size="md"
        footer={
          <>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>Cancel</Button>
            <Button loading={createMutation.isPending} onClick={() => createMutation.mutate()}>Add Vehicle</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Select
            label="Vehicle Type *"
            value={form.vehicle_type_id}
            onChange={e => setForm(p => ({ ...p, vehicle_type_id: e.target.value }))}
            placeholder="Select type…"
            options={(vehicleTypes ?? []).map(t => ({ value: t.id, label: t.name }))}
          />
          <Input label="Plate Number *" value={form.plate_number} onChange={setF('plate_number')} placeholder="KWR-123-AB" />
          <div className="grid grid-cols-2 gap-3">
            <Input label="Make *"  value={form.make}  onChange={setF('make')}  placeholder="Toyota" />
            <Input label="Model *" value={form.model} onChange={setF('model')} placeholder="Corolla" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Input label="Color *" value={form.color} onChange={setF('color')} placeholder="White" />
            <Input label="Year"    value={form.year}  onChange={setF('year')}  placeholder="2022" type="number" />
          </div>
        </div>
      </Modal>

      {/* Toggle confirm */}
      <ConfirmModal
        open={!!toggleTarget}
        onClose={() => setToggleTarget(null)}
        onConfirm={() => toggleMutation.mutate()}
        title={toggleTarget?.status === 'active' ? 'Deactivate Vehicle' : 'Activate Vehicle'}
        message={`${toggleTarget?.status === 'active' ? 'Deactivating' : 'Activating'} ${toggleTarget?.plate_number}. ${toggleTarget?.status === 'active' ? 'The driver will be unassigned.' : ''}`}
        confirmLabel={toggleTarget?.status === 'active' ? 'Deactivate' : 'Activate'}
        danger={toggleTarget?.status === 'active'}
        loading={toggleMutation.isPending}
      />
    </PageWrapper>
  );
}
