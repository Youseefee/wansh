-- ============================================================================
-- Wenshy (ونشي) - Migration 003: Security Helpers, Triggers & Data Guards
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Private RLS & Authorization Helper Functions
-- ----------------------------------------------------------------------------
-- Note:
-- - All helpers are placed in `private` (not exposed via Data API).
-- - `GRANT USAGE ON SCHEMA private` and `GRANT EXECUTE` on ONLY these safe
--   read-only predicate helpers are granted to `authenticated` so RLS policies
--   can evaluate them without `permission denied` errors.
-- - Every function uses `SET search_path = ''` and caches `(SELECT auth.uid())`.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'::public.app_role
      AND is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION private.current_user_role()
RETURNS public.app_role
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT role
  FROM public.profiles
  WHERE id = (SELECT auth.uid())
    AND is_active = true;
$$;

CREATE OR REPLACE FUNCTION private.is_driver_approved()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.drivers d
    JOIN public.profiles p ON p.id = d.id
    WHERE d.id = (SELECT auth.uid())
      AND p.role = 'driver'::public.app_role
      AND p.is_active = true
      AND d.approval_status = 'approved'::public.driver_approval_status
  );
$$;

-- Avoids RLS infinite recursion between `rescue_requests` and `dispatch_offers`
CREATE OR REPLACE FUNCTION private.driver_has_pending_offer(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dispatch_offers o
    WHERE o.request_id = p_request_id
      AND o.driver_id = (SELECT auth.uid())
      AND o.status = 'pending'::public.offer_status
      AND o.expires_at > now()
  );
$$;

CREATE OR REPLACE FUNCTION private.is_request_customer(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rescue_requests r
    WHERE r.id = p_request_id
      AND r.customer_id = (SELECT auth.uid())
  );
$$;

CREATE OR REPLACE FUNCTION private.is_trip_participant(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rescue_requests r
    WHERE r.id = p_request_id
      AND (
        r.customer_id = (SELECT auth.uid())
        OR r.driver_id = (SELECT auth.uid())
      )
  );
$$;

-- Allows customer and assigned driver to read each other's basic profile info
-- (name, phone, avatar) ONLY when linked by an assigned rescue request.
CREATE OR REPLACE FUNCTION private.is_active_trip_counterparty(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rescue_requests r
    WHERE r.status NOT IN ('searching'::public.trip_status, 'expired'::public.trip_status)
      AND (
        (r.customer_id = (SELECT auth.uid()) AND r.driver_id = p_profile_id)
        OR
        (r.driver_id = (SELECT auth.uid()) AND r.customer_id = p_profile_id)
      )
  );
$$;

