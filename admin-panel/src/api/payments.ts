import { apiClient, apiRequest } from './client';
import type { PaginatedResponse } from '../types';

export interface Payment {
  id: string;
  booking_id: string;
  provider: string;
  amount: number;
  currency: string;
  status: 'pending' | 'paid' | 'failed' | 'refunded';
  reference: string;
  provider_ref?: string;
  created_at: string;
  customer_name?: string;
  customer_phone?: string;
  booking_code?: string;
  booking_status?: string;
  final_fare?: number;
  estimated_fare?: number;
  distance_km?: number;
  pickup_address?: string;
  destination_address?: string;
  raw_response?: string;
}

export interface PaymentsFilter {
  page?: number;
  status?: string;
  search?: string;
}

export const paymentsApi = {
  list: (params: PaymentsFilter = {}) =>
    apiRequest<PaginatedResponse<Payment>>(
      apiClient.get('/admin/payments', { params }),
    ),

  show: (id: string) =>
    apiRequest<Payment>(apiClient.get(`/admin/payments/${id}`)),

  refund: (id: string) =>
    apiRequest<null>(apiClient.post(`/admin/payments/${id}/refund`, {})),
};
