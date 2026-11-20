-- ============================================================================
-- Wenshy (ونشي) - Migration 002: Core Tables, Constraints & Indexes
-- ============================================================================

-- Sequences for human-readable reference codes
CREATE SEQUENCE IF NOT EXISTS public.rescue_request_code_seq START WITH 100001 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS public.complaint_code_seq START WITH 100001 INCREMENT BY 1;

-- ----------------------------------------------------------------------------
-- 1. Profiles (1:1 extension of auth.users for Customer, Driver, Admin)
-- ----------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        public.app_role NOT NULL DEFAULT 'customer',
  full_name   text NOT NULL DEFAULT '',
  phone       text UNIQUE,
  email       text,
  avatar_url  text,
  is_active   boolean NOT NULL DEFAULT true,
  fcm_token   text,
  locale      text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar', 'en')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profiles_role_active_idx ON public.profiles (role, is_active);

-- ----------------------------------------------------------------------------
-- 2. Customer Vehicles (Saved cars for quick breakdown requests)
-- ----------------------------------------------------------------------------
CREATE TABLE public.customer_vehicles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  make             text NOT NULL,
  model            text NOT NULL,
  year             smallint CHECK (year IS NULL OR year BETWEEN 1950 AND 2100),
  color            text,
  plate_number     text NOT NULL,
  vehicle_category public.vehicle_category NOT NULL DEFAULT 'sedan',
  notes            text,
  is_default       boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX customer_vehicles_customer_id_idx ON public.customer_vehicles (customer_id);

-- Enforce at most one default vehicle per customer
CREATE UNIQUE INDEX customer_vehicles_one_default_idx
  ON public.customer_vehicles (customer_id)
  WHERE is_default = true;

