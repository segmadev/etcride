// ── API response envelope ──────────────────────────────────────────────────
export interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T;
  errors: Record<string, string[]> | null;
}

export interface PaginatedResponse<T> {
  total: number;
  page: number;
  per_page: number;
  data: T[];
}

// ── Auth ───────────────────────────────────────────────────────────────────
export interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: string;
  status: number;
}

// ── Booking ────────────────────────────────────────────────────────────────
export type BookingStatus =
  | 'pending'
  | 'assigned'
  | 'accepted'
  | 'payment_pending'
  | 'paid'
  | 'in_progress'
  | 'completed'
  | 'cancelled';

export type BookingType = 'ride' | 'delivery';
export type PaymentStatus = 'unpaid' | 'pending' | 'paid' | 'failed';

export interface BookingStop {
  id: string;
  address: string;
  lat: number;
  lng: number;
  stop_order: number;
  reached_at: string | null;
}

export interface BookingStatusHistory {
  status: string;
  changed_at: string;
  note: string;
}

export interface Booking {
  id: string;
  booking_code?: string | null;
  booking_type: BookingType;
  status: BookingStatus;
  payment_status: PaymentStatus;
  estimated_fare: number;
  final_fare: number | null;
  distance_km: number;
  pickup_address: string;
  pickup_lat: number;
  pickup_lng: number;
  dropoff_address: string;
  dropoff_lat: number;
  dropoff_lng: number;
  note: string | null;
  created_at: string;
  vehicle_type_id?: string | null;
  vehicle_type?: string | null;
  vehicle_type_category?: string | null;
  customer_id?: string | null;
  customer_name?: string;
  customer_phone?: string;
  customer_email?: string | null;
  driver_id?: string | null;
  driver_name?: string | null;
  driver_phone?: string | null;
  stops?: BookingStop[];
  status_history?: BookingStatusHistory[];
  // full detail (from show endpoint)
  customer?: { id: string; name: string; phone: string; email: string | null } | null;
  driver?: { id: string; name: string; phone: string; last_seen: string | null; vehicle_id: string | null } | null;
  payment?: { id: string; provider: string; amount: number; status: string; created_at: string } | null;
  history?: BookingStatusHistory[];
}

// ── Driver ────────────────────────────────────────────────────────────────
export interface DriverStats {
  total_trips: number;
  completed: number;
  cancelled: number;
  rejected: number;
  total_earned: number;
}

export type KycStatus = 'not_submitted' | 'pending' | 'verified' | 'rejected';

export interface Driver {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  photo: string | null;
  photo_url: string | null;
  license_number: string | null;
  is_active: boolean | number;
  is_online: boolean | number;
  last_seen: string | null;
  // KYC
  kyc_status: KycStatus;
  kyc_id_type: string | null;
  kyc_id_number: string | null;
  kyc_id_front: string | null;
  kyc_id_back: string | null;
  kyc_front_url: string | null;
  kyc_back_url: string | null;
  kyc_note: string | null;
  // Vehicle (from join)
  vehicle_id: string | null;
  plate_number?: string | null;
  make?: string | null;
  model?: string | null;
  color?: string | null;
  driver_vehicle_type_id?: string | null;
  vehicle_type?: string | null;
  vehicle_type_category?: string | null;
  vehicle?: Vehicle | null;
  stats?: { total: number; completed: number; cancelled: number };
  created_at: string;
}

// ── Vehicle ───────────────────────────────────────────────────────────────
export interface Vehicle {
  id: string;
  vehicle_type_id: string;
  vehicle_type_name?: string;
  plate_number: string;
  make: string;
  model: string;
  color: string;
  year: string | null;
  status: 'active' | 'inactive';
  driver_id?: string | null;
  driver_name?: string | null;
  driver_phone?: string | null;
  created_at: string;
}

// ── Vehicle Type ──────────────────────────────────────────────────────────
export interface VehicleType {
  id: string;
  name: string;
  description: string | null;
  base_fare: number;
  per_km_rate: number;
  per_stop_fee: number;
  is_active: boolean | number;
  vehicle_count?: number;
}

// ── Zone ──────────────────────────────────────────────────────────────────
export interface ZonePricing {
  id: string;
  vehicle_type_id: string;
  vehicle_type_name: string;
  base_fare: number;
  per_km_rate: number;
  per_stop_fee: number;
  is_active: boolean | number;
}

export interface Zone {
  id: string;
  name: string;
  description: string | null;
  is_default: boolean | number;
  is_active: boolean | number;
  pricing_entries?: number;
}

// ── Settings ──────────────────────────────────────────────────────────────
export interface SettingEntry {
  value: string;
  description: string;
  updated_at: string;
}

export type Settings = Record<string, SettingEntry>;

// ── Reports ───────────────────────────────────────────────────────────────
export interface BookingReportSummary {
  total: number;
  completed: number;
  cancelled: number;
  pending: number;
  in_progress: number;
  rides: number;
  deliveries: number;
  paid_count: number;
  total_revenue: string;
}

export interface DailyBreakdown {
  date: string;
  total: number;
  completed: number;
  cancelled: number;
  revenue: string;
}

export interface RevenueReportSummary {
  total_revenue: string;
  estimated_total: string;
  paid_bookings: number;
  failed_payments: number;
  avg_fare: string;
}

export interface ProviderBreakdown {
  provider: string;
  transactions: number;
  total: string;
  avg: string;
}

export interface DriverReportRow {
  id: string;
  name: string;
  phone: string;
  is_active: number;
  is_online: number;
  total_jobs: number;
  completed: number;
  cancelled: number;
  rejected: number;
  total_earned: string;
}
