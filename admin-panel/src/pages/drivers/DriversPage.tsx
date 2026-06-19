import { useState, useRef, useCallback, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Plus, Search, Power, Camera, Eye, ChevronDown,
  ChevronUp, CheckCircle, XCircle, AlertCircle, Car,
  Shield, FileText, Upload, X, Users,
} from 'lucide-react';
import { PageWrapper }    from '../../components/layout/PageWrapper';
import { Card }           from '../../components/ui/Card';
import { Table }          from '../../components/ui/Table';
import { Badge }          from '../../components/ui/Badge';
import { Pagination }     from '../../components/ui/Pagination';
import { Button }         from '../../components/ui/Button';
import { Input, Select }  from '../../components/ui/Input';
import { Modal, ConfirmModal } from '../../components/ui/Modal';
import { useToast }       from '../../components/ui/Toast';
import { driversApi, vehiclesApi, vehicleTypesApi, getApiErrorMessage } from '../../api';
import { formatDateTime } from '../../utils';
import { cn }             from '../../utils';
import type { Driver, KycStatus } from '../../types';

// ── Shared helpers ────────────────────────────────────────────────────────────
function Avatar({ url, name, size = 'md' }: { url?: string | null; name: string; size?: 'sm' | 'md' | 'lg' }) {
  const dim = size === 'lg' ? 'h-20 w-20 text-2xl' : size === 'md' ? 'h-10 w-10 text-sm' : 'h-8 w-8 text-xs';
  if (url) return <img src={url} alt={name} className={`${dim} rounded-full object-cover border-2 border-white shadow`} />;
  return (
    <div className={`${dim} rounded-full bg-brand-100 text-brand-700 font-bold flex items-center justify-center shrink-0`}>
      {name.charAt(0).toUpperCase()}
    </div>
  );
}

const KYC_COLORS: Record<KycStatus, string> = {
  not_submitted: 'text-slate-400 bg-slate-100',
  pending:       'text-amber-700 bg-amber-100',
  verified:      'text-green-700 bg-green-100',
  rejected:      'text-red-700 bg-red-100',
};
const KYC_LABELS: Record<KycStatus, string> = {
  not_submitted: 'No KYC',
  pending:       'KYC Pending',
  verified:      'KYC Verified',
  rejected:      'KYC Rejected',
};

const DRIVING_EXPERIENCE_OPTIONS = [
  { value: 'Less than 1 year', label: 'Less than 1 year' },
  { value: '1 - 2 years', label: '1 - 2 years' },
  { value: '3 - 5 years', label: '3 - 5 years' },
  { value: '5+ years', label: '5+ years' },
];

