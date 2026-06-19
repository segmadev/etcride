import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Pencil, Plus, Power, Truck } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { Button } from '../../components/ui/Button';
import { Input, Select } from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { vehiclesApi, vehicleTypesApi, getApiErrorMessage } from '../../api';
import { cn } from '../../utils';
import type { Vehicle } from '../../types';

// ── Mobile vehicle card ───────────────────────────────────────────────────────
function VehicleCard({
  vehicle: v,
  onToggle,
  onEdit,
  onView,
}: {
  vehicle: Vehicle;
  onToggle: () => void;
  onEdit: () => void;
  onView: () => void;
}) {
  const isActive = v.status === 'active';
  return (
    <div className={cn(
      'rounded-2xl border bg-white shadow-sm overflow-hidden',
      isActive ? 'border-slate-200' : 'border-slate-100 opacity-75',
    )}>
      <div className="flex items-center gap-3 px-4 py-3">
        <VehicleImage vehicle={v} size="sm" />
        <div className="flex-1 min-w-0">
          <p className="font-mono text-base font-bold text-slate-800">{v.plate_number}</p>
          <p className="text-xs text-slate-500 truncate">
            {v.make} {v.model}{v.color ? ` · ${v.color}` : ''}{v.year ? ` · ${v.year}` : ''}
          </p>
        </div>
        <Badge status={v.status}>{v.status}</Badge>
      </div>

      <div className="border-t border-slate-50 px-4 pb-3 pt-2.5 space-y-2">
        <div className="flex items-center gap-2 flex-wrap">
          {v.vehicle_type_name && (
            <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs text-slate-600 font-medium">{v.vehicle_type_name}</span>
          )}
          <span className="text-xs text-slate-500">
            {v.driver_name
              ? <>Assigned to <span className="font-medium text-slate-700">{v.driver_name}</span>{v.driver_phone ? ` · ${v.driver_phone}` : ''}</>
              : <span className="italic">Unassigned</span>
            }
          </span>
        </div>
        <button
          onClick={onView}
          className="flex w-full items-center justify-center gap-1.5 rounded-xl border border-slate-200 py-2.5 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-50 active:scale-[0.98]"
        >
          View Details
        </button>
        <button
          onClick={onEdit}
          className="flex w-full items-center justify-center gap-1.5 rounded-xl border border-slate-200 py-2.5 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-50 active:scale-[0.98]"
        >
          <Pencil size={14} /> Edit Details
        </button>
        <button
          onClick={onToggle}
          className={cn(
            'flex w-full items-center justify-center gap-1.5 rounded-xl border py-2.5 text-sm font-medium transition-colors active:scale-[0.98]',
            isActive
              ? 'border-red-100 text-red-500 hover:bg-red-50 active:bg-red-100'
              : 'border-green-100 text-green-600 hover:bg-green-50 active:bg-green-100',
          )}
        >
          <Power size={14} /> {isActive ? 'Deactivate' : 'Activate'}
        </button>
      </div>
    </div>
  );
}

