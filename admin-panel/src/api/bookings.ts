import { apiClient, apiRequest } from './client';
import type { Booking, PaginatedResponse } from '../types';

export interface BookingsFilter {
  page?: number;
  status?: string;
  type?: string;
  from?: string;
  to?: string;
  search?: string;
}

export const bookingsApi = {
  list: (params: BookingsFilter = {}) =>
    apiRequest<PaginatedResponse<Booking>>(
      apiClient.get('/admin/bookings', { params }),
    ),

  show: (id: string) =>
    apiRequest<Booking>(apiClient.get(`/admin/bookings/${id}`)),

  assign: (id: string, driverId: string) =>
    apiRequest<{ driver_id: string }>(
      apiClient.post(`/admin/bookings/${id}/assign`, { driver_id: driverId }),
    ),

  reassign: (id: string, driverId: string, reason?: string) =>
    apiRequest<null>(
      apiClient.post(`/admin/bookings/${id}/reassign`, { driver_id: driverId, reason }),
    ),

  deassign: (id: string) =>
    apiRequest<null>(
      apiClient.post(`/admin/bookings/${id}/deassign`),
    ),

  cancel: (id: string, reason?: string) =>
    apiRequest<null>(
      apiClient.post(`/admin/bookings/${id}/cancel`, { reason }),
    ),

  track: (id: string) =>
    apiRequest<{ driver_id: string; driver_name: string; lat: number; lng: number; last_seen: string }>(
      apiClient.get(`/admin/bookings/${id}/track`),
    ),

  notifications: () =>
    apiRequest<Array<{ id: string; title: string; body: string; is_read: boolean; created_at: string }>>(
      apiClient.get('/admin/bookings/notifications'),
    ),
};
