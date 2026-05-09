import { apiClient, apiRequest } from './client';
import type {
  BookingReportSummary,
  DailyBreakdown,
  RevenueReportSummary,
  ProviderBreakdown,
  DriverReportRow,
} from '../types';

export interface DateRangeParams {
  from?: string;
  to?: string;
}

export const reportsApi = {
  bookings: (params: DateRangeParams & { status?: string; type?: string } = {}) =>
    apiRequest<{
      period: { from: string; to: string };
      summary: BookingReportSummary;
      daily: DailyBreakdown[];
    }>(apiClient.get('/admin/reports/bookings', { params })),

  revenue: (params: DateRangeParams = {}) =>
    apiRequest<{
      period: { from: string; to: string };
      summary: RevenueReportSummary;
      providers: ProviderBreakdown[];
      currency: string;
    }>(apiClient.get('/admin/reports/revenue', { params })),

  drivers: (params: DateRangeParams = {}) =>
    apiRequest<{
      period: { from: string; to: string };
      data: DriverReportRow[];
    }>(apiClient.get('/admin/reports/drivers', { params })),
};
