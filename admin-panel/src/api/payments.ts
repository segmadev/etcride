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

export interface PaymentGateway {
  id: number;
  name: string;
  display_name: string;
  is_enabled: boolean;
  priority: number;
  public_key?: string;
  secret_key?: string;
  webhook_secret?: string;
  min_amount: number;
  max_amount: number;
  transaction_fee_percent: number;
  transaction_fee_fixed: number;
  created_at: string;
  updated_at: string;
}

export interface GatewayStats {
  name: string;
  display_name: string;
  total_transactions: number;
  total_amount: string;
  successful_count: number;
  failed_count: number;
  pending_count: number;
  last_transaction: string | null;
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

export const paymentGatewaysApi = {
  list: () =>
    apiRequest<PaymentGateway[]>(
      apiClient.get('/admin/payment-gateways'),
    ),

  show: (id: number) =>
    apiRequest<PaymentGateway>(
      apiClient.get(`/admin/payment-gateways/${id}`),
    ),

  update: (id: number, data: Partial<PaymentGateway>) =>
    apiRequest<PaymentGateway>(
      apiClient.put(`/admin/payment-gateways/${id}`, data),
    ),

  toggle: (id: number) =>
    apiRequest<{ is_enabled: boolean }>(
      apiClient.post(`/admin/payment-gateways/${id}/toggle`, {}),
    ),

  stats: () =>
    apiRequest<GatewayStats[]>(
      apiClient.get('/admin/payment-gateways/stats'),
    ),
};

// Default export for backward compatibility
export default paymentsApi;
