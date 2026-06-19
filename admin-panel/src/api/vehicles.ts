import { apiClient, apiRequest } from './client';
import type { Vehicle, PaginatedResponse } from '../types';

export interface VehiclesFilter {
  page?: number;
  vehicle_type_id?: string;
  status?: string;
}

export interface CreateVehiclePayload {
  vehicle_type_id: string;
  plate_number: string;
  make: string;
  model: string;
  color: string;
  year?: string;
  photo?: File | null;
}

export interface UpdateVehiclePayload {
  make?: string;
  model?: string;
  color?: string;
  year?: string;
  plate_number?: string;
  vehicle_type_id?: string;
  photo?: File | null;
}

export const vehiclesApi = {
  list: (params: VehiclesFilter = {}) =>
    apiRequest<PaginatedResponse<Vehicle>>(
      apiClient.get('/admin/vehicles', { params }),
    ),

  show: (id: string) =>
    apiRequest<Vehicle>(apiClient.get(`/admin/vehicles/${id}`)),

  create: (payload: CreateVehiclePayload) => {
    const hasPhoto = !!payload.photo;

    if (!hasPhoto) {
      const { photo: _photo, ...json } = payload;
      return apiRequest<{ id: string; plate_number: string }>(
        apiClient.post('/admin/vehicles', json),
      );
    }

    const form = new FormData();
    form.append('vehicle_type_id', payload.vehicle_type_id);
    form.append('plate_number', payload.plate_number);
    form.append('make', payload.make);
    form.append('model', payload.model);
    form.append('color', payload.color);
    if (payload.year) form.append('year', payload.year);
    if (payload.photo) form.append('photo', payload.photo);

    return apiRequest<{ id: string; plate_number: string }>(
      apiClient.post('/admin/vehicles', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }),
    );
  },

  update: (id: string, payload: UpdateVehiclePayload) => {
    const hasPhoto = !!payload.photo;

    if (!hasPhoto) {
      const { photo: _photo, ...json } = payload;
      return apiRequest<null>(apiClient.post(`/admin/vehicles/${id}`, json));
    }

    const form = new FormData();
    if (payload.vehicle_type_id) form.append('vehicle_type_id', payload.vehicle_type_id);
    if (payload.plate_number) form.append('plate_number', payload.plate_number);
    if (payload.make) form.append('make', payload.make);
    if (payload.model) form.append('model', payload.model);
    if (payload.color) form.append('color', payload.color);
    if (payload.year) form.append('year', payload.year);
    if (payload.photo) form.append('photo', payload.photo);

    return apiRequest<null>(
      apiClient.post(`/admin/vehicles/${id}`, form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }),
    );
  },

  toggleStatus: (id: string) =>
    apiRequest<{ status: string }>(
      apiClient.put(`/admin/vehicles/${id}/status`),
    ),
};