-- Storage helper for `breakdown-photos`: path format `<customer_id>/<request_id>/<filename>`
CREATE OR REPLACE FUNCTION private.can_view_breakdown_photo(p_object_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
  v_parts text[];
  v_request_id uuid;
BEGIN
  IF (SELECT private.is_admin()) THEN
    RETURN true;
  END IF;

  v_parts := string_to_array(p_object_name, '/');
  IF array_length(v_parts, 1) < 2 THEN
    RETURN false;
  END IF;

  -- Owner folder always readable
  IF v_parts[1] = (SELECT auth.uid())::text THEN
    RETURN true;
  END IF;

  -- Validate 2nd segment is UUID before casting
  IF v_parts[2] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;

  v_request_id := v_parts[2]::uuid;

  RETURN EXISTS (
    SELECT 1
    FROM public.rescue_requests r
    WHERE r.id = v_request_id
      AND (
        r.driver_id = (SELECT auth.uid())
        OR (
          r.status = 'searching'::public.trip_status
          AND private.driver_has_pending_offer(r.id)
        )
      )
  );
END;
$$;

-- Realtime authorization helper for `realtime.messages` RLS
CREATE OR REPLACE FUNCTION private.can_access_realtime_topic(p_topic text, p_action text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_suffix text;
  v_target_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  IF (SELECT private.is_admin()) THEN
    RETURN true;
  END IF;

  -- 1. Private Trip Channel: `trip:<request_uuid>`
  IF p_topic LIKE 'trip:%' THEN
    v_suffix := substring(p_topic FROM 6);
    IF v_suffix !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RETURN false;
    END IF;
    v_target_id := v_suffix::uuid;

    IF p_action = 'SELECT' THEN
      -- Both customer and assigned driver can subscribe to receive broadcasts
      RETURN EXISTS (
        SELECT 1
        FROM public.rescue_requests r
        WHERE r.id = v_target_id
          AND (r.customer_id = v_uid OR r.driver_id = v_uid)
      );
    ELSIF p_action = 'INSERT' THEN
      -- ONLY the assigned driver on an active trip can broadcast live GPS coordinates
      RETURN EXISTS (
        SELECT 1
        FROM public.rescue_requests r
        WHERE r.id = v_target_id
          AND r.driver_id = v_uid
          AND r.status IN (
            'driver_assigned'::public.trip_status,
            'en_route_to_pickup'::public.trip_status,
            'arrived_at_pickup'::public.trip_status,
            'vehicle_loaded'::public.trip_status,
            'en_route_to_dropoff'::public.trip_status
          )
      );
    END IF;
    RETURN false;
  END IF;

  -- 2. Private Driver Dispatch Channel: `driver:<driver_uuid>`
  IF p_topic LIKE 'driver:%' THEN
    v_suffix := substring(p_topic FROM 8);
    IF v_suffix !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RETURN false;
    END IF;
    v_target_id := v_suffix::uuid;

    -- Drivers can only listen (SELECT) to their own dispatch notifications;
    -- DB triggers push offers (clients cannot spoof INSERT).
    IF p_action = 'SELECT' THEN
      RETURN v_target_id = v_uid;
    END IF;
    RETURN false;
  END IF;

  -- 3. Online Fleet Presence Channel: `fleet:online`
  IF p_topic = 'fleet:online' THEN
    IF p_action IN ('SELECT', 'INSERT') THEN
      RETURN (SELECT private.is_driver_approved());
    END IF;
    RETURN false;
  END IF;

  RETURN false;
END;
$$;

-- Grant minimal privileges on private RLS helpers
GRANT USAGE ON SCHEMA private TO authenticated, service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
  private.is_admin(),
  private.current_user_role(),
  private.is_driver_approved(),
  private.driver_has_pending_offer(uuid),
  private.is_request_customer(uuid),
  private.is_trip_participant(uuid),
  private.is_active_trip_counterparty(uuid),
  private.can_view_breakdown_photo(text),
  private.can_access_realtime_topic(text, text)
TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Generic `updated_at` Trigger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_customer_vehicles_updated_at
  BEFORE UPDATE ON public.customer_vehicles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_winch_types_updated_at
  BEFORE UPDATE ON public.winch_types
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_drivers_updated_at
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_driver_winches_updated_at
  BEFORE UPDATE ON public.driver_winches
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_driver_documents_updated_at
  BEFORE UPDATE ON public.driver_documents
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_rescue_requests_updated_at
  BEFORE UPDATE ON public.rescue_requests
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_dispatch_offers_updated_at
  BEFORE UPDATE ON public.dispatch_offers
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER trg_complaints_updated_at
  BEFORE UPDATE ON public.complaints
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

-- ----------------------------------------------------------------------------
-- 3. Auth Signup Sync Trigger (`auth.users` -> `public.profiles` / `drivers`)
-- ----------------------------------------------------------------------------
-- Security rule: Never trust `admin` role from client signup metadata.
-- Only `'customer'` or `'driver'` may be created via self-registration.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_raw_role text;
  v_safe_role public.app_role;
  v_full_name text;
  v_locale text;
  v_phone text;
BEGIN
  v_raw_role := lower(COALESCE(NEW.raw_user_meta_data ->> 'role', 'customer'));
  v_safe_role := CASE
    WHEN v_raw_role = 'driver' THEN 'driver'::public.app_role
    ELSE 'customer'::public.app_role
  END;

  v_full_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'name'), ''),
    ''
  );

  v_locale := CASE
    WHEN lower(COALESCE(NEW.raw_user_meta_data ->> 'locale', 'ar')) = 'en' THEN 'en'
    ELSE 'ar'
  END;

  v_phone := COALESCE(
    NULLIF(TRIM(NEW.phone), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'phone'), '')
  );

  INSERT INTO public.profiles (id, role, full_name, phone, email, locale)
  VALUES (NEW.id, v_safe_role, v_full_name, v_phone, NEW.email, v_locale)
  ON CONFLICT (id) DO NOTHING;

  IF v_safe_role = 'driver'::public.app_role THEN
    INSERT INTO public.drivers (
      id,
      national_id_number,
      license_number,
      approval_status
    )
    VALUES (
      NEW.id,
      NULLIF(TRIM(NEW.raw_user_meta_data ->> 'national_id_number'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data ->> 'license_number'), ''),
      'pending'::public.driver_approval_status
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();

-- ----------------------------------------------------------------------------
-- 4. PostGIS Geography Sync Triggers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.sync_driver_geography()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = extensions
AS $$
BEGIN
  IF NEW.current_lat IS NOT NULL AND NEW.current_lng IS NOT NULL THEN
    NEW.current_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(NEW.current_lng, NEW.current_lat),
      4326
    )::extensions.geography;
  ELSIF NEW.current_location IS NOT NULL THEN
    NEW.current_lat := extensions.ST_Y(NEW.current_location::extensions.geometry);
    NEW.current_lng := extensions.ST_X(NEW.current_location::extensions.geometry);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_drivers_sync_geography
  BEFORE INSERT OR UPDATE OF current_lat, current_lng, current_location
  ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION private.sync_driver_geography();

