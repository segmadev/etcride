import { apiClient, apiRequest } from './client';

// Trip report and cancellation management
export interface TripReport {
  id: number;
  booking_id: string;
  booking_code?: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string;
  customer_email: string;
  driver_id?: string;
  driver_name: string;
  driver_phone: string;
  report_reason: string;
  description: string;
  report_status: 'pending' | 'reviewed' | 'resolved';
  booking_status: string;
  final_fare?: number;
  pickup_address: string;
  destination_address: string;
  vehicle_type?: string;
  created_at: string;
  cancellation_id?: number;
  cancellation_reason?: string;
  cancellation_status?: 'pending' | 'approved' | 'rejected';
  admin_notes?: string;
}

export interface TripReportDetail extends TripReport {
  // Full details with all booking info
}

export const tripReportsApi = {
  list: (filters?: { status?: string; search?: string }) =>
    apiRequest<TripReport[]>(
      apiClient.get('/admin/trip-reports', {
        params: filters,
      })
    ),

  show: (id: number) =>
    apiRequest<TripReportDetail>(apiClient.get(`/admin/trip-reports/${id}`)),

  approveCancellation: (id: number, notes?: string) =>
    apiRequest<void>(
      apiClient.put(`/admin/trip-reports/${id}/approve-cancellation`, {
        notes,
      })
    ),

  rejectCancellation: (id: number, notes?: string) =>
    apiRequest<void>(
      apiClient.put(`/admin/trip-reports/${id}/reject-cancellation`, {
        notes,
      })
    ),
};
