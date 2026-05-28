import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, Car } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { vehicleTypesApi, getApiErrorMessage } from '../../api';
import { formatCurrency } from '../../utils';
import type { VehicleType } from '../../types';

const emptyForm = { name: '', description: '', base_fare: '', per_km_rate: '', per_stop_fee: '' };

export function VehicleTypesPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [modalOpen, setModalOpen]       = useState(false);
  const [editTarget, setEditTarget]     = useState<VehicleType | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<VehicleType | null>(null);
  const [form, setForm] = useState(emptyForm);

  const { data: types, isLoading } = useQuery({
    queryKey: ['vehicle-types'],
    queryFn: () => vehicleTypesApi.list(),
  });

  const setF = (k: string) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(prev => ({ ...prev, [k]: e.target.value }));

  const openCreate = () => { setEditTarget(null); setForm(emptyForm); setModalOpen(true); };
  const openEdit   = (t: VehicleType) => {
    setEditTarget(t);
    setForm({ name: t.name, description: t.description ?? '', base_fare: String(t.base_fare), per_km_rate: String(t.per_km_rate), per_stop_fee: String(t.per_stop_fee) });
    setModalOpen(true);
  };

  const saveMutation = useMutation({
    mutationFn: () => {
      const payload = { name: form.name, description: form.description, base_fare: parseFloat(form.base_fare), per_km_rate: parseFloat(form.per_km_rate), per_stop_fee: parseFloat(form.per_stop_fee) };
      return editTarget ? vehicleTypesApi.update(editTarget.id, payload) : vehicleTypesApi.create(payload);
    },
    onSuccess: () => { toast(editTarget ? 'Vehicle type updated.' : 'Vehicle type created.', 'success'); qc.invalidateQueries({ queryKey: ['vehicle-types'] }); setModalOpen(false); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => vehicleTypesApi.remove(deleteTarget!.id),
    onSuccess: () => { toast('Vehicle type removed.', 'success'); qc.invalidateQueries({ queryKey: ['vehicle-types'] }); setDeleteTarget(null); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  return (
    <PageWrapper
      title="Vehicle Types"
      subtitle="Define vehicle categories and their default pricing"
      actions={<Button icon={<Plus size={14} />} onClick={openCreate}>New Type</Button>}
    >
      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1,2,3].map(i => <div key={i} className="h-44 rounded-xl bg-white border border-slate-200 animate-pulse" />)}
        </div>
      ) : (types ?? []).length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3 text-slate-400">
          <Car size={36} className="opacity-30" />
          <p className="text-sm">No vehicle types yet.</p>
          <Button icon={<Plus size={14} />} onClick={openCreate}>New Type</Button>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {(types ?? []).map(t => (
            <div key={t.id} className="rounded-xl border border-slate-200 bg-white shadow-sm hover:shadow-md transition-shadow p-4 md:p-5">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600 shrink-0">
                    <Car size={18} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-slate-900 text-sm">{t.name}</h3>
                    <Badge status={t.is_active ? 'active' : 'inactive'} className="mt-0.5">
                      {t.is_active ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </div>
                <div className="flex gap-1 shrink-0">
                  <button onClick={() => openEdit(t)} className="flex h-8 w-8 items-center justify-center rounded-xl text-slate-400 hover:bg-slate-100 hover:text-brand-600 transition-colors">
                    <Pencil size={13} />
                  </button>
                  <button onClick={() => setDeleteTarget(t)} className="flex h-8 w-8 items-center justify-center rounded-xl text-slate-400 hover:bg-red-50 hover:text-red-600 transition-colors">
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>

              {t.description && <p className="text-xs text-slate-500 mb-3 leading-relaxed">{t.description}</p>}

              <div className="grid grid-cols-3 gap-2 pt-3 border-t border-slate-100">
                {[
                  { label: 'Base Fare', value: formatCurrency(t.base_fare) },
                  { label: 'Per km',    value: formatCurrency(t.per_km_rate) },
                  { label: 'Per stop',  value: formatCurrency(t.per_stop_fee) },
                ].map(({ label, value }) => (
                  <div key={label} className="text-center">
                    <p className="text-xs font-semibold text-slate-800">{value}</p>
                    <p className="text-[10px] text-slate-400">{label}</p>
                  </div>
                ))}
              </div>

              {t.vehicle_count !== undefined && (
                <p className="mt-3 text-xs text-slate-400 text-center border-t border-slate-50 pt-2">
                  {t.vehicle_count} vehicle{t.vehicle_count !== 1 ? 's' : ''} assigned
                </p>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Create/Edit modal */}
      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={editTarget ? `Edit — ${editTarget.name}` : 'New Vehicle Type'} size="md"
        footer={<><Button variant="outline" onClick={() => setModalOpen(false)}>Cancel</Button><Button loading={saveMutation.isPending} onClick={() => saveMutation.mutate()}>{editTarget ? 'Save Changes' : 'Create'}</Button></>}
      >
        <div className="space-y-4">
          <Input label="Name *"       value={form.name}        onChange={setF('name')}        placeholder="Sedan" />
          <Input label="Description"  value={form.description} onChange={setF('description')} placeholder="Standard 4-door vehicle" />
          <div className="grid grid-cols-3 gap-3">
            <Input label="Base Fare (₦) *"  value={form.base_fare}    onChange={setF('base_fare')}    type="number" placeholder="500" />
            <Input label="Per km (₦) *"     value={form.per_km_rate}  onChange={setF('per_km_rate')}  type="number" placeholder="150" />
            <Input label="Per stop (₦) *"   value={form.per_stop_fee} onChange={setF('per_stop_fee')} type="number" placeholder="200" />
          </div>
        </div>
      </Modal>

      <ConfirmModal open={!!deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={() => deleteMutation.mutate()}
        title="Delete Vehicle Type" message={`Delete "${deleteTarget?.name}"? This will fail if vehicles of this type exist.`}
        confirmLabel="Delete" danger loading={deleteMutation.isPending} />
    </PageWrapper>
  );
}