CREATE OR REPLACE FUNCTION private.sync_rescue_request_geography()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = extensions
AS $$
BEGIN
  NEW.pickup_location := extensions.ST_SetSRID(
    extensions.ST_MakePoint(NEW.pickup_lng, NEW.pickup_lat),
    4326
  )::extensions.geography;

  NEW.dropoff_location := extensions.ST_SetSRID(
    extensions.ST_MakePoint(NEW.dropoff_lng, NEW.dropoff_lat),
    4326
  )::extensions.geography;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rescue_requests_sync_geography
  BEFORE INSERT OR UPDATE OF pickup_lat, pickup_lng, dropoff_lat, dropoff_lng
  ON public.rescue_requests
  FOR EACH ROW EXECUTE FUNCTION private.sync_rescue_request_geography();

-- ----------------------------------------------------------------------------
-- 5. Privilege Escalation & Direct Mutation Guard Triggers
-- ----------------------------------------------------------------------------
-- Note: Direct client PostgREST calls execute with `current_user IN ('anon', 'authenticated')`.
-- Trusted `SECURITY DEFINER` RPCs execute with `current_user = 'postgres'`.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.guard_profile_updates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Only administrators can change user roles' USING ERRCODE = '42501';
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION 'Only administrators can activate or suspend accounts' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_guard_updates
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.guard_profile_updates();

CREATE OR REPLACE FUNCTION private.guard_driver_updates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF NEW.approval_status IS DISTINCT FROM OLD.approval_status
       OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
       OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
       OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at THEN
      RAISE EXCEPTION 'Approval workflow fields are managed by administrators only' USING ERRCODE = '42501';
    END IF;

    IF NEW.avg_rating IS DISTINCT FROM OLD.avg_rating
       OR NEW.total_ratings IS DISTINCT FROM OLD.total_ratings
       OR NEW.total_trips IS DISTINCT FROM OLD.total_trips
       OR NEW.total_earnings IS DISTINCT FROM OLD.total_earnings
       OR NEW.is_available IS DISTINCT FROM OLD.is_available THEN
      RAISE EXCEPTION 'System-managed driver metrics cannot be edited directly' USING ERRCODE = '42501';
    END IF;

    IF NEW.is_online = true AND OLD.approval_status <> 'approved'::public.driver_approval_status THEN
      RAISE EXCEPTION 'Driver account must be approved before going online' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_drivers_guard_updates
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION private.guard_driver_updates();

