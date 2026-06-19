import { apiClient, apiRequest } from './client';
import type { VehicleType } from '../types';

export interface VehicleTypePayload {
  name: string;
  description?: string;
  base_fare: number;
  per_km_rate: number;
  per_stop_fee: number;
  is_active?: number;
  category?: 'ride' | 'delivery';
}

export const vehicleTypesApi = {
  list: () =>
    apiRequest<VehicleType[]>(apiClient.get('/admin/vehicle-types')),

  create: (payload: VehicleTypePayload) =>
    apiRequest<{ id: string; name: string }>(
      apiClient.post('/admin/vehicle-types', payload),
    ),

  update: (id: string, payload: Partial<VehicleTypePayload>) =>
    apiRequest<null>(apiClient.put(`/admin/vehicle-types/${id}`, payload)),

  remove: (id: string) =>
    apiRequest<null>(apiClient.delete(`/admin/vehicle-types/${id}`)),
};