function VehicleImage({ vehicle, size = 'md' }: { vehicle: Vehicle; size?: 'sm' | 'md' | 'lg' }) {
  const dimension = size === 'lg' ? 'h-40 w-full' : size === 'sm' ? 'h-12 w-12' : 'h-12 w-16';

  if (vehicle.photo_url) {
    return (
      <img
        src={vehicle.photo_url}
        alt={`${vehicle.make} ${vehicle.model}`}
        className={`${dimension} shrink-0 rounded-xl border border-slate-200 object-cover bg-slate-50`}
      />
    );
  }

  return (
    <div className={`${dimension} flex shrink-0 items-center justify-center rounded-xl bg-slate-100`}>
      <Truck size={size === 'lg' ? 28 : 18} className="text-slate-400" />
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export function VehiclesPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [page, setPage]     = useState(1);
  const [status, setStatus] = useState('');
  const [typeId, setTypeId] = useState('');

  const [createOpen, setCreateOpen]     = useState(false);
  const [toggleTarget, setToggleTarget] = useState<Vehicle | null>(null);
  const [editTarget, setEditTarget]     = useState<Vehicle | null>(null);
  const [detailId, setDetailId]         = useState<string | null>(null);

  const [form, setForm] = useState({
    vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '',
    photo: null as File | null,
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

  const { data: detailVehicle, isLoading: detailLoading } = useQuery({
    queryKey: ['vehicle', detailId],
    queryFn: () => vehiclesApi.show(detailId!),
    enabled: !!detailId,
  });

  const createMutation = useMutation({
    mutationFn: () => vehiclesApi.create(form),
    onSuccess: () => {
      toast('Vehicle added.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      setCreateOpen(false);
      setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '', photo: null });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const updateMutation = useMutation({
    mutationFn: () => vehiclesApi.update(editTarget!.id, {
      vehicle_type_id: form.vehicle_type_id,
      plate_number: form.plate_number,
      make: form.make,
      model: form.model,
      color: form.color,
      year: form.year,
      photo: form.photo,
    }),
    onSuccess: () => {
      toast('Vehicle updated.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      setEditTarget(null);
      setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '', photo: null });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const toggleMutation = useMutation({
    mutationFn: () => vehiclesApi.toggleStatus(toggleTarget!.id),
    onSuccess: () => {
      toast('Vehicle status updated.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      setToggleTarget(null);
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const typeOptions = [
    { value: '', label: 'All Types' },
    ...(vehicleTypes ?? []).map(t => ({ value: t.id, label: t.name })),
  ];

  const allVehicles = data?.data ?? [];

  const openEdit = (v: Vehicle) => {
    setEditTarget(v);
    setForm({
      vehicle_type_id: v.vehicle_type_id ?? '',
      plate_number: v.plate_number ?? '',
      make: v.make ?? '',
      model: v.model ?? '',
      color: v.color ?? '',
      year: v.year ?? '',
      photo: null,
    });
  };

  const columns = [
    {
      key: 'plate_number',
      header: 'Plate',
      render: (v: Vehicle) => <span className="font-mono font-bold text-slate-800 text-sm">{v.plate_number}</span>,
    },
    {
      key: 'vehicle',
      header: 'Vehicle',
      render: (v: Vehicle) => (
        <div className="flex items-center gap-3">
          <VehicleImage vehicle={v} />
          <div>
            <p className="text-sm font-medium text-slate-800">{v.make} {v.model}</p>
            <p className="text-xs text-slate-400">{v.color}{v.color && v.year ? ' · ' : ''}{v.year ?? ''}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (v: Vehicle) => <span className="text-sm text-slate-600">{v.vehicle_type_name ?? '—'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (v: Vehicle) => <Badge status={v.status}>{v.status}</Badge>,
    },
    {
      key: 'driver',
      header: 'Assigned Driver',
      render: (v: Vehicle) => v.driver_name
        ? <div><p className="text-sm text-slate-800">{v.driver_name}</p><p className="text-xs text-slate-400">{v.driver_phone}</p></div>
        : <span className="text-xs text-slate-400 italic">Unassigned</span>,
    },
    {
      key: 'actions',
      header: '',
      render: (v: Vehicle) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={e => { e.stopPropagation(); openEdit(v); }}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700"
            title="Edit"
          >
            <Pencil size={14} />
          </button>
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
        </div>
      ),
    },
  ];

  return (
    <PageWrapper
      title="Vehicles"
      subtitle="Manage the vehicle fleet"
      actions={<Button icon={<Plus size={14} />} onClick={() => setCreateOpen(true)}>Add Vehicle</Button>}
    >
      {/* ── Filter bar ──────────────────────────────────────────────────────── */}
      <div className="mb-4 flex flex-wrap gap-2">
        <select
          value={typeId}
          onChange={e => { setTypeId(e.target.value); setPage(1); }}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          {typeOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <select
          value={status}
          onChange={e => { setStatus(e.target.value); setPage(1); }}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      {/* ── Mobile card list ──────────────────────────────────────────────── */}
      <div className="md:hidden space-y-2.5">
        {isLoading ? (
          <div className="flex items-center justify-center py-16 text-sm text-slate-400">Loading…</div>
        ) : allVehicles.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-slate-400">
            <Truck size={32} className="opacity-40" />
            <p className="text-sm">No vehicles found.</p>
          </div>
        ) : allVehicles.map(v => (
          <VehicleCard
            key={v.id}
            vehicle={v}
            onToggle={() => setToggleTarget(v)}
            onEdit={() => openEdit(v)}
            onView={() => setDetailId(v.id)}
          />
        ))}
        <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
      </div>

      {/* ── Desktop table ──────────────────────────────────────────────────── */}
      <div className="hidden md:block">
        <Card padding={false}>
          <Table
            columns={columns}
            data={allVehicles}
            loading={isLoading}
            keyExtractor={v => v.id}
            emptyMessage="No vehicles found."
            onRowClick={v => setDetailId(v.id)}
          />
          <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
        </Card>
      </div>

      {/* Create vehicle modal */}
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
          <div>
            <label className="mb-1.5 block text-sm font-medium text-slate-700">Vehicle Photo (optional)</label>
            <input
              type="file"
              accept="image/*"
              onChange={e => setForm(p => ({ ...p, photo: e.target.files?.[0] ?? null }))}
              className="block w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-slate-100 file:px-3 file:py-2 file:text-sm file:font-medium file:text-slate-700 hover:file:bg-slate-200"
            />
            {form.photo && (
              <p className="mt-1 text-xs text-slate-500">Selected: {form.photo.name}</p>
            )}
          </div>
        </div>
      </Modal>

      {/* Edit vehicle modal */}
      <Modal
        open={!!editTarget}
        onClose={() => { setEditTarget(null); setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '', photo: null }); }}
        title="Edit Vehicle"
        size="md"
        footer={
          <>
            <Button
              variant="outline"
              onClick={() => { setEditTarget(null); setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '', photo: null }); }}
            >
              Cancel
            </Button>
            <Button loading={updateMutation.isPending} onClick={() => updateMutation.mutate()}>
              Save Changes
            </Button>
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
          <div>
            <label className="mb-1.5 block text-sm font-medium text-slate-700">Vehicle Photo (optional)</label>
            <input
              type="file"
              accept="image/*"
              onChange={e => setForm(p => ({ ...p, photo: e.target.files?.[0] ?? null }))}
              className="block w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-slate-100 file:px-3 file:py-2 file:text-sm file:font-medium file:text-slate-700 hover:file:bg-slate-200"
            />
            {form.photo && (
              <p className="mt-1 text-xs text-slate-500">Selected: {form.photo.name}</p>
            )}
          </div>
        </div>
      </Modal>

      <Modal
        open={!!detailId}
        onClose={() => setDetailId(null)}
        title="Vehicle Details"
        size="md"
        footer={<Button variant="outline" onClick={() => setDetailId(null)}>Close</Button>}
      >
        {detailLoading || !detailVehicle ? (
          <div className="py-10 text-center text-sm text-slate-400">Loading vehicle details...</div>
        ) : (
          <div className="space-y-5">
            <VehicleImage vehicle={detailVehicle} size="lg" />
            <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <DetailItem label="Plate Number" value={detailVehicle.plate_number} />
                <DetailItem label="Status" value={detailVehicle.status} />
                <DetailItem label="Make" value={detailVehicle.make || '—'} />
                <DetailItem label="Model" value={detailVehicle.model || '—'} />
                <DetailItem label="Color" value={detailVehicle.color || '—'} />
                <DetailItem label="Year" value={detailVehicle.year || '—'} />
                <DetailItem label="Vehicle Type" value={detailVehicle.vehicle_type_name || '—'} />
                <DetailItem
                  label="Assigned Driver"
                  value={detailVehicle.driver_name ? `${detailVehicle.driver_name}${detailVehicle.driver_phone ? ` · ${detailVehicle.driver_phone}` : ''}` : 'Unassigned'}
                />
              </div>
            </div>
            <div className="flex justify-end">
              <Button
                onClick={() => {
                  setDetailId(null);
                  openEdit(detailVehicle);
                }}
              >
                Edit Vehicle
              </Button>
            </div>
          </div>
        )}
      </Modal>

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

function DetailItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="mb-1 text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value}</p>
    </div>
  );
}