CREATE OR REPLACE FUNCTION private.guard_driver_winch_mutations()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified := false;
    ELSIF TG_OP = 'UPDATE' AND NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
      RAISE EXCEPTION 'Only administrators can verify winch vehicles' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_driver_winches_guard_mutations
  BEFORE INSERT OR UPDATE ON public.driver_winches
  FOR EACH ROW EXECUTE FUNCTION private.guard_driver_winch_mutations();

CREATE OR REPLACE FUNCTION private.guard_driver_document_mutations()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.review_status := 'pending'::public.document_review_status;
      NEW.rejection_reason := NULL;
      NEW.reviewed_by := NULL;
      NEW.reviewed_at := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.storage_path IS DISTINCT FROM OLD.storage_path THEN
        -- Re-uploading a document automatically resets review status to pending
        NEW.review_status := 'pending'::public.document_review_status;
        NEW.rejection_reason := NULL;
        NEW.reviewed_by := NULL;
        NEW.reviewed_at := NULL;
      ELSIF NEW.review_status IS DISTINCT FROM OLD.review_status
         OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
         OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
         OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at THEN
        RAISE EXCEPTION 'Only administrators can review driver documents' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_driver_documents_guard_mutations
  BEFORE INSERT OR UPDATE ON public.driver_documents
  FOR EACH ROW EXECUTE FUNCTION private.guard_driver_document_mutations();

CREATE OR REPLACE FUNCTION private.guard_rescue_request_updates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
       OR NEW.winch_type_id IS DISTINCT FROM OLD.winch_type_id
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.winch_id IS DISTINCT FROM OLD.winch_id
       OR NEW.estimated_price IS DISTINCT FROM OLD.estimated_price
       OR NEW.final_price IS DISTINCT FROM OLD.final_price
       OR NEW.base_fare_snapshot IS DISTINCT FROM OLD.base_fare_snapshot
       OR NEW.price_per_km_snapshot IS DISTINCT FROM OLD.price_per_km_snapshot
       OR NEW.geodesic_distance_km IS DISTINCT FROM OLD.geodesic_distance_km
       OR NEW.estimated_distance_km IS DISTINCT FROM OLD.estimated_distance_km
       OR NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
      RAISE EXCEPTION 'Trip state and pricing must be modified via Wenshy RPC functions' USING ERRCODE = '42501';
    END IF;

    IF OLD.status <> 'searching'::public.trip_status AND (
      NEW.pickup_lat IS DISTINCT FROM OLD.pickup_lat
      OR NEW.pickup_lng IS DISTINCT FROM OLD.pickup_lng
      OR NEW.dropoff_lat IS DISTINCT FROM OLD.dropoff_lat
      OR NEW.dropoff_lng IS DISTINCT FROM OLD.dropoff_lng
    ) THEN
      RAISE EXCEPTION 'Coordinates cannot be modified after a driver is assigned' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rescue_requests_guard_updates
  BEFORE UPDATE ON public.rescue_requests
  FOR EACH ROW EXECUTE FUNCTION private.guard_rescue_request_updates();

-- ----------------------------------------------------------------------------
-- 6. Ratings Validation & Driver Aggregate Recalculation Triggers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.validate_rating_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_req public.rescue_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = NEW.request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rescue request not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_req.status <> 'delivered'::public.trip_status THEN
    RAISE EXCEPTION 'Ratings can only be submitted after delivery' USING ERRCODE = 'P0001';
  END IF;

  IF v_req.customer_id <> NEW.customer_id OR v_req.driver_id IS DISTINCT FROM NEW.driver_id THEN
    RAISE EXCEPTION 'Rating customer/driver mismatch with trip record' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ratings_validate_insert
  BEFORE INSERT ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION private.validate_rating_insert();

