-- ============================================================================
-- Wenshy (ونشي) - Migration 001: Schemas, Extensions & Domain Types
-- ============================================================================
-- Notes:
-- 1. PostGIS is installed in the dedicated `extensions` schema (never `public`)
--    so internal PostGIS tables like `spatial_ref_sys` are not exposed via Data API.
-- 2. The `private` schema holds internal RLS helpers and trigger functions
--    that should never be exposed directly via PostgREST.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS private;

-- Ensure extensions schema is usable by API roles (PostGIS types/functions)
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Lock down private schema by default; explicit USAGE/EXECUTE grants are added
-- only for read-only RLS predicate functions in Migration 004.
REVOKE ALL ON SCHEMA private FROM PUBLIC;

-- Install PostGIS inside `extensions`
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- ----------------------------------------------------------------------------
-- Domain ENUM Types
-- ----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.app_role AS ENUM ('customer', 'driver', 'admin');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'driver_approval_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.driver_approval_status AS ENUM (
      'pending',
      'under_review',
      'approved',
      'rejected',
      'suspended'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.document_type AS ENUM (
      'national_id_front',
      'national_id_back',
      'driver_license_front',
      'driver_license_back',
      'winch_license_front',
      'winch_license_back',
      'criminal_record',
      'selfie_with_id'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_review_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.document_review_status AS ENUM ('pending', 'approved', 'rejected');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_category' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.vehicle_category AS ENUM (
      'sedan',
      'hatchback',
      'suv',
      'pickup',
      'van',
      'luxury_low_clearance',
      'motorcycle',
      'light_truck'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.trip_status AS ENUM (
      'searching',            -- في انتظار سائق
      'driver_assigned',      -- تم قبول الطلب وتعيين السائق
      'en_route_to_pickup',   -- السائق في الطريق لموقع العطل
      'arrived_at_pickup',    -- السائق وصل لموقع العطل
      'vehicle_loaded',       -- تم تحميل السيارة على الونش
      'en_route_to_dropoff',  -- في الطريق للوجهة
      'delivered',            -- تم التوصيل بنجاح
      'cancelled',            -- تم إلغاء الطلب
      'expired'               -- انتهت مهلة البحث دون قبول
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'offer_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.offer_status AS ENUM (
      'pending',
      'accepted',
      'rejected',
      'expired',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.payment_method AS ENUM ('cash', 'card', 'wallet');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'refunded', 'failed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_category' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.complaint_category AS ENUM (
      'pricing',
      'driver_behavior',
      'customer_behavior',
      'vehicle_damage',
      'delay',
      'app_issue',
      'other'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.complaint_status AS ENUM (
      'open',
      'in_progress',
      'resolved',
      'dismissed'
    );
  END IF;
END
$$;
