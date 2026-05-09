import { apiClient, apiRequest } from './client';
import type { Driver, KycStatus, PaginatedResponse } from '../types';

export interface DriversFilter {
  page?: number;
  search?: string;
  status?: string;
  is_online?: number;
}

export interface CreateDriverPayload {
  name: string;
  phone: string;
  email?: string;
  password: string;
  license_number?: string;
  vehicle_id?: string;
  photo?: File | null;
  // KYC (optional)
  kyc_id_type?: string;
  kyc_id_number?: string;
  kyc_id_front?: File | null;
  kyc_id_back?: File | null;
}

/** Build a FormData from a CreateDriverPayload so files are included */
function toFormData(payload: CreateDriverPayload): FormData {
  const fd = new FormData();
  fd.append('name',     payload.name);
  fd.append('phone',    payload.phone);
  fd.append('password', btoa(payload.password));
  if (payload.email)          fd.append('email',          payload.email);
  if (payload.license_number) fd.append('license_number', payload.license_number);
  if (payload.vehicle_id)     fd.append('vehicle_id',     payload.vehicle_id);
  if (payload.photo)          fd.append('photo',          payload.photo);
  if (payload.kyc_id_type)    fd.append('kyc_id_type',    payload.kyc_id_type);
  if (payload.kyc_id_number)  fd.append('kyc_id_number',  payload.kyc_id_number);
  if (payload.kyc_id_front)   fd.append('kyc_id_front',   payload.kyc_id_front);
  if (payload.kyc_id_back)    fd.append('kyc_id_back',    payload.kyc_id_back);
  return fd;
}

export const driversApi = {
  list: (params: DriversFilter = {}) =>
    apiRequest<PaginatedResponse<Driver>>(
      apiClient.get('/admin/drivers', { params }),
    ),

  show: (id: string) =>
    apiRequest<Driver>(apiClient.get(`/admin/drivers/${id}`)),

  create: (payload: CreateDriverPayload) =>
    apiRequest<{ id: string; name: string; phone: string; photo_url: string | null }>(
      apiClient.post('/admin/drivers', toFormData(payload), {
        headers: { 'Content-Type': 'multipart/form-data' },
      }),
    ),

  update: (id: string, payload: { name?: string; email?: string; license_number?: string; photo?: File | null }) => {
    const fd = new FormData();
    if (payload.name)           fd.append('name',           payload.name);
    if (payload.email)          fd.append('email',          payload.email);
    if (payload.license_number) fd.append('license_number', payload.license_number);
    if (payload.photo)          fd.append('photo',          payload.photo);
    return apiRequest<{ photo_url: string | null }>(
      apiClient.put(`/admin/drivers/${id}`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }),
    );
  },

  toggleStatus: (id: string) =>
    apiRequest<{ is_active: boolean }>(
      apiClient.put(`/admin/drivers/${id}/status`),
    ),

  assignVehicle: (id: string, vehicleId: string) =>
    apiRequest<null>(
      apiClient.post(`/admin/drivers/${id}/assign-vehicle`, { vehicle_id: vehicleId }),
    ),

  updateKyc: (
    id: string,
    payload: {
      kyc_status?: KycStatus;
      kyc_id_type?: string;
      kyc_id_number?: string;
      kyc_note?: string;
      kyc_id_front?: File | null;
      kyc_id_back?: File | null;
    },
  ) => {
    const fd = new FormData();
    if (payload.kyc_status)    fd.append('kyc_status',    payload.kyc_status);
    if (payload.kyc_id_type)   fd.append('kyc_id_type',   payload.kyc_id_type);
    if (payload.kyc_id_number) fd.append('kyc_id_number', payload.kyc_id_number);
    if (payload.kyc_note)      fd.append('kyc_note',      payload.kyc_note);
    if (payload.kyc_id_front)  fd.append('kyc_id_front',  payload.kyc_id_front);
    if (payload.kyc_id_back)   fd.append('kyc_id_back',   payload.kyc_id_back);
    return apiRequest<{ kyc_status: KycStatus; kyc_front_url: string | null; kyc_back_url: string | null }>(
      apiClient.put(`/admin/drivers/${id}/kyc`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }),
    );
  },
};