CREATE OR REPLACE FUNCTION private.sync_driver_rating_stats()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  v_driver_id := COALESCE(NEW.driver_id, OLD.driver_id);

  UPDATE public.drivers d
  SET
    avg_rating = COALESCE((
      SELECT ROUND(AVG(r.score)::numeric, 2)
      FROM public.ratings r
      WHERE r.driver_id = v_driver_id
    ), 5.00),
    total_ratings = (
      SELECT COUNT(*)::integer
      FROM public.ratings r
      WHERE r.driver_id = v_driver_id
    )
  WHERE d.id = v_driver_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_ratings_sync_driver_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION private.sync_driver_rating_stats();

-- ----------------------------------------------------------------------------
-- 7. Complaint Validation & Protection Trigger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.guard_complaint_mutations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_req public.rescue_requests%ROWTYPE;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.request_id IS NOT NULL THEN
      SELECT * INTO v_req FROM public.rescue_requests WHERE id = NEW.request_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Referenced rescue request not found' USING ERRCODE = 'P0002';
      END IF;
      IF NOT (SELECT private.is_admin())
         AND NEW.reporter_id <> v_req.customer_id
         AND NEW.reporter_id IS DISTINCT FROM v_req.driver_id THEN
        RAISE EXCEPTION 'Only trip participants can file a complaint for this trip' USING ERRCODE = '42501';
      END IF;
    END IF;

    IF NOT (SELECT private.is_admin()) THEN
      NEW.status := 'open'::public.complaint_status;
      NEW.admin_notes := NULL;
      NEW.resolved_by := NULL;
      NEW.resolved_at := NULL;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
      IF NEW.status IS DISTINCT FROM OLD.status
         OR NEW.admin_notes IS DISTINCT FROM OLD.admin_notes
         OR NEW.resolved_by IS DISTINCT FROM OLD.resolved_by
         OR NEW.resolved_at IS DISTINCT FROM OLD.resolved_at
         OR NEW.reporter_id IS DISTINCT FROM OLD.reporter_id THEN
        RAISE EXCEPTION 'Only administrators can update complaint resolution fields' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_complaints_guard_mutations
  BEFORE INSERT OR UPDATE ON public.complaints
  FOR EACH ROW EXECUTE FUNCTION private.guard_complaint_mutations();

-- ----------------------------------------------------------------------------
-- 8. Supabase Realtime Broadcast Triggers (Private Channels)
-- ----------------------------------------------------------------------------
-- Broadcasts persistent DB changes to private channels:
--   - `trip:<request_id>` for Customer + Assigned Driver live trip updates
--   - `driver:<driver_id>` for Driver incoming dispatch offers
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.broadcast_rescue_request_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM realtime.broadcast_changes(
    'trip:' || COALESCE(NEW.id, OLD.id)::text,
    TG_OP,
    TG_OP,
    TG_TABLE_NAME,
    TG_TABLE_SCHEMA,
    NEW,
    OLD
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_rescue_requests_broadcast
  AFTER INSERT OR UPDATE OF status, driver_id, winch_id, final_price, payment_status
  ON public.rescue_requests
  FOR EACH ROW EXECUTE FUNCTION private.broadcast_rescue_request_changes();

CREATE OR REPLACE FUNCTION private.broadcast_dispatch_offer_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM realtime.broadcast_changes(
    'driver:' || COALESCE(NEW.driver_id, OLD.driver_id)::text,
    TG_OP,
    TG_OP,
    TG_TABLE_NAME,
    TG_TABLE_SCHEMA,
    NEW,
    OLD
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_dispatch_offers_broadcast
  AFTER INSERT OR UPDATE OF status
  ON public.dispatch_offers
  FOR EACH ROW EXECUTE FUNCTION private.broadcast_dispatch_offer_changes();

-- Add selected operational tables to `supabase_realtime` publication
-- (ideal for the Admin Web Dashboard using supabase-js Postgres Changes)
DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY['rescue_requests', 'drivers', 'driver_documents', 'complaints']
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_table
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', v_table);
    END IF;
  END LOOP;
END
$$;