-- ----------------------------------------------------------------------------
-- 3. Winch Types (Catalog of tow truck categories & pricing parameters)
-- ----------------------------------------------------------------------------
CREATE TABLE public.winch_types (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text NOT NULL UNIQUE,
  name_ar          text NOT NULL,
  name_en          text NOT NULL,
  description_ar   text,
  description_en   text,
  base_fare        numeric(10, 2) NOT NULL CHECK (base_fare >= 0),
  price_per_km     numeric(10, 2) NOT NULL CHECK (price_per_km >= 0),
  minimum_fare     numeric(10, 2) NOT NULL CHECK (minimum_fare >= 0),
  road_factor      numeric(4, 2) NOT NULL DEFAULT 1.25 CHECK (road_factor >= 1.00 AND road_factor <= 3.00),
  surge_multiplier numeric(4, 2) NOT NULL DEFAULT 1.00 CHECK (surge_multiplier >= 0.50 AND surge_multiplier <= 5.00),
  max_weight_tons  numeric(5, 2) CHECK (max_weight_tons IS NULL OR max_weight_tons > 0),
  icon_name        text,
  sort_order       integer NOT NULL DEFAULT 0,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX winch_types_active_sort_idx
  ON public.winch_types (sort_order)
  WHERE is_active = true;

-- ----------------------------------------------------------------------------
-- 4. Drivers (1:1 extension of profiles for Tow-Truck Drivers)
-- ----------------------------------------------------------------------------
CREATE TABLE public.drivers (
  id                   uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  national_id_number   text UNIQUE,
  license_number       text,
  license_expiry       date,
  approval_status      public.driver_approval_status NOT NULL DEFAULT 'pending',
  rejection_reason     text,
  reviewed_by          uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at          timestamptz,
  is_online            boolean NOT NULL DEFAULT false,
  is_available         boolean NOT NULL DEFAULT true,
  current_lat          double precision CHECK (current_lat IS NULL OR current_lat BETWEEN -90 AND 90),
  current_lng          double precision CHECK (current_lng IS NULL OR current_lng BETWEEN -180 AND 180),
  current_location     extensions.geography(Point, 4326),
  current_heading      numeric(5, 2) CHECK (current_heading IS NULL OR (current_heading >= 0 AND current_heading <= 360)),
  current_speed_kmh    numeric(6, 2) CHECK (current_speed_kmh IS NULL OR current_speed_kmh >= 0),
  last_location_at     timestamptz,
  avg_rating           numeric(3, 2) NOT NULL DEFAULT 5.00 CHECK (avg_rating BETWEEN 0 AND 5),
  total_ratings        integer NOT NULL DEFAULT 0 CHECK (total_ratings >= 0),
  total_trips          integer NOT NULL DEFAULT 0 CHECK (total_trips >= 0),
  total_earnings       numeric(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_earnings >= 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX drivers_approval_status_idx ON public.drivers (approval_status);
CREATE INDEX drivers_reviewed_by_idx ON public.drivers (reviewed_by) WHERE reviewed_by IS NOT NULL;

-- Partial spatial GiST index covering ONLY approved, online, available drivers
CREATE INDEX drivers_available_location_gist_idx
  ON public.drivers USING gist (current_location)
  WHERE approval_status = 'approved'
    AND is_online = true
    AND is_available = true
    AND current_location IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 5. Driver Winches (Tow-truck vehicles owned/operated by drivers)
-- ----------------------------------------------------------------------------
CREATE TABLE public.driver_winches (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id            uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  winch_type_id        uuid NOT NULL REFERENCES public.winch_types(id) ON DELETE RESTRICT,
  plate_number         text NOT NULL UNIQUE,
  brand                text NOT NULL,
  model                text NOT NULL,
  year                 smallint CHECK (year IS NULL OR year BETWEEN 1980 AND 2100),
  color                text,
  max_capacity_tons    numeric(5, 2) CHECK (max_capacity_tons IS NULL OR max_capacity_tons > 0),
  winch_license_number text,
  winch_license_expiry date,
  photo_paths          text[] NOT NULL DEFAULT '{}',
  is_verified          boolean NOT NULL DEFAULT false,
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX driver_winches_driver_id_idx ON public.driver_winches (driver_id);
CREATE INDEX driver_winches_type_verified_idx
  ON public.driver_winches (winch_type_id, driver_id)
  WHERE is_active = true AND is_verified = true;

-- ----------------------------------------------------------------------------
-- 6. Driver Documents (KYC & Compliance files stored in `driver-documents` bucket)
-- ----------------------------------------------------------------------------
CREATE TABLE public.driver_documents (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id        uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  winch_id         uuid REFERENCES public.driver_winches(id) ON DELETE SET NULL,
  document_type    public.document_type NOT NULL,
  storage_path     text NOT NULL,
  review_status    public.document_review_status NOT NULL DEFAULT 'pending',
  rejection_reason text,
  reviewed_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at      timestamptz,
  expires_at       date,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_documents_unique_type_per_driver UNIQUE (driver_id, document_type)
);

CREATE INDEX driver_documents_driver_id_idx ON public.driver_documents (driver_id);
CREATE INDEX driver_documents_pending_idx
  ON public.driver_documents (review_status, created_at)
  WHERE review_status = 'pending';

-- ----------------------------------------------------------------------------
-- 7. Rescue Requests (Core Towing Trips)
-- ----------------------------------------------------------------------------
CREATE TABLE public.rescue_requests (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_code             text NOT NULL UNIQUE DEFAULT ('WN-' || nextval('public.rescue_request_code_seq')::text),
  customer_id              uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  driver_id                uuid REFERENCES public.drivers(id) ON DELETE SET NULL,
  winch_type_id            uuid NOT NULL REFERENCES public.winch_types(id) ON DELETE RESTRICT,
  winch_id                 uuid REFERENCES public.driver_winches(id) ON DELETE SET NULL,
  customer_vehicle_id      uuid REFERENCES public.customer_vehicles(id) ON DELETE SET NULL,

  -- Snapshot of vehicle at request time (preserves audit history)
  vehicle_make             text,
  vehicle_model            text,
  vehicle_year             smallint,
  vehicle_color            text,
  vehicle_plate            text,
  vehicle_category         public.vehicle_category NOT NULL DEFAULT 'sedan',

  -- Breakdown context & photos (paths in `breakdown-photos` bucket)
  breakdown_reason         text,
  breakdown_notes          text,
  breakdown_photo_paths    text[] NOT NULL DEFAULT '{}',

  -- Pickup & Dropoff Coordinates + PostGIS Geography
  pickup_lat               double precision NOT NULL CHECK (pickup_lat BETWEEN -90 AND 90),
  pickup_lng               double precision NOT NULL CHECK (pickup_lng BETWEEN -180 AND 180),
  pickup_location          extensions.geography(Point, 4326) NOT NULL,
  pickup_address           text NOT NULL,

  dropoff_lat              double precision NOT NULL CHECK (dropoff_lat BETWEEN -90 AND 90),
  dropoff_lng              double precision NOT NULL CHECK (dropoff_lng BETWEEN -180 AND 180),
  dropoff_location         extensions.geography(Point, 4326) NOT NULL,
  dropoff_address          text NOT NULL,

  -- Distance & Pricing Snapshot
  geodesic_distance_km     numeric(8, 2) NOT NULL CHECK (geodesic_distance_km >= 0),
  estimated_distance_km    numeric(8, 2) NOT NULL CHECK (estimated_distance_km >= 0),
  estimated_duration_min   integer CHECK (estimated_duration_min IS NULL OR estimated_duration_min >= 0),
  base_fare_snapshot       numeric(10, 2) NOT NULL CHECK (base_fare_snapshot >= 0),
  price_per_km_snapshot    numeric(10, 2) NOT NULL CHECK (price_per_km_snapshot >= 0),
  estimated_price          numeric(10, 2) NOT NULL CHECK (estimated_price >= 0),
  final_price              numeric(10, 2) CHECK (final_price IS NULL OR final_price >= 0),
  currency                 text NOT NULL DEFAULT 'EGP',
  payment_method           public.payment_method NOT NULL DEFAULT 'cash',
  payment_status           public.payment_status NOT NULL DEFAULT 'pending',

  -- Trip Lifecycle & Timestamps
  status                   public.trip_status NOT NULL DEFAULT 'searching',
  current_wave             smallint NOT NULL DEFAULT 1,
  cancellation_reason      text,
  cancelled_by             uuid REFERENCES public.profiles(id) ON DELETE SET NULL,

  accepted_at              timestamptz,
  en_route_at              timestamptz,
  arrived_at               timestamptz,
  loaded_at                timestamptz,
  dropoff_started_at       timestamptz,
  completed_at             timestamptz,
  cancelled_at             timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

-- Foreign key & query indexes
CREATE INDEX rescue_requests_customer_created_idx ON public.rescue_requests (customer_id, created_at DESC);
CREATE INDEX rescue_requests_driver_created_idx ON public.rescue_requests (driver_id, created_at DESC) WHERE driver_id IS NOT NULL;
CREATE INDEX rescue_requests_winch_type_idx ON public.rescue_requests (winch_type_id);
CREATE INDEX rescue_requests_active_status_idx
  ON public.rescue_requests (status, created_at DESC)
  WHERE status NOT IN ('delivered', 'cancelled', 'expired');

-- Spatial indexes on pickup/dropoff
CREATE INDEX rescue_requests_pickup_gist_idx ON public.rescue_requests USING gist (pickup_location);
CREATE INDEX rescue_requests_dropoff_gist_idx ON public.rescue_requests USING gist (dropoff_location);

-- ----------------------------------------------------------------------------
-- 8. Dispatch Offers (Realtime matching invitations sent to candidate drivers)
-- ----------------------------------------------------------------------------
CREATE TABLE public.dispatch_offers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      uuid NOT NULL REFERENCES public.rescue_requests(id) ON DELETE CASCADE,
  driver_id       uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  winch_id        uuid NOT NULL REFERENCES public.driver_winches(id) ON DELETE CASCADE,
  distance_meters integer NOT NULL CHECK (distance_meters >= 0),
  eta_minutes     integer CHECK (eta_minutes IS NULL OR eta_minutes >= 0),
  wave_number     smallint NOT NULL DEFAULT 1,
  status          public.offer_status NOT NULL DEFAULT 'pending',
  rejection_reason text,
  expires_at      timestamptz NOT NULL,
  responded_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  -- Prevent dispatching the same request twice to the same driver
  CONSTRAINT dispatch_offers_unique_request_driver UNIQUE (request_id, driver_id)
);

CREATE INDEX dispatch_offers_request_status_idx ON public.dispatch_offers (request_id, status);
CREATE INDEX dispatch_offers_driver_pending_idx
  ON public.dispatch_offers (driver_id, expires_at DESC)
  WHERE status = 'pending';

-- ----------------------------------------------------------------------------
-- 9. Trip Status Logs (Immutable Audit Trail of Trip Stages)
-- ----------------------------------------------------------------------------
CREATE TABLE public.trip_status_logs (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id  uuid NOT NULL REFERENCES public.rescue_requests(id) ON DELETE CASCADE,
  from_status public.trip_status,
  to_status   public.trip_status NOT NULL,
  changed_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  lat         double precision CHECK (lat IS NULL OR lat BETWEEN -90 AND 90),
  lng         double precision CHECK (lng IS NULL OR lng BETWEEN -180 AND 180),
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX trip_status_logs_request_created_idx ON public.trip_status_logs (request_id, created_at ASC);

-- ----------------------------------------------------------------------------
-- 10. Trip Location History (Throttled GPS Breadcrumbs during Active Trips)
-- ----------------------------------------------------------------------------
CREATE TABLE public.trip_location_history (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id  uuid NOT NULL REFERENCES public.rescue_requests(id) ON DELETE CASCADE,
  driver_id   uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  lat         double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng         double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  heading     numeric(5, 2),
  speed_kmh   numeric(6, 2),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX trip_location_history_request_recorded_idx
  ON public.trip_location_history (request_id, recorded_at ASC);

-- ----------------------------------------------------------------------------
-- 11. Ratings (Customer review per delivered rescue trip)
-- ----------------------------------------------------------------------------
CREATE TABLE public.ratings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id  uuid NOT NULL UNIQUE REFERENCES public.rescue_requests(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  driver_id   uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  score       smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment     text,
  tags        text[] NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ratings_driver_created_idx ON public.ratings (driver_id, created_at DESC);
CREATE INDEX ratings_customer_id_idx ON public.ratings (customer_id);

-- ----------------------------------------------------------------------------
-- 12. Complaints (Customer/Driver Dispute & Support Tickets)
-- ----------------------------------------------------------------------------
CREATE TABLE public.complaints (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_code   text NOT NULL UNIQUE DEFAULT ('CMP-' || nextval('public.complaint_code_seq')::text),
  request_id       uuid REFERENCES public.rescue_requests(id) ON DELETE SET NULL,
  reporter_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  category         public.complaint_category NOT NULL,
  subject          text NOT NULL,
  description      text NOT NULL,
  evidence_paths   text[] NOT NULL DEFAULT '{}',
  status           public.complaint_status NOT NULL DEFAULT 'open',
  admin_notes      text,
  resolved_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX complaints_reporter_created_idx ON public.complaints (reporter_id, created_at DESC);
CREATE INDEX complaints_status_created_idx ON public.complaints (status, created_at DESC);
CREATE INDEX complaints_request_id_idx ON public.complaints (request_id) WHERE request_id IS NOT NULL;
