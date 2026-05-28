import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, MapPin, DollarSign, ChevronRight } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Select } from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { zonesApi, vehicleTypesApi, getApiErrorMessage } from '../../api';
import { formatCurrency } from '../../utils';
import type { Zone, ZonePricing } from '../../types';

export function ZonesPage() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [zoneModal, setZoneModal]         = useState(false);
  const [editZone, setEditZone]           = useState<Zone | null>(null);
  const [deleteZone, setDeleteZone]       = useState<Zone | null>(null);
  const [pricingZone, setPricingZone]     = useState<Zone | null>(null);
  const [deletePricing, setDeletePricing] = useState<{ zoneId: string; pricing: ZonePricing } | null>(null);
  const [pricingForm, setPricingForm]     = useState({ vehicle_type_id: '', base_fare: '', per_km_rate: '', per_stop_fee: '' });
  const [zoneForm, setZoneForm]           = useState({ name: '', description: '' });

  const { data: zones } = useQuery({ queryKey: ['zones'], queryFn: () => zonesApi.list() });
  const { data: pricingData } = useQuery({ queryKey: ['zone-pricing', pricingZone?.id], queryFn: () => zonesApi.getPricing(pricingZone!.id), enabled: !!pricingZone });
  const { data: vehicleTypes } = useQuery({ queryKey: ['vehicle-types'], queryFn: () => vehicleTypesApi.list(), enabled: !!pricingZone });

  const openCreateZone = () => { setEditZone(null); setZoneForm({ name: '', description: '' }); setZoneModal(true); };
  const openEditZone   = (z: Zone) => { setEditZone(z); setZoneForm({ name: z.name, description: z.description ?? '' }); setZoneModal(true); };

  const zoneMutation = useMutation({
    mutationFn: () => editZone ? zonesApi.update(editZone.id, zoneForm) : zonesApi.create(zoneForm),
    onSuccess: () => { toast(editZone ? 'Zone updated.' : 'Zone created.', 'success'); qc.invalidateQueries({ queryKey: ['zones'] }); setZoneModal(false); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const deleteZoneMutation = useMutation({
    mutationFn: () => zonesApi.remove(deleteZone!.id),
    onSuccess: () => { toast('Zone deleted.', 'success'); qc.invalidateQueries({ queryKey: ['zones'] }); setDeleteZone(null); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const setPricingMutation = useMutation({
    mutationFn: () => zonesApi.setPricing(pricingZone!.id, { vehicle_type_id: pricingForm.vehicle_type_id, base_fare: parseFloat(pricingForm.base_fare), per_km_rate: parseFloat(pricingForm.per_km_rate), per_stop_fee: parseFloat(pricingForm.per_stop_fee) }),
    onSuccess: () => { toast('Pricing saved.', 'success'); qc.invalidateQueries({ queryKey: ['zone-pricing', pricingZone?.id] }); setPricingForm({ vehicle_type_id: '', base_fare: '', per_km_rate: '', per_stop_fee: '' }); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const deletePricingMutation = useMutation({
    mutationFn: () => zonesApi.removePricing(deletePricing!.zoneId, deletePricing!.pricing.id),
    onSuccess: () => { toast('Pricing entry removed.', 'success'); qc.invalidateQueries({ queryKey: ['zone-pricing', pricingZone?.id] }); setDeletePricing(null); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  return (
    <PageWrapper
      title="Zones & Pricing"
      subtitle="Manage geographic zones and per-zone fare overrides"
      // actions={<Button icon={<Plus size={14} />} onClick={openCreateZone}>New Zone</Button>}
    >
      {(zones ?? []).length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3 text-slate-400">
          <MapPin size={36} className="opacity-30" />
          <p className="text-sm">No zones yet. Create your first zone.</p>
          <Button icon={<Plus size={14} />} onClick={openCreateZone}>New Zone</Button>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {(zones ?? []).map(z => (
            <div key={z.id} className="rounded-xl border border-slate-200 bg-white shadow-sm hover:shadow-md transition-shadow p-4 md:p-5">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600 shrink-0">
                    <MapPin size={18} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-slate-900 text-sm">{z.name}</h3>
                    <div className="flex gap-1.5 mt-0.5 flex-wrap">
                      {z.is_default && <Badge className="bg-indigo-100 text-indigo-700">Default</Badge>}
                      <Badge status={z.is_active ? 'active' : 'inactive'}>{z.is_active ? 'Active' : 'Inactive'}</Badge>
                    </div>
                  </div>
                </div>
                <div className="flex gap-1 shrink-0">
                  <button onClick={() => openEditZone(z)} className="flex h-8 w-8 items-center justify-center rounded-xl text-slate-400 hover:bg-slate-100 hover:text-brand-600 transition-colors">
                    <Pencil size={13} />
                  </button>
                  {!z.is_default && (
                    <button onClick={() => setDeleteZone(z)} className="flex h-8 w-8 items-center justify-center rounded-xl text-slate-400 hover:bg-red-50 hover:text-red-600 transition-colors">
                      <Trash2 size={13} />
                    </button>
                  )}
                </div>
              </div>

              {z.description && <p className="text-xs text-slate-500 mb-3">{z.description}</p>}

              <div className="flex items-center justify-between pt-3 border-t border-slate-100">
                <span className="text-xs text-slate-400">{z.pricing_entries ?? 0} pricing entries</span>
                <button
                  onClick={() => setPricingZone(z)}
                  className="flex items-center gap-1 rounded-lg bg-brand-50 px-2.5 py-1.5 text-xs text-brand-600 hover:bg-brand-100 font-medium transition-colors"
                >
                  <DollarSign size={12} /> Manage Pricing <ChevronRight size={12} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Zone create/edit */}
      <Modal open={zoneModal} onClose={() => setZoneModal(false)} title={editZone ? `Edit Zone — ${editZone.name}` : 'New Zone'} size="sm"
        footer={<><Button variant="outline" onClick={() => setZoneModal(false)}>Cancel</Button><Button loading={zoneMutation.isPending} onClick={() => zoneMutation.mutate()}>{editZone ? 'Save Changes' : 'Create Zone'}</Button></>}
      >
        <div className="space-y-4">
          <Input label="Zone Name *" value={zoneForm.name} onChange={e => setZoneForm(p => ({ ...p, name: e.target.value }))} placeholder="GRA Premium Zone" />
          <Input label="Description" value={zoneForm.description} onChange={e => setZoneForm(p => ({ ...p, description: e.target.value }))} placeholder="Optional description" />
        </div>
      </Modal>

      <ConfirmModal open={!!deleteZone} onClose={() => setDeleteZone(null)} onConfirm={() => deleteZoneMutation.mutate()}
        title="Delete Zone" message={`Delete zone "${deleteZone?.name}" and all its pricing entries?`}
        confirmLabel="Delete" danger loading={deleteZoneMutation.isPending} />

      {/* Pricing management modal */}
      <Modal open={!!pricingZone} onClose={() => setPricingZone(null)} title={`Pricing — ${pricingZone?.name}`} size="lg">
        {(pricingData?.pricing ?? []).length > 0 && (
          <div className="mb-5">
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Current Pricing</p>
            <div className="space-y-2">
              {pricingData!.pricing.map(p => (
                <div key={p.id} className="flex items-center gap-3 rounded-xl bg-slate-50 p-3">
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-slate-800">{p.vehicle_type_name}</p>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Base {formatCurrency(p.base_fare)} · /km {formatCurrency(p.per_km_rate)} · /stop {formatCurrency(p.per_stop_fee)}
                    </p>
                  </div>
                  <button onClick={() => setDeletePricing({ zoneId: pricingZone!.id, pricing: p })}
                    className="flex h-8 w-8 items-center justify-center rounded-xl text-slate-400 hover:bg-red-50 hover:text-red-600 transition-colors">
                    <Trash2 size={13} />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}
        <div className="border-t border-slate-200 pt-4">
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Set Pricing for a Vehicle Type</p>
          <div className="space-y-3">
            <Select label="Vehicle Type *" value={pricingForm.vehicle_type_id} onChange={e => setPricingForm(p => ({ ...p, vehicle_type_id: e.target.value }))} placeholder="Select type…"
              options={(vehicleTypes ?? []).map(t => ({ value: t.id, label: t.name }))} />
            <div className="grid grid-cols-3 gap-3">
              <Input label="Base Fare (₦)"  value={pricingForm.base_fare}    onChange={e => setPricingForm(p => ({ ...p, base_fare: e.target.value }))}    type="number" placeholder="500" />
              <Input label="Per km (₦)"     value={pricingForm.per_km_rate}  onChange={e => setPricingForm(p => ({ ...p, per_km_rate: e.target.value }))}  type="number" placeholder="150" />
              <Input label="Per stop (₦)"   value={pricingForm.per_stop_fee} onChange={e => setPricingForm(p => ({ ...p, per_stop_fee: e.target.value }))} type="number" placeholder="200" />
            </div>
            <Button loading={setPricingMutation.isPending} disabled={!pricingForm.vehicle_type_id} onClick={() => setPricingMutation.mutate()} className="w-full">
              Save Pricing
            </Button>
          </div>
        </div>
      </Modal>

      <ConfirmModal open={!!deletePricing} onClose={() => setDeletePricing(null)} onConfirm={() => deletePricingMutation.mutate()}
        title="Remove Pricing Entry" message={`Remove pricing for "${deletePricing?.pricing.vehicle_type_name}"?`}
        confirmLabel="Remove" danger loading={deletePricingMutation.isPending} />
    </PageWrapper>
  );
}