function KycBadge({ status }: { status: KycStatus }) {
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium ${KYC_COLORS[status]}`}>
      {status === 'verified'  && <CheckCircle size={10} />}
      {status === 'rejected'  && <XCircle size={10} />}
      {status === 'pending'   && <AlertCircle size={10} />}
      {KYC_LABELS[status]}
    </span>
  );
}

// ── Photo upload ──────────────────────────────────────────────────────────────
function PhotoUpload({ value, onChange, label = 'Photo' }: {
  value: File | null; onChange: (f: File | null) => void; label?: string;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const preview  = value ? URL.createObjectURL(value) : null;
  return (
    <div className="flex items-center gap-4">
      <div
        onClick={() => inputRef.current?.click()}
        className="relative h-16 w-16 rounded-full border-2 border-dashed border-slate-300 cursor-pointer hover:border-brand-500 transition-colors flex items-center justify-center overflow-hidden bg-slate-50"
      >
        {preview
          ? <img src={preview} className="h-full w-full object-cover" alt="preview" />
          : <Camera size={20} className="text-slate-400" />
        }
        {preview && (
          <button type="button" onClick={e => { e.stopPropagation(); onChange(null); }}
            className="absolute top-0 right-0 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-white">
            <X size={10} />
          </button>
        )}
      </div>
      <div>
        <p className="text-sm font-medium text-slate-700">{label}</p>
        <button type="button" onClick={() => inputRef.current?.click()} className="text-xs text-brand-600 hover:text-brand-700">
          {preview ? 'Change photo' : 'Upload photo'}
        </button>
      </div>
      <input ref={inputRef} type="file" accept="image/*" className="hidden"
        onChange={e => onChange(e.target.files?.[0] ?? null)} />
    </div>
  );
}

// ── KYC document upload ───────────────────────────────────────────────────────
function DocUpload({ value, onChange, label }: { value: File | null; onChange: (f: File | null) => void; label: string }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const preview  = value ? URL.createObjectURL(value) : null;
  return (
    <div>
      <p className="text-xs font-medium text-slate-600 mb-1">{label}</p>
      <div
        onClick={() => inputRef.current?.click()}
        className="relative h-24 rounded-xl border-2 border-dashed border-slate-200 cursor-pointer hover:border-brand-400 transition-colors flex flex-col items-center justify-center gap-1 bg-slate-50 overflow-hidden"
      >
        {preview
          ? <img src={preview} className="h-full w-full object-cover rounded-xl" alt={label} />
          : <><Upload size={16} className="text-slate-400" /><span className="text-xs text-slate-400">Click to upload</span></>
        }
        {value && (
          <button type="button" onClick={e => { e.stopPropagation(); onChange(null); }}
            className="absolute top-1 right-1 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-white">
            <X size={10} />
          </button>
        )}
      </div>
      <input ref={inputRef} type="file" accept="image/*" className="hidden"
        onChange={e => onChange(e.target.files?.[0] ?? null)} />
    </div>
  );
}

// ── Quick Add Vehicle Modal ────────────────────────────────────────────────────
function QuickAddVehicleModal({ open, onClose, onCreated }: {
  open: boolean; onClose: () => void;
  onCreated: (id: string, label: string) => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [form, setForm] = useState({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '' });
  const sf = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(p => ({ ...p, [k]: e.target.value }));

  const { data: types } = useQuery({ queryKey: ['vehicle-types'], queryFn: () => vehicleTypesApi.list(), enabled: open });

  const mutation = useMutation({
    mutationFn: () => vehiclesApi.create({ vehicle_type_id: form.vehicle_type_id, plate_number: form.plate_number, make: form.make, model: form.model, color: form.color, year: form.year || undefined }),
    onSuccess: (res) => {
      toast('Vehicle created.', 'success');
      qc.invalidateQueries({ queryKey: ['vehicles'] });
      onCreated(res.id, `${form.plate_number} — ${form.make} ${form.model}`);
      setForm({ vehicle_type_id: '', plate_number: '', make: '', model: '', color: '', year: '' });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  return (
    <Modal open={open} onClose={onClose} title="Add Vehicle" size="sm"
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={mutation.isPending} disabled={!form.plate_number || !form.make || !form.model || !form.vehicle_type_id} onClick={() => mutation.mutate()}>Create & Select</Button></>}
    >
      <div className="space-y-3">
        <Select label="Vehicle Type *" value={form.vehicle_type_id} onChange={sf('vehicle_type_id')} placeholder="Select type…" options={(types ?? []).map((t: { id: string; name: string }) => ({ value: t.id, label: t.name }))} />
        <div className="grid grid-cols-2 gap-3">
          <Input label="Plate Number *" value={form.plate_number} onChange={sf('plate_number')} placeholder="KWR-123-AB" />
          <Input label="Year"           value={form.year}         onChange={sf('year')}         placeholder="2020" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Input label="Make *"  value={form.make}  onChange={sf('make')}  placeholder="Toyota" />
          <Input label="Model *" value={form.model} onChange={sf('model')} placeholder="Corolla" />
        </div>
        <Input label="Color" value={form.color} onChange={sf('color')} placeholder="White" />
      </div>
    </Modal>
  );
}

// ── Create Driver Modal ───────────────────────────────────────────────────────
function CreateDriverModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [form, setForm] = useState({ name: '', phone: '', email: '', password: '', license_number: '', vehicle_id: '' });
  const sf = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(p => ({ ...p, [k]: e.target.value }));
  const [photo, setPhoto]         = useState<File | null>(null);
  const [kycOpen, setKycOpen]     = useState(false);
  const [kycIdType, setKycIdType] = useState('');
  const [kycIdNum, setKycIdNum]   = useState('');
  const [drivingExperience, setDrivingExperience] = useState('');
  const [kycFront, setKycFront]   = useState<File | null>(null);
  const [kycBack, setKycBack]     = useState<File | null>(null);
  const [showPass, setShowPass]   = useState(false);
  const [addVehicleOpen, setAddVehicleOpen] = useState(false);

  const { data: vehicles } = useQuery({ queryKey: ['vehicles', 'active'], queryFn: () => vehiclesApi.list({ status: 'active' }), enabled: open });
  const [extraVehicles, setExtraVehicles] = useState<{ value: string; label: string }[]>([]);

  const reset = useCallback(() => {
    setForm({ name: '', phone: '', email: '', password: '', license_number: '', vehicle_id: '' });
    setPhoto(null); setKycOpen(false); setKycIdType(''); setKycIdNum(''); setDrivingExperience('');
    setKycFront(null); setKycBack(null); setExtraVehicles([]);
  }, []);

  const mutation = useMutation({
    mutationFn: () => driversApi.create({
      name: form.name, phone: form.phone, email: form.email || undefined,
      password: form.password, license_number: form.license_number || undefined,
      vehicle_id: form.vehicle_id || undefined, photo: photo || undefined,
      kyc_id_type: kycIdType || undefined, kyc_id_number: kycIdNum || undefined,
      driving_experience: drivingExperience || undefined,
      kyc_id_front: kycFront || undefined, kyc_id_back: kycBack || undefined,
    }),
    onSuccess: () => {
      toast('Driver created successfully.', 'success');
      qc.invalidateQueries({ queryKey: ['drivers'] });
      reset(); onClose();
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const vehicleOptions = [
    ...(vehicles?.data ?? []).map(v => ({ value: v.id, label: `${v.plate_number} — ${v.make} ${v.model}` })),
    ...extraVehicles,
  ];

  return (
    <>
      <Modal open={open} onClose={() => { reset(); onClose(); }} title="Add New Driver" size="lg"
        footer={<><Button variant="outline" onClick={() => { reset(); onClose(); }}>Cancel</Button><Button loading={mutation.isPending} disabled={!form.name || !form.phone || !form.password} onClick={() => mutation.mutate()}>Create Driver</Button></>}
      >
        <div className="space-y-6">
          <PhotoUpload value={photo} onChange={setPhoto} label="Driver Photo (optional)" />

          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Basic Information</p>
            <div className="grid grid-cols-2 gap-3">
              <Input label="Full Name *"    value={form.name}           onChange={sf('name')}           placeholder="Musa Aliyu" />
              <Input label="Phone *"        value={form.phone}          onChange={sf('phone')}          placeholder="08055555555" />
              <Input label="Email"          value={form.email}          onChange={sf('email')}          type="email" placeholder="driver@email.com" />
              <Input label="License Number" value={form.license_number} onChange={sf('license_number')} placeholder="KWR-DL-123456" />
            </div>
            <div className="mt-3 relative">
              <Input label="Password *" value={form.password} onChange={sf('password')} type={showPass ? 'text' : 'password'} placeholder="Min 6 characters" />
              <button type="button" onClick={() => setShowPass(s => !s)} className="absolute right-3 top-7 text-xs text-slate-400 hover:text-slate-600">
                {showPass ? 'Hide' : 'Show'}
              </button>
            </div>
          </div>

          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Vehicle Assignment (optional)</p>
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Select label="Assign Vehicle" value={form.vehicle_id} onChange={sf('vehicle_id')} placeholder="Select a vehicle or add new…" options={vehicleOptions} />
              </div>
              <button type="button" onClick={() => setAddVehicleOpen(true)}
                className="mb-0.5 flex items-center gap-1.5 rounded-xl border border-brand-500 px-3 py-2 text-sm text-brand-600 hover:bg-brand-50 transition-colors whitespace-nowrap">
                <Plus size={14} /> Add Vehicle
              </button>
            </div>
            {form.vehicle_id && <p className="mt-1.5 flex items-center gap-1.5 text-xs text-green-600"><Car size={12} /> Vehicle selected — will be assigned on save.</p>}
          </div>

          <div className="rounded-xl border border-slate-200 overflow-hidden">
            <button type="button" onClick={() => setKycOpen(s => !s)}
              className="flex w-full items-center justify-between px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors">
              <span className="flex items-center gap-2">
                <Shield size={14} className="text-slate-400" />
                KYC Details
                <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] text-slate-500">Optional</span>
              </span>
              {kycOpen ? <ChevronUp size={16} className="text-slate-400" /> : <ChevronDown size={16} className="text-slate-400" />}
            </button>
            {kycOpen && (
              <div className="px-4 pb-4 border-t border-slate-100 pt-4 space-y-3 bg-slate-50/50">
                <div className="grid grid-cols-2 gap-3">
                  <Select label="ID Type" value={kycIdType} onChange={e => setKycIdType(e.target.value)} placeholder="Select ID type…"
                    options={[{ value: 'NIN', label: 'NIN' }, { value: "Driver's License", label: "Driver's License" }, { value: "Voter's Card", label: "Voter's Card" }, { value: 'International Passport', label: 'International Passport' }]} />
                  <Input label="ID Number" value={kycIdNum} onChange={e => setKycIdNum(e.target.value)} placeholder="Enter ID number" />
                </div>
                <Select
                  label="Driving Experience"
                  value={drivingExperience}
                  onChange={e => setDrivingExperience(e.target.value)}
                  placeholder="Select experience…"
                  options={DRIVING_EXPERIENCE_OPTIONS}
                />
                <div className="grid grid-cols-2 gap-3">
                  <DocUpload label="ID Front" value={kycFront} onChange={setKycFront} />
                  <DocUpload label="ID Back"  value={kycBack}  onChange={setKycBack} />
                </div>
              </div>
            )}
          </div>
        </div>
      </Modal>
      <QuickAddVehicleModal open={addVehicleOpen} onClose={() => setAddVehicleOpen(false)}
        onCreated={(id, label) => { setExtraVehicles(prev => [...prev, { value: id, label }]); setForm(p => ({ ...p, vehicle_id: id })); setAddVehicleOpen(false); }} />
    </>
  );
}

// ── KYC Panel ─────────────────────────────────────────────────────────────────
function KycPanel({ driver, onUpdated }: { driver: Driver; onUpdated: () => void }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [currentStatus, setCurrentStatus] = useState<KycStatus>(driver.kyc_status);
  const [note, setNote]       = useState(driver.kyc_note ?? '');
  const [front, setFront]     = useState<File | null>(null);
  const [back, setBack]       = useState<File | null>(null);
  const [profilePhoto, setProfilePhoto] = useState<File | null>(null);
  const [kycIdType, setType]  = useState(driver.kyc_id_type ?? '');
  const [kycIdNum, setNum]    = useState(driver.kyc_id_number ?? '');
  const [drivingExperience, setDrivingExperience] = useState(driver.driving_experience ?? '');

  useEffect(() => {
    setCurrentStatus(driver.kyc_status);
    setNote(driver.kyc_note ?? '');
    setType(driver.kyc_id_type ?? '');
    setNum(driver.kyc_id_number ?? '');
    setDrivingExperience(driver.driving_experience ?? '');
  }, [driver]);

  const mutation = useMutation({
    mutationFn: (status: KycStatus) => driversApi.updateKyc(driver.id, {
      kyc_status: status,
      kyc_note: note.trim(),
      kyc_id_type: kycIdType,
      kyc_id_number: kycIdNum,
      driving_experience: drivingExperience,
      kyc_id_front: front || undefined,
      kyc_id_back: back || undefined,
      profile_photo: profilePhoto || undefined,
    }),
    onSuccess: (updated, status) => {
      const resolvedNote = updated.kyc_note ?? (note.trim() || null);
      const resolvedExperience = updated.driving_experience ?? (drivingExperience || null);
      setCurrentStatus(updated.kyc_status ?? status);
      setNote(resolvedNote ?? '');
      qc.setQueryData<Driver>(['driver', driver.id], current => current ? ({
        ...current,
        kyc_status: updated.kyc_status ?? status,
        kyc_note: resolvedNote,
        driving_experience: resolvedExperience,
        photo_url: updated.photo_url ?? current.photo_url,
        profile_photo_url: updated.photo_url ?? current.profile_photo_url,
        kyc_front_url: updated.kyc_front_url ?? current.kyc_front_url,
        kyc_back_url: updated.kyc_back_url ?? current.kyc_back_url,
      }) : current);
      toast(
        status === 'verified'
          ? 'Driver KYC verified.'
          : status === 'rejected'
              ? 'Driver KYC rejected.'
              : 'KYC updated.',
        'success',
      );
      onUpdated();
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const handleSubmit = (status: KycStatus) => {
    if (status === 'rejected' && note.trim() === '') {
      toast('Enter a rejection reason before rejecting this KYC.', 'error');
      return;
    }
    mutation.mutate(status);
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between"><KycBadge status={currentStatus} /></div>
      <div className="rounded-xl border border-slate-200 bg-slate-50 p-3">
        <div className="mb-3 flex items-center gap-3">
          <Avatar url={driver.photo_url} name={driver.name} size="md" />
          <div>
            <p className="text-sm font-medium text-slate-800">Profile Photo</p>
            <p className="text-xs text-slate-500">Used as the driver's avatar in the apps.</p>
          </div>
        </div>
        <PhotoUpload value={profilePhoto} onChange={setProfilePhoto} label="Replace profile photo" />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Select label="ID Type" value={kycIdType} onChange={e => setType(e.target.value)} placeholder="Select…"
          options={[{ value: 'NIN', label: 'NIN' }, { value: "Driver's License", label: "Driver's License" }, { value: "Voter's Card", label: "Voter's Card" }, { value: 'International Passport', label: 'International Passport' }]} />
        <Input label="ID Number" value={kycIdNum} onChange={e => setNum(e.target.value)} placeholder="ID number" />
      </div>
      <Select
        label="Driving Experience"
        value={drivingExperience}
        onChange={e => setDrivingExperience(e.target.value)}
        placeholder="Select driving experience…"
        options={DRIVING_EXPERIENCE_OPTIONS}
      />
      <div className="grid grid-cols-2 gap-3">
        <div>
          <DocUpload label="ID Front" value={front} onChange={setFront} />
          {!front && driver.kyc_front_url && <a href={driver.kyc_front_url} target="_blank" rel="noreferrer" className="mt-1 flex items-center gap-1 text-xs text-brand-600 hover:underline"><Eye size={10} /> View current</a>}
        </div>
        <div>
          <DocUpload label="ID Back" value={back} onChange={setBack} />
          {!back && driver.kyc_back_url && <a href={driver.kyc_back_url} target="_blank" rel="noreferrer" className="mt-1 flex items-center gap-1 text-xs text-brand-600 hover:underline"><Eye size={10} /> View current</a>}
        </div>
      </div>
      <div>
        <label className="text-xs font-medium text-slate-600">Admin Note (optional)</label>
        <textarea value={note} onChange={e => setNote(e.target.value)} rows={2} placeholder="Reason for rejection, etc."
          className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none" />
      </div>
      <div className="flex gap-2">
        <button onClick={() => handleSubmit('verified')} disabled={mutation.isPending}
          className="flex items-center gap-1.5 rounded-xl bg-green-600 px-3 py-2 text-sm font-medium text-white hover:bg-green-700 transition-colors disabled:opacity-60">
          <CheckCircle size={14} /> Verify
        </button>
        <button onClick={() => handleSubmit('rejected')} disabled={mutation.isPending}
          className="flex items-center gap-1.5 rounded-xl bg-red-500 px-3 py-2 text-sm font-medium text-white hover:bg-red-600 transition-colors disabled:opacity-60">
          <XCircle size={14} /> Reject
        </button>
        <button onClick={() => handleSubmit(currentStatus)} disabled={mutation.isPending}
          className="flex items-center gap-1.5 rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 transition-colors disabled:opacity-60">
          Save
        </button>
      </div>
    </div>
  );
}

// ── Edit Driver Panel ─────────────────────────────────────────────────────────
function EditDriverPanel({ driver, onUpdated }: { driver: Driver; onUpdated: () => void }) {
  const { toast } = useToast();
  const qc        = useQueryClient();

  const [form, setForm] = useState({
    name:           driver.name,
    phone:          driver.phone,
    email:          driver.email ?? '',
    license_number: driver.license_number ?? '',
    password:       '',
  });
  const [photo,       setPhoto]       = useState<File | null>(null);
  const [showPass,    setShowPass]    = useState(false);
  const [vehicleId,   setVehicleId]   = useState('');
  const [addVehicleOpen, setAddVehicleOpen] = useState(false);
  const [extraVehicles,  setExtraVehicles]  = useState<{ value: string; label: string }[]>([]);

  const sf = (k: keyof typeof form) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setForm(p => ({ ...p, [k]: e.target.value }));

  const { data: vehicles } = useQuery({
    queryKey: ['vehicles', 'active'],
    queryFn:  () => vehiclesApi.list({ status: 'active' }),
  });

  // Build options with assignment status — free vehicles first, then assigned to others.
  const vehicleOptions = [
    ...(vehicles?.data ?? [])
      .slice()
      .sort((a, b) => {
        if (a.driver_id === driver.id)              return -1; // this driver's current vehicle → top
        if (b.driver_id === driver.id)              return  1;
        if (!a.driver_id && b.driver_id)            return -1; // free before assigned-to-other
        if (a.driver_id && !b.driver_id)            return  1;
        return 0;
      })
      .map(v => {
        const base = `${v.plate_number} — ${v.make} ${v.model}${v.color ? ` (${v.color})` : ''}`;
        if (v.driver_id === driver.id)
          return { value: v.id, label: `✓ ${base} · this driver` };
        if (v.driver_id && v.driver_name)
          return { value: v.id, label: `⚠ ${base} · assigned to ${v.driver_name}` };
        return { value: v.id, label: `● ${base} · free` };
      }),
    ...extraVehicles,
  ];

  const updateMutation = useMutation({
    mutationFn: () => driversApi.update(driver.id, {
      name:           form.name           || undefined,
      email:          form.email          || undefined,
      license_number: form.license_number || undefined,
      photo:          photo               || undefined,
      ...(form.password ? { password: form.password } : {}),
    } as Parameters<typeof driversApi.update>[1]),
    onSuccess: () => { toast('Driver updated.', 'success'); qc.invalidateQueries({ queryKey: ['drivers'] }); onUpdated(); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const assignMutation = useMutation({
    mutationFn: (vid: string) => driversApi.assignVehicle(driver.id, vid),
    onSuccess: (_r, vid) => {
      toast(vid ? 'Vehicle assigned.' : 'Vehicle detached.', 'success');
      qc.invalidateQueries({ queryKey: ['drivers'] });
      onUpdated();
      setVehicleId('');
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const hasVehicle = !!(driver.plate_number || driver.vehicle_id);

  return (
    <>
      <div className="space-y-5">
        {/* Photo */}
        <PhotoUpload value={photo} onChange={setPhoto} label="Driver Photo" />

        {/* Basic fields */}
        <div>
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Basic Information</p>
          <div className="grid grid-cols-2 gap-3">
            <Input label="Full Name *"    value={form.name}           onChange={sf('name')}           placeholder="Musa Aliyu" />
            <Input label="Phone *"        value={form.phone}          onChange={sf('phone')}          placeholder="08055555555" />
            <Input label="Email"          value={form.email}          onChange={sf('email')}          type="email" placeholder="driver@email.com" />
            <Input label="License Number" value={form.license_number} onChange={sf('license_number')} placeholder="KWR-DL-123456" />
          </div>
          <div className="mt-3 relative">
            <Input label="New Password (leave blank to keep current)" value={form.password} onChange={sf('password')} type={showPass ? 'text' : 'password'} placeholder="Min 6 characters" />
            <button type="button" onClick={() => setShowPass(s => !s)} className="absolute right-3 top-7 text-xs text-slate-400 hover:text-slate-600">
              {showPass ? 'Hide' : 'Show'}
            </button>
          </div>
        </div>

        <Button loading={updateMutation.isPending} disabled={!form.name || !form.phone} onClick={() => updateMutation.mutate()}>
          Save Changes
        </Button>

        {/* Vehicle assignment / detach */}
        <div className="border-t border-slate-100 pt-5">
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3 flex items-center gap-1.5">
            <Car size={13} /> Vehicle Assignment
          </p>

          {hasVehicle && (
            <div className="mb-3 flex items-center justify-between rounded-xl bg-blue-50 border border-blue-100 px-3 py-2.5">
              <div>
                <p className="text-xs text-blue-500 font-medium">Currently Assigned</p>
                <p className="text-sm font-semibold text-blue-900">
                  {driver.plate_number} — {driver.make} {driver.model}
                </p>
              </div>
              <button
                onClick={() => assignMutation.mutate('')}
                disabled={assignMutation.isPending}
                className="flex items-center gap-1 rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-100 transition-colors disabled:opacity-60"
              >
                <X size={11} /> Detach
              </button>
            </div>
          )}

          <div className="flex items-end gap-2">
            <div className="flex-1">
              <Select
                label={hasVehicle ? 'Replace Vehicle' : 'Assign Vehicle'}
                value={vehicleId}
                onChange={e => setVehicleId(e.target.value)}
                placeholder="Select a vehicle…"
                options={vehicleOptions}
              />
            </div>
            <button type="button" onClick={() => setAddVehicleOpen(true)}
              className="mb-0.5 flex items-center gap-1.5 rounded-xl border border-brand-500 px-3 py-2 text-sm text-brand-600 hover:bg-brand-50 transition-colors whitespace-nowrap">
              <Plus size={14} /> New
            </button>
          </div>
          {vehicleId && (
            <Button
              className="mt-2 w-full"
              loading={assignMutation.isPending}
              onClick={() => assignMutation.mutate(vehicleId)}
            >
              {hasVehicle ? 'Replace Vehicle' : 'Assign Vehicle'}
            </Button>
          )}
        </div>
      </div>

      <QuickAddVehicleModal
        open={addVehicleOpen}
        onClose={() => setAddVehicleOpen(false)}
        onCreated={(id, label) => {
          setExtraVehicles(prev => [...prev, { value: id, label }]);
          setVehicleId(id);
          setAddVehicleOpen(false);
        }}
      />
    </>
  );
}

// ── Driver Detail Modal ───────────────────────────────────────────────────────
function DriverDetailModal({ driverId, onClose }: { driverId: string; onClose: () => void }) {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState<'info' | 'kyc' | 'edit'>('info');

  const { data, isLoading, refetch } = useQuery({ queryKey: ['driver', driverId], queryFn: () => driversApi.show(driverId) });

  const toggleMutation = useMutation({
    mutationFn: () => driversApi.toggleStatus(driverId),
    onSuccess: () => { toast('Status updated.', 'success'); qc.invalidateQueries({ queryKey: ['drivers'] }); refetch(); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  if (isLoading) return <Modal open onClose={onClose} title="Driver Detail" size="md"><p className="py-8 text-center text-sm text-slate-400">Loading…</p></Modal>;
  if (!data) return null;

  return (
    <Modal open onClose={onClose} title="Driver Detail" size="lg">
      <div className="flex items-start gap-4 mb-5 pb-5 border-b border-slate-100">
        <Avatar url={data.photo_url} name={data.name} size="lg" />
        <div className="flex-1 min-w-0">
          <h2 className="text-lg font-semibold text-slate-900">{data.name}</h2>
          <p className="text-sm text-slate-500">{data.phone}{data.email ? ` · ${data.email}` : ''}</p>
          <div className="flex items-center gap-2 mt-2 flex-wrap">
            <Badge status={data.is_active ? 'active' : 'inactive'}>{data.is_active ? 'Active' : 'Inactive'}</Badge>
            <Badge status={data.is_online ? 'online' : 'offline'} dot>{data.is_online ? 'Online' : 'Offline'}</Badge>
            <KycBadge status={data.kyc_status} />
          </div>
        </div>
        <button onClick={() => toggleMutation.mutate()} disabled={toggleMutation.isPending}
          className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-medium transition-colors ${data.is_active ? 'bg-red-50 text-red-600 hover:bg-red-100' : 'bg-green-50 text-green-700 hover:bg-green-100'}`}>
          <Power size={12} /> {data.is_active ? 'Deactivate' : 'Activate'}
        </button>
      </div>

      <div className="flex border-b border-slate-200 mb-5 -mx-1">
        {([['info', 'Profile & Stats'], ['edit', 'Edit Driver'], ['kyc', 'KYC Documents']] as const).map(([key, label]) => (
          <button key={key} onClick={() => setActiveTab(key)}
            className={`px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px ${activeTab === key ? 'border-brand-500 text-brand-600' : 'border-transparent text-slate-500 hover:text-slate-700'}`}>
            {label}
          </button>
        ))}
      </div>

      {activeTab === 'info' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: 'License No.', value: data.license_number ?? '—' },
              { label: 'Joined',      value: formatDateTime(data.created_at) },
              { label: 'Last Seen',   value: data.last_seen ? formatDateTime(data.last_seen) : '—' },
            ].map(({ label, value }) => (
              <div key={label} className="rounded-xl bg-slate-50 p-3">
                <p className="text-xs text-slate-400">{label}</p>
                <p className="text-sm font-medium text-slate-800 mt-0.5">{value}</p>
              </div>
            ))}
          </div>
          {(data.plate_number || data.make) && (
            <div className="rounded-xl bg-blue-50 border border-blue-100 p-3">
              <p className="text-xs text-blue-500 font-medium mb-1 flex items-center gap-1"><Car size={11} /> Assigned Vehicle</p>
              <p className="text-sm font-medium text-blue-900">
                {data.plate_number} — {data.make} {data.model}{data.color ? ` (${data.color})` : ''}{data.vehicle_type ? ` · ${data.vehicle_type}` : ''}
              </p>
            </div>
          )}
          {data.stats && (
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">Trip Statistics</p>
              <div className="grid grid-cols-3 gap-2">
                {[{ label: 'Total', value: data.stats.total ?? 0 }, { label: 'Completed', value: data.stats.completed ?? 0 }, { label: 'Cancelled', value: data.stats.cancelled ?? 0 }].map(({ label, value }) => (
                  <div key={label} className="rounded-xl bg-slate-50 p-3 text-center">
                    <p className="text-xl font-bold text-slate-900">{value}</p>
                    <p className="text-xs text-slate-400">{label}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
      {activeTab === 'edit' && <EditDriverPanel driver={data} onUpdated={() => { refetch(); qc.invalidateQueries({ queryKey: ['drivers'] }); }} />}
      {activeTab === 'kyc'  && <KycPanel driver={data} onUpdated={() => { refetch(); qc.invalidateQueries({ queryKey: ['drivers'] }); }} />}
    </Modal>
  );
}

// ── Mobile driver card ────────────────────────────────────────────────────────
function DriverCard({ driver: d, onView, onToggle }: {
  driver: Driver; onView: () => void; onToggle: () => void;
}) {
  return (
    <div className={cn(
      'rounded-2xl border bg-white shadow-sm overflow-hidden',
      d.is_active ? 'border-slate-200' : 'border-slate-100 opacity-75',
    )}>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3">
        <Avatar url={d.photo_url} name={d.name} size="md" />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <p className="text-sm font-semibold text-slate-900 truncate">{d.name}</p>
            <span className={cn('h-2 w-2 rounded-full shrink-0', Number(d.is_online) ? 'bg-green-400' : 'bg-slate-300')} />
          </div>
          <p className="text-xs text-slate-400">{d.phone}</p>
        </div>
        <Badge status={d.is_active ? 'active' : 'inactive'}>{d.is_active ? 'Active' : 'Inactive'}</Badge>
      </div>

      {/* Details */}
      <div className="border-t border-slate-50 px-4 pb-3 pt-2.5 space-y-2">
        <div className="flex items-center gap-2">
          <Car size={12} className="shrink-0 text-slate-400" />
          {d.plate_number
            ? <span className="text-xs text-slate-700"><span className="font-mono font-semibold">{d.plate_number}</span> · {d.make} {d.model}{d.vehicle_type ? ` · ${d.vehicle_type}` : ''}</span>
            : <span className="text-xs text-slate-400 italic">No vehicle assigned</span>
          }
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <KycBadge status={d.kyc_status ?? 'not_submitted'} />
          {d.email && <span className="text-[11px] text-slate-400 truncate">{d.email}</span>}
        </div>

        {/* Actions */}
        <div className="flex gap-2 pt-1">
          <button onClick={onView}
            className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-slate-200 py-2.5 text-sm font-medium text-slate-600 hover:bg-slate-50 active:bg-slate-100 transition-colors">
            <FileText size={14} /> Profile
          </button>
          <button onClick={onToggle}
            className={cn(
              'flex flex-1 items-center justify-center gap-1.5 rounded-xl border py-2.5 text-sm font-medium transition-colors active:scale-[0.98]',
              d.is_active ? 'border-red-100 text-red-500 hover:bg-red-50' : 'border-green-100 text-green-600 hover:bg-green-50',
            )}>
            <Power size={14} /> {d.is_active ? 'Deactivate' : 'Activate'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export function DriversPage() {
  const [page, setPage]     = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');

  const [createOpen, setCreateOpen]     = useState(false);
  const [detailId, setDetailId]         = useState<string | null>(null);
  const [toggleTarget, setToggleTarget] = useState<Driver | null>(null);

  const qc = useQueryClient();
  const { toast } = useToast();

  const { data, isLoading } = useQuery({
    queryKey: ['drivers', page, search, status],
    queryFn: () => driversApi.list({ page, search, status }),
  });

  const toggleMutation = useMutation({
    mutationFn: () => driversApi.toggleStatus(toggleTarget!.id),
    onSuccess: () => { toast('Driver status updated.', 'success'); qc.invalidateQueries({ queryKey: ['drivers'] }); setToggleTarget(null); },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  const allDrivers = data?.data ?? [];

  const columns = [
    {
      key: 'name',
      header: 'Driver',
      render: (d: Driver) => (
        <div className="flex items-center gap-3">
          <Avatar url={d.photo_url} name={d.name} size="md" />
          <div className="min-w-0">
            <p className="font-semibold text-slate-900 text-sm truncate">{d.name}</p>
            <p className="text-xs text-slate-400">{d.phone}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (d: Driver) => (
        <div className="flex flex-col gap-1">
          <Badge status={d.is_active ? 'active' : 'inactive'}>{d.is_active ? 'Active' : 'Inactive'}</Badge>
          <Badge status={d.is_online ? 'online' : 'offline'} dot>{d.is_online ? 'Online' : 'Offline'}</Badge>
        </div>
      ),
    },
    {
      key: 'vehicle',
      header: 'Vehicle',
      render: (d: Driver) => d.plate_number
        ? <div><p className="font-mono text-sm font-semibold text-slate-800">{d.plate_number}</p><p className="text-xs text-slate-400">{d.make} {d.model}{d.vehicle_type ? ` · ${d.vehicle_type}` : ''}</p></div>
        : <span className="text-xs text-slate-400 italic">Unassigned</span>,
    },
    {
      key: 'kyc',
      header: 'KYC',
      render: (d: Driver) => <KycBadge status={d.kyc_status ?? 'not_submitted'} />,
    },
    {
      key: 'joined',
      header: 'Joined',
      render: (d: Driver) => <span className="text-xs text-slate-500">{formatDateTime(d.created_at)}</span>,
    },
    {
      key: 'actions',
      header: '',
      render: (d: Driver) => (
        <div className="flex items-center gap-1">
          <button onClick={e => { e.stopPropagation(); setDetailId(d.id); }}
            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-700 transition-colors" title="View details">
            <FileText size={14} />
          </button>
          <button onClick={e => { e.stopPropagation(); setToggleTarget(d); }}
            className={`flex h-7 w-7 items-center justify-center rounded-lg transition-colors ${d.is_active ? 'text-slate-400 hover:bg-red-50 hover:text-red-600' : 'text-slate-400 hover:bg-green-50 hover:text-green-700'}`}
            title={d.is_active ? 'Deactivate' : 'Activate'}>
            <Power size={14} />
          </button>
        </div>
      ),
    },
  ];

  return (
    <PageWrapper
      title="Drivers"
      subtitle="Manage driver accounts, vehicles and KYC"
      actions={
        <Button icon={<Plus size={14} />} onClick={() => setCreateOpen(true)}>
          Add Driver
        </Button>
      }
    >
      {/* ── Filter bar ──────────────────────────────────────────────────────── */}
      <div className="mb-4 flex gap-2">
        <div className="relative flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 z-10" />
          <input
            placeholder="Search by name, phone or email…"
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
            className="w-full rounded-xl border border-slate-300 bg-white pl-9 pr-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
        <select
          value={status}
          onChange={e => { setStatus(e.target.value); setPage(1); }}
          className="rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <option value="">All Drivers</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      {/* ── Mobile card list ──────────────────────────────────────────────── */}
      <div className="md:hidden space-y-2.5">
        {isLoading ? (
          <div className="flex items-center justify-center py-16 text-sm text-slate-400">Loading…</div>
        ) : allDrivers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-slate-400">
            <Users size={32} className="opacity-40" />
            <p className="text-sm">No drivers found.</p>
          </div>
        ) : allDrivers.map(d => (
          <DriverCard
            key={d.id}
            driver={d}
            onView={() => setDetailId(d.id)}
            onToggle={() => setToggleTarget(d)}
          />
        ))}
        <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
      </div>

      {/* ── Desktop table ──────────────────────────────────────────────────── */}
      <div className="hidden md:block">
        <Card padding={false}>
          <Table
            columns={columns}
            data={allDrivers}
            loading={isLoading}
            keyExtractor={d => d.id}
            emptyMessage="No drivers found."
            onRowClick={d => setDetailId(d.id)}
          />
          <Pagination page={page} total={data?.total ?? 0} perPage={data?.per_page ?? 25} onChange={setPage} />
        </Card>
      </div>

      <CreateDriverModal open={createOpen} onClose={() => setCreateOpen(false)} />
      {detailId && <DriverDetailModal driverId={detailId} onClose={() => setDetailId(null)} />}
      <ConfirmModal
        open={!!toggleTarget}
        onClose={() => setToggleTarget(null)}
        onConfirm={() => toggleMutation.mutate()}
        title={toggleTarget?.is_active ? 'Deactivate Driver' : 'Activate Driver'}
        message={`${toggleTarget?.is_active ? 'Deactivate' : 'Activate'} ${toggleTarget?.name}?`}
        confirmLabel={toggleTarget?.is_active ? 'Deactivate' : 'Activate'}
        danger={!!toggleTarget?.is_active}
        loading={toggleMutation.isPending}
      />
    </PageWrapper>
  );
}
