import { apiClient, apiRequest } from './client';
import type { Zone, ZonePricing } from '../types';

export interface ZonePayload { name: string; description?: string }
export interface ZonePricingPayload {
  vehicle_type_id: string;
  base_fare: number;
  per_km_rate: number;
  per_stop_fee: number;
}

export const zonesApi = {
  list: () =>
    apiRequest<Zone[]>(apiClient.get('/admin/zones')),

  create: (payload: ZonePayload) =>
    apiRequest<{ id: string; name: string }>(
      apiClient.post('/admin/zones', payload),
    ),

  update: (id: string, payload: Partial<ZonePayload> & { is_active?: boolean }) =>
    apiRequest<null>(apiClient.put(`/admin/zones/${id}`, payload)),

  remove: (id: string) =>
    apiRequest<null>(apiClient.delete(`/admin/zones/${id}`)),

  getPricing: (id: string) =>
    apiRequest<{ zone: Zone; pricing: ZonePricing[] }>(
      apiClient.get(`/admin/zones/${id}/pricing`),
    ),

  setPricing: (id: string, payload: ZonePricingPayload) =>
    apiRequest<null>(apiClient.post(`/admin/zones/${id}/pricing`, payload)),

  removePricing: (id: string, pricingId: string) =>
    apiRequest<null>(apiClient.delete(`/admin/zones/${id}/pricing/${pricingId}`)),
};
