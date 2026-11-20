// ============================================================================
// Wenshy (ونشي) Admin Dashboard - TypeScript Schema Types
// Matches Supabase migrations 001, 002, 004, 005 100% accurately.
// ============================================================================

export type AppRole = 'customer' | 'driver' | 'admin';

export type DriverApprovalStatus =
  | 'pending'
  | 'under_review'
  | 'approved'
  | 'rejected'
  | 'suspended';

export type DocumentType =
  | 'national_id_front'
  | 'national_id_back'
  | 'driver_license_front'
  | 'driver_license_back'
  | 'winch_license_front'
  | 'winch_license_back'
  | 'criminal_record'
  | 'selfie_with_id';

export type DocumentReviewStatus = 'pending' | 'approved' | 'rejected';

export type TripStatus =
  | 'searching'
  | 'driver_assigned'
  | 'en_route_to_pickup'
  | 'arrived_at_pickup'
  | 'vehicle_loaded'
  | 'en_route_to_dropoff'
  | 'delivered'
  | 'cancelled'
  | 'expired';

export type PaymentMethod = 'cash' | 'card' | 'wallet';

export type ComplaintCategory =
  | 'pricing'
  | 'driver_behavior'
  | 'customer_behavior'
  | 'vehicle_damage'
  | 'delay'
  | 'app_issue'
  | 'other';

export type ComplaintStatus = 'open' | 'in_progress' | 'resolved' | 'dismissed';

export interface Profile {
  id: string;
  role: AppRole;
  full_name: string;
  phone: string | null;
  email: string | null;
  avatar_url: string | null;
  is_active: boolean;
  fcm_token: string | null;
  locale: 'ar' | 'en';
  created_at: string;
  updated_at: string;
}

export interface DashboardStats {
  total_customers: number;
  total_drivers: number;
  approved_drivers: number;
  pending_driver_approvals: number;
  online_drivers_now: number;
  searching_requests_now: number;
  active_trips_now: number;
  delivered_today: number;
  revenue_today: number;
  open_complaints: number;
  average_driver_rating: number;
}

export interface DriverWinchSummary {
  winch_id: string;
  winch_type_id: string;
  winch_type_ar: string;
  winch_type_en: string;
  plate_number: string;
  brand: string;
  model: string;
  year: number | null;
  is_verified: boolean;
  is_active: boolean;
  photo_paths: string[];
}

export interface DriverDocumentSummary {
  document_id: string;
  document_type: DocumentType;
  storage_path: string;
  review_status: DocumentReviewStatus;
  rejection_reason: string | null;
  expires_at: string | null;
  updated_at: string;
}

export interface AdminDriverApplication {
  driver_id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  avatar_url: string | null;
  is_active: boolean;
  national_id_number: string | null;
  license_number: string | null;
  license_expiry: string | null;
  approval_status: DriverApprovalStatus;
  rejection_reason: string | null;
  reviewed_at: string | null;
  is_online: boolean;
  is_available: boolean;
  avg_rating: number;
  total_trips: number;
  created_at: string;
  winches: DriverWinchSummary[];
  documents: DriverDocumentSummary[];
}

export interface AdminActiveTrip {
  id: string;
  request_code: string;
  status: TripStatus;
  created_at: string;
  accepted_at: string | null;
  pickup_lat: number;
  pickup_lng: number;
  pickup_address: string;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_address: string;
  estimated_distance_km: number;
  estimated_price: number;
  final_price: number | null;
  payment_method: PaymentMethod;
  winch_type_ar: string;
  winch_type_en: string;
  customer_id: string;
  customer_name: string;
  customer_phone: string | null;
  driver_id: string | null;
  driver_name: string | null;
  driver_phone: string | null;
  driver_lat: number | null;
  driver_lng: number | null;
  winch_plate_number: string | null;
}

export interface AdminComplaintItem {
  id: string;
  complaint_code: string;
  category: ComplaintCategory;
  status: ComplaintStatus;
  subject: string;
  description: string;
  evidence_paths: string[];
  admin_notes: string | null;
  created_at: string;
  resolved_at: string | null;
  request_id: string | null;
  request_code: string | null;
  reporter_id: string;
  reporter_name: string;
  reporter_phone: string | null;
  reporter_role: AppRole;
  reported_user_id: string | null;
  reported_user_name: string | null;
  reported_user_role: AppRole | null;
}

export interface WinchType {
  id: string;
  code: string;
  name_ar: string;
  name_en: string;
  description_ar: string | null;
  description_en: string | null;
  base_fare: number;
  price_per_km: number;
  minimum_fare: number;
  road_factor: number;
  surge_multiplier: number;
  max_weight_tons: number | null;
  icon_name: string | null;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}
