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
}

export interface UpdateVehiclePayload {
  make?: string;
  model?: string;
  color?: string;
  year?: string;
  plate_number?: string;
  vehicle_type_id?: string;
}

export const vehiclesApi = {
  list: (params: VehiclesFilter = {}) =>
    apiRequest<PaginatedResponse<Vehicle>>(
      apiClient.get('/admin/vehicles', { params }),
    ),

  show: (id: string) =>
    apiRequest<Vehicle>(apiClient.get(`/admin/vehicles/${id}`)),

  create: (payload: CreateVehiclePayload) =>
    apiRequest<{ id: string; plate_number: string }>(
      apiClient.post('/admin/vehicles', payload),
    ),

  update: (id: string, payload: UpdateVehiclePayload) =>
    apiRequest<null>(apiClient.put(`/admin/vehicles/${id}`, payload)),

  toggleStatus: (id: string) =>
    apiRequest<{ status: string }>(
      apiClient.put(`/admin/vehicles/${id}/status`),
    ),
};
