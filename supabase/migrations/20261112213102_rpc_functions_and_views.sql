-- ============================================================================
-- Wenshy (ونشي) - Migration 004: Core RPC Functions & Admin Views
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Quotation Calculation RPC (`calculate_winch_quote`)
-- ----------------------------------------------------------------------------
-- Computes geodesic distance using PostGIS geography (WGS84), applies either
-- a bounded Directions API distance or the winch type's road_factor, and
-- enforces minimum fare & surge multiplier server-side.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_winch_quote(
  p_winch_type_id     uuid,
  p_pickup_lat        double precision,
  p_pickup_lng        double precision,
  p_dropoff_lat       double precision,
  p_dropoff_lng       double precision,
  p_route_distance_km numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions
STABLE
AS $$
DECLARE
  v_winch            public.winch_types%ROWTYPE;
  v_pickup_geog      extensions.geography;
  v_dropoff_geog     extensions.geography;
  v_geodesic_km      numeric(10, 2);
  v_effective_km     numeric(10, 2);
  v_raw_fare         numeric(10, 2);
  v_estimated_price  numeric(10, 2);
  v_eta_minutes      integer;
BEGIN
  IF p_pickup_lat NOT BETWEEN -90 AND 90 OR p_pickup_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid pickup coordinates' USING ERRCODE = '22023';
  END IF;

  IF p_dropoff_lat NOT BETWEEN -90 AND 90 OR p_dropoff_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid dropoff coordinates' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_winch
  FROM public.winch_types
  WHERE id = p_winch_type_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Winch type not found or inactive' USING ERRCODE = 'P0002';
  END IF;

  v_pickup_geog := extensions.ST_SetSRID(extensions.ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::extensions.geography;
  v_dropoff_geog := extensions.ST_SetSRID(extensions.ST_MakePoint(p_dropoff_lng, p_dropoff_lat), 4326)::extensions.geography;

  v_geodesic_km := ROUND((extensions.ST_Distance(v_pickup_geog, v_dropoff_geog) / 1000.0)::numeric, 2);

  -- Guard against client price manipulation if optional route distance is provided
  IF p_route_distance_km IS NOT NULL THEN
    v_effective_km := ROUND(
      GREATEST(v_geodesic_km, LEAST(p_route_distance_km, GREATEST(v_geodesic_km * 3.0, 5.0)))::numeric,
      2
    );
  ELSE
    v_effective_km := ROUND((v_geodesic_km * v_winch.road_factor)::numeric, 2);
  END IF;

  v_raw_fare := v_winch.base_fare + (v_effective_km * v_winch.price_per_km);
  v_estimated_price := GREATEST(
    v_winch.minimum_fare,
    ROUND((v_raw_fare * v_winch.surge_multiplier)::numeric, 2)
  );

  -- Approximate towing duration assuming ~35 km/h urban average speed
  v_eta_minutes := GREATEST(5, CEIL((v_effective_km / 35.0) * 60.0)::integer);

  RETURN jsonb_build_object(
    'winch_type_id', v_winch.id,
    'winch_code', v_winch.code,
    'winch_name_ar', v_winch.name_ar,
    'winch_name_en', v_winch.name_en,
    'geodesic_distance_km', v_geodesic_km,
    'estimated_distance_km', v_effective_km,
    'estimated_duration_min', v_eta_minutes,
    'base_fare', v_winch.base_fare,
    'price_per_km', v_winch.price_per_km,
    'minimum_fare', v_winch.minimum_fare,
    'surge_multiplier', v_winch.surge_multiplier,
    'estimated_price', v_estimated_price,
    'min_price_range', GREATEST(v_winch.minimum_fare, ROUND((v_estimated_price * 0.95)::numeric, 2)),
    'max_price_range', ROUND((v_estimated_price * 1.10)::numeric, 2),
    'currency', 'EGP'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Find Nearest Available Approved Drivers (`find_nearest_drivers`)
-- ----------------------------------------------------------------------------
-- Uses PostGIS ST_DWithin + partial spatial GiST index to locate the closest
-- online, available, approved drivers operating a verified matching winch.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.find_nearest_drivers(
  p_pickup_lat         double precision,
  p_pickup_lng         double precision,
  p_winch_type_id      uuid,
  p_radius_meters      integer DEFAULT 15000,
  p_limit              integer DEFAULT 10,
  p_exclude_request_id uuid DEFAULT NULL
)
RETURNS TABLE (
  driver_id        uuid,
  winch_id         uuid,
  full_name        text,
  avatar_url       text,
  avg_rating       numeric(3, 2),
  total_trips      integer,
  winch_brand      text,
  winch_model      text,
  plate_number     text,
  current_lat      double precision,
  current_lng      double precision,
  distance_meters  integer,
  eta_minutes      integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions
STABLE
AS $$
DECLARE
  v_pickup_geog extensions.geography;
  v_safe_limit  integer;
  v_safe_radius integer;
BEGIN
  IF current_user IN ('anon', 'authenticated') AND (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_pickup_lat NOT BETWEEN -90 AND 90 OR p_pickup_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid pickup coordinates' USING ERRCODE = '22023';
  END IF;

  v_safe_limit := LEAST(GREATEST(COALESCE(p_limit, 10), 1), 50);
  v_safe_radius := LEAST(GREATEST(COALESCE(p_radius_meters, 15000), 500), 100000);

  v_pickup_geog := extensions.ST_SetSRID(
    extensions.ST_MakePoint(p_pickup_lng, p_pickup_lat),
    4326
  )::extensions.geography;

  RETURN QUERY
  WITH per_driver AS (
    SELECT DISTINCT ON (d.id)
      d.id AS driver_id,
      dw.id AS winch_id,
      p.full_name,
      p.avatar_url,
      d.avg_rating,
      d.total_trips,
      dw.brand AS winch_brand,
      dw.model AS winch_model,
      dw.plate_number,
      d.current_lat,
      d.current_lng,
      ROUND(extensions.ST_Distance(d.current_location, v_pickup_geog))::integer AS distance_meters,
      GREATEST(3, CEIL((extensions.ST_Distance(d.current_location, v_pickup_geog) / 1000.0 / 30.0) * 60.0)::integer) AS eta_minutes
    FROM public.drivers d
    JOIN public.profiles p
      ON p.id = d.id
    JOIN public.driver_winches dw
      ON dw.driver_id = d.id
    WHERE d.approval_status = 'approved'::public.driver_approval_status
      AND d.is_online = true
      AND d.is_available = true
      AND d.current_location IS NOT NULL
      AND d.last_location_at >= (now() - interval '10 minutes')
      AND p.is_active = true
      AND dw.winch_type_id = p_winch_type_id
      AND dw.is_active = true
      AND dw.is_verified = true
      AND extensions.ST_DWithin(d.current_location, v_pickup_geog, v_safe_radius)
      AND (
        p_exclude_request_id IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM public.dispatch_offers o
          WHERE o.request_id = p_exclude_request_id
            AND o.driver_id = d.id
        )
      )
    ORDER BY
      d.id,
      dw.created_at ASC
  )
  SELECT pd.*
  FROM per_driver pd
  ORDER BY pd.distance_meters ASC, pd.avg_rating DESC
  LIMIT v_safe_limit;
END;
$$;

-- Note: Wrapping `find_nearest_drivers` sorted by distance in a helper query when dispatching
-- lets DISTINCT ON (d.id) pick 1 winch per driver and then sort globally by distance_meters ASC.

-- ----------------------------------------------------------------------------
-- 3. Dispatch Rescue Request to Nearest Drivers (`dispatch_rescue_request`)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_rescue_request(
  p_request_id         uuid,
  p_radius_meters      integer DEFAULT 15000,
  p_wave_number        integer DEFAULT 1,
  p_batch_size         integer DEFAULT 5,
  p_offer_ttl_seconds  integer DEFAULT 45
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions
AS $$
DECLARE
  v_uid              uuid := (SELECT auth.uid());
  v_req              public.rescue_requests%ROWTYPE;
  v_dispatched_count integer := 0;
  v_expires_at       timestamptz;
BEGIN
  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rescue request not found' USING ERRCODE = 'P0002';
  END IF;

  IF current_user IN ('anon', 'authenticated')
     AND v_req.customer_id <> v_uid
     AND NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Not authorized to dispatch this rescue request' USING ERRCODE = '42501';
  END IF;

  IF v_req.status <> 'searching'::public.trip_status THEN
    RETURN jsonb_build_object(
      'request_id', v_req.id,
      'status', v_req.status,
      'dispatched_count', 0,
      'message', 'Request is no longer searching'
    );
  END IF;

  -- Expire timed-out pending offers before issuing next wave
  UPDATE public.dispatch_offers
  SET status = 'expired'::public.offer_status,
      responded_at = now()
  WHERE request_id = v_req.id
    AND status = 'pending'::public.offer_status
    AND expires_at <= now();

  v_expires_at := now() + make_interval(secs => LEAST(GREATEST(COALESCE(p_offer_ttl_seconds, 45), 15), 180));

  WITH ranked_candidates AS (
    SELECT *
    FROM public.find_nearest_drivers(
      v_req.pickup_lat,
      v_req.pickup_lng,
      v_req.winch_type_id,
      p_radius_meters,
      50,
      v_req.id
    )
    ORDER BY distance_meters ASC, avg_rating DESC
    LIMIT LEAST(GREATEST(COALESCE(p_batch_size, 5), 1), 15)
  ),
  inserted_offers AS (
    INSERT INTO public.dispatch_offers (
      request_id,
      driver_id,
      winch_id,
      distance_meters,
      eta_minutes,
      wave_number,
      status,
      expires_at
    )
    SELECT
      v_req.id,
      c.driver_id,
      c.winch_id,
      c.distance_meters,
      c.eta_minutes,
      GREATEST(COALESCE(p_wave_number, 1), 1),
      'pending'::public.offer_status,
      v_expires_at
    FROM ranked_candidates c
    ON CONFLICT (request_id, driver_id) DO NOTHING
    RETURNING id
  )
  SELECT COUNT(*)::integer INTO v_dispatched_count
  FROM inserted_offers;

  UPDATE public.rescue_requests
  SET current_wave = GREATEST(current_wave, COALESCE(p_wave_number, 1))
  WHERE id = v_req.id;

  RETURN jsonb_build_object(
    'request_id', v_req.id,
    'wave_number', p_wave_number,
    'radius_meters', p_radius_meters,
    'dispatched_count', v_dispatched_count,
    'expires_at', v_expires_at
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Create Rescue Request + Auto-Quote + Wave 1 Dispatch
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_rescue_request(
  p_winch_type_id          uuid,
  p_pickup_lat             double precision,
  p_pickup_lng             double precision,
  p_pickup_address         text,
  p_dropoff_lat            double precision,
  p_dropoff_lng            double precision,
  p_dropoff_address        text,
  p_customer_vehicle_id    uuid DEFAULT NULL,
  p_vehicle_make           text DEFAULT NULL,
  p_vehicle_model          text DEFAULT NULL,
  p_vehicle_year           smallint DEFAULT NULL,
  p_vehicle_color          text DEFAULT NULL,
  p_vehicle_plate          text DEFAULT NULL,
  p_vehicle_category       public.vehicle_category DEFAULT 'sedan',
  p_breakdown_reason       text DEFAULT NULL,
  p_breakdown_notes        text DEFAULT NULL,
  p_breakdown_photo_paths  text[] DEFAULT '{}',
  p_payment_method         public.payment_method DEFAULT 'cash',
  p_route_distance_km      numeric DEFAULT NULL,
  p_initial_radius_meters  integer DEFAULT 15000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions
AS $$
DECLARE
  v_uid           uuid := (SELECT auth.uid());
  v_profile       public.profiles%ROWTYPE;
  v_vehicle       public.customer_vehicles%ROWTYPE;
  v_quote         jsonb;
  v_request       public.rescue_requests%ROWTYPE;
  v_dispatch      jsonb;
  v_make          text := p_vehicle_make;
  v_model         text := p_vehicle_model;
  v_year          smallint := p_vehicle_year;
  v_color         text := p_vehicle_color;
  v_plate         text := p_vehicle_plate;
  v_category      public.vehicle_category := COALESCE(p_vehicle_category, 'sedan'::public.vehicle_category);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid;
  IF NOT FOUND OR v_profile.is_active = false THEN
    RAISE EXCEPTION 'Account is inactive or missing profile' USING ERRCODE = '42501';
  END IF;

  IF p_customer_vehicle_id IS NOT NULL THEN
    SELECT * INTO v_vehicle
    FROM public.customer_vehicles
    WHERE id = p_customer_vehicle_id
      AND customer_id = v_uid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Selected vehicle does not belong to user' USING ERRCODE = '42501';
    END IF;

    v_make := COALESCE(NULLIF(TRIM(v_make), ''), v_vehicle.make);
    v_model := COALESCE(NULLIF(TRIM(v_model), ''), v_vehicle.model);
    v_year := COALESCE(v_year, v_vehicle.year);
    v_color := COALESCE(NULLIF(TRIM(v_color), ''), v_vehicle.color);
    v_plate := COALESCE(NULLIF(TRIM(v_plate), ''), v_vehicle.plate_number);
    v_category := v_vehicle.vehicle_category;
  END IF;

  -- Authoritative server-side quote calculation
  v_quote := public.calculate_winch_quote(
    p_winch_type_id,
    p_pickup_lat,
    p_pickup_lng,
    p_dropoff_lat,
    p_dropoff_lng,
    p_route_distance_km
  );

  INSERT INTO public.rescue_requests (
    customer_id,
    winch_type_id,
    customer_vehicle_id,
    vehicle_make,
    vehicle_model,
    vehicle_year,
    vehicle_color,
    vehicle_plate,
    vehicle_category,
    breakdown_reason,
    breakdown_notes,
    breakdown_photo_paths,
    pickup_lat,
    pickup_lng,
    pickup_location,
    pickup_address,
    dropoff_lat,
    dropoff_lng,
    dropoff_location,
    dropoff_address,
    geodesic_distance_km,
    estimated_distance_km,
    estimated_duration_min,
    base_fare_snapshot,
    price_per_km_snapshot,
    estimated_price,
    currency,
    payment_method,
    status
  )
  VALUES (
    v_uid,
    p_winch_type_id,
    p_customer_vehicle_id,
    v_make,
    v_model,
    v_year,
    v_color,
    v_plate,
    v_category,
    p_breakdown_reason,
    p_breakdown_notes,
    COALESCE(p_breakdown_photo_paths, '{}'),
    p_pickup_lat,
    p_pickup_lng,
    extensions.ST_SetSRID(extensions.ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::extensions.geography,
    p_pickup_address,
    p_dropoff_lat,
    p_dropoff_lng,
    extensions.ST_SetSRID(extensions.ST_MakePoint(p_dropoff_lng, p_dropoff_lat), 4326)::extensions.geography,
    p_dropoff_address,
    (v_quote ->> 'geodesic_distance_km')::numeric,
    (v_quote ->> 'estimated_distance_km')::numeric,
    (v_quote ->> 'estimated_duration_min')::integer,
    (v_quote ->> 'base_fare')::numeric,
    (v_quote ->> 'price_per_km')::numeric,
    (v_quote ->> 'estimated_price')::numeric,
    v_quote ->> 'currency',
    COALESCE(p_payment_method, 'cash'::public.payment_method),
    'searching'::public.trip_status
  )
  RETURNING * INTO v_request;

  INSERT INTO public.trip_status_logs (
    request_id,
    from_status,
    to_status,
    changed_by,
    lat,
    lng,
    notes
  )
  VALUES (
    v_request.id,
    NULL,
    'searching'::public.trip_status,
    v_uid,
    p_pickup_lat,
    p_pickup_lng,
    'Rescue request created'
  );

  v_dispatch := public.dispatch_rescue_request(
    v_request.id,
    COALESCE(p_initial_radius_meters, 15000),
    1,
    5,
    45
  );

  RETURN jsonb_build_object(
    'request', to_jsonb(v_request),
    'quote', v_quote,
    'dispatch', v_dispatch
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Driver Accepts Rescue Offer (`accept_rescue_offer`) — Race-Condition Safe
-- ----------------------------------------------------------------------------
-- Uses `FOR UPDATE SKIP LOCKED` on `rescue_requests` to ensure at most ONE
-- driver can claim a rescue request even under concurrent tap collisions.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_rescue_offer(
  p_offer_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_id uuid := (SELECT auth.uid());
  v_offer     public.dispatch_offers%ROWTYPE;
  v_driver    public.drivers%ROWTYPE;
  v_req       public.rescue_requests%ROWTYPE;
BEGIN
  IF v_driver_id IS NULL OR NOT (SELECT private.is_driver_approved()) THEN
    RAISE EXCEPTION 'Only approved drivers can accept rescue offers' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_offer
  FROM public.dispatch_offers
  WHERE id = p_offer_id
    AND driver_id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dispatch offer not found for this driver' USING ERRCODE = 'P0002';
  END IF;

  IF v_offer.status <> 'pending'::public.offer_status THEN
    RETURN jsonb_build_object(
      'accepted', false,
      'reason', 'offer_already_processed',
      'offer_status', v_offer.status
    );
  END IF;

  IF v_offer.expires_at <= now() THEN
    UPDATE public.dispatch_offers
    SET status = 'expired'::public.offer_status,
        responded_at = now()
    WHERE id = v_offer.id;

    RETURN jsonb_build_object(
      'accepted', false,
      'reason', 'offer_expired'
    );
  END IF;

  SELECT * INTO v_driver
  FROM public.drivers
  WHERE id = v_driver_id
  FOR UPDATE;

  IF NOT v_driver.is_online OR NOT v_driver.is_available THEN
    RETURN jsonb_build_object(
      'accepted', false,
      'reason', 'driver_not_available'
    );
  END IF;

  -- Atomic non-blocking row claim on rescue_requests
  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = v_offer.request_id
    AND status = 'searching'::public.trip_status
    AND driver_id IS NULL
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    UPDATE public.dispatch_offers
    SET status = 'cancelled'::public.offer_status,
        responded_at = now()
    WHERE id = v_offer.id;

    RETURN jsonb_build_object(
      'accepted', false,
      'reason', 'request_already_assigned_or_cancelled'
    );
  END IF;

  -- Claim trip
  UPDATE public.rescue_requests
  SET driver_id = v_driver_id,
      winch_id = v_offer.winch_id,
      status = 'driver_assigned'::public.trip_status,
      accepted_at = now()
  WHERE id = v_req.id;

  -- Mark winning offer accepted & cancel competing offers
  UPDATE public.dispatch_offers
  SET status = 'accepted'::public.offer_status,
      responded_at = now()
  WHERE id = v_offer.id;

  UPDATE public.dispatch_offers
  SET status = 'cancelled'::public.offer_status,
      responded_at = now()
  WHERE request_id = v_req.id
    AND id <> v_offer.id
    AND status = 'pending'::public.offer_status;

  -- Mark driver busy
  UPDATE public.drivers
  SET is_available = false
  WHERE id = v_driver_id;

  INSERT INTO public.trip_status_logs (
    request_id,
    from_status,
    to_status,
    changed_by,
    lat,
    lng,
    notes
  )
  VALUES (
    v_req.id,
    'searching'::public.trip_status,
    'driver_assigned'::public.trip_status,
    v_driver_id,
    v_driver.current_lat,
    v_driver.current_lng,
    'Driver accepted dispatch offer'
  );

  RETURN jsonb_build_object(
    'accepted', true,
    'request_id', v_req.id,
    'request_code', v_req.request_code,
    'status', 'driver_assigned'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. Driver Rejects Offer (`reject_rescue_offer`)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_rescue_offer(
  p_offer_id uuid,
  p_reason   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_id uuid := (SELECT auth.uid());
  v_updated   boolean := false;
BEGIN
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.dispatch_offers
  SET status = 'rejected'::public.offer_status,
      rejection_reason = p_reason,
      responded_at = now()
  WHERE id = p_offer_id
    AND driver_id = v_driver_id
    AND status = 'pending'::public.offer_status;

  v_updated := FOUND;

  RETURN jsonb_build_object(
    'offer_id', p_offer_id,
    'rejected', v_updated
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. Update Trip Lifecycle Stage (`driver_update_trip_stage`)
-- ----------------------------------------------------------------------------
-- Enforces strict state machine transitions:
--   driver_assigned    -> en_route_to_pickup
--   en_route_to_pickup -> arrived_at_pickup
--   arrived_at_pickup  -> vehicle_loaded
--   vehicle_loaded     -> en_route_to_dropoff
--   en_route_to_dropoff -> delivered
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.driver_update_trip_stage(
  p_request_id  uuid,
  p_new_status  public.trip_status,
  p_lat         double precision DEFAULT NULL,
  p_lng         double precision DEFAULT NULL,
  p_notes       text DEFAULT NULL,
  p_final_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid         uuid := (SELECT auth.uid());
  v_req         public.rescue_requests%ROWTYPE;
  v_valid       boolean := false;
  v_final_price numeric(10, 2);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rescue request not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_req.driver_id IS DISTINCT FROM v_uid AND NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Only the assigned driver can update trip stages' USING ERRCODE = '42501';
  END IF;

  v_valid := CASE v_req.status
    WHEN 'driver_assigned'::public.trip_status    THEN p_new_status IN ('en_route_to_pickup'::public.trip_status, 'arrived_at_pickup'::public.trip_status)
    WHEN 'en_route_to_pickup'::public.trip_status THEN p_new_status = 'arrived_at_pickup'::public.trip_status
    WHEN 'arrived_at_pickup'::public.trip_status  THEN p_new_status = 'vehicle_loaded'::public.trip_status
    WHEN 'vehicle_loaded'::public.trip_status     THEN p_new_status = 'en_route_to_dropoff'::public.trip_status
    WHEN 'en_route_to_dropoff'::public.trip_status THEN p_new_status = 'delivered'::public.trip_status
    ELSE false
  END;

  IF NOT v_valid THEN
    RAISE EXCEPTION 'Invalid trip status transition from % to %', v_req.status, p_new_status
      USING ERRCODE = 'P0001';
  END IF;

  IF p_new_status = 'delivered'::public.trip_status THEN
    IF p_final_price IS NOT NULL THEN
      IF p_final_price < v_req.base_fare_snapshot
         OR p_final_price > GREATEST(v_req.base_fare_snapshot, v_req.estimated_price * 1.50) THEN
        RAISE EXCEPTION 'Final price outside allowed variance bounds' USING ERRCODE = '22023';
      END IF;
      v_final_price := ROUND(p_final_price, 2);
    ELSE
      v_final_price := v_req.estimated_price;
    END IF;
  END IF;

  UPDATE public.rescue_requests
  SET
    status = p_new_status,
    en_route_at = CASE WHEN p_new_status = 'en_route_to_pickup'::public.trip_status THEN COALESCE(en_route_at, now()) ELSE en_route_at END,
    arrived_at = CASE WHEN p_new_status = 'arrived_at_pickup'::public.trip_status THEN COALESCE(arrived_at, now()) ELSE arrived_at END,
    loaded_at = CASE WHEN p_new_status = 'vehicle_loaded'::public.trip_status THEN COALESCE(loaded_at, now()) ELSE loaded_at END,
    dropoff_started_at = CASE WHEN p_new_status = 'en_route_to_dropoff'::public.trip_status THEN COALESCE(dropoff_started_at, now()) ELSE dropoff_started_at END,
    completed_at = CASE WHEN p_new_status = 'delivered'::public.trip_status THEN now() ELSE completed_at END,
    final_price = CASE WHEN p_new_status = 'delivered'::public.trip_status THEN v_final_price ELSE final_price END,
    payment_status = CASE
      WHEN p_new_status = 'delivered'::public.trip_status AND payment_method = 'cash'::public.payment_method
        THEN 'paid'::public.payment_status
      ELSE payment_status
    END
  WHERE id = v_req.id;

  IF p_new_status = 'delivered'::public.trip_status THEN
    UPDATE public.drivers
    SET is_available = true,
        total_trips = total_trips + 1,
        total_earnings = total_earnings + v_final_price
    WHERE id = v_req.driver_id;
  END IF;

  INSERT INTO public.trip_status_logs (
    request_id,
    from_status,
    to_status,
    changed_by,
    lat,
    lng,
    notes
  )
  VALUES (
    v_req.id,
    v_req.status,
    p_new_status,
    v_uid,
    p_lat,
    p_lng,
    p_notes
  );

  RETURN jsonb_build_object(
    'request_id', v_req.id,
    'from_status', v_req.status,
    'to_status', p_new_status,
    'final_price', v_final_price,
    'updated_at', now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. Cancel Rescue Request (`cancel_rescue_request`)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_rescue_request(
  p_request_id uuid,
  p_reason     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid      uuid := (SELECT auth.uid());
  v_is_admin boolean := (SELECT private.is_admin());
  v_req      public.rescue_requests%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rescue request not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT v_is_admin
     AND v_req.customer_id <> v_uid
     AND v_req.driver_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Not authorized to cancel this rescue request' USING ERRCODE = '42501';
  END IF;

  IF NOT v_is_admin AND v_req.status NOT IN (
    'searching'::public.trip_status,
    'driver_assigned'::public.trip_status,
    'en_route_to_pickup'::public.trip_status,
    'arrived_at_pickup'::public.trip_status
  ) THEN
    RAISE EXCEPTION 'Cannot cancel trip after vehicle has been loaded (current status: %)', v_req.status
      USING ERRCODE = 'P0001';
  END IF;

  IF v_req.status IN ('delivered'::public.trip_status, 'cancelled'::public.trip_status, 'expired'::public.trip_status) THEN
    RETURN jsonb_build_object(
      'request_id', v_req.id,
      'cancelled', false,
      'status', v_req.status
    );
  END IF;

  UPDATE public.rescue_requests
  SET status = 'cancelled'::public.trip_status,
      cancellation_reason = p_reason,
      cancelled_by = v_uid,
      cancelled_at = now()
  WHERE id = v_req.id;

  UPDATE public.dispatch_offers
  SET status = 'cancelled'::public.offer_status,
      responded_at = now()
  WHERE request_id = v_req.id
    AND status = 'pending'::public.offer_status;

  IF v_req.driver_id IS NOT NULL THEN
    UPDATE public.drivers
    SET is_available = true
    WHERE id = v_req.driver_id;
  END IF;

  INSERT INTO public.trip_status_logs (
    request_id,
    from_status,
    to_status,
    changed_by,
    notes
  )
  VALUES (
    v_req.id,
    v_req.status,
    'cancelled'::public.trip_status,
    v_uid,
    COALESCE(p_reason, 'Trip cancelled')
  );

  RETURN jsonb_build_object(
    'request_id', v_req.id,
    'cancelled', true,
    'status', 'cancelled'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. Driver Live Location & Availability Sync (`driver_update_location`)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.driver_update_location(
  p_lat               double precision,
  p_lng               double precision,
  p_heading           numeric DEFAULT NULL,
  p_speed_kmh         numeric DEFAULT NULL,
  p_is_online         boolean DEFAULT NULL,
  p_active_request_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions
AS $$
DECLARE
  v_driver_id uuid := (SELECT auth.uid());
  v_driver    public.drivers%ROWTYPE;
BEGIN
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_lat NOT BETWEEN -90 AND 90 OR p_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid coordinates' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_driver
  FROM public.drivers
  WHERE id = v_driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver profile not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_is_online = true AND v_driver.approval_status <> 'approved'::public.driver_approval_status THEN
    RAISE EXCEPTION 'Driver account must be approved before going online' USING ERRCODE = '42501';
  END IF;

  UPDATE public.drivers
  SET
    current_lat = p_lat,
    current_lng = p_lng,
    current_heading = COALESCE(p_heading, current_heading),
    current_speed_kmh = COALESCE(p_speed_kmh, current_speed_kmh),
    is_online = COALESCE(p_is_online, is_online),
    last_location_at = now()
  WHERE id = v_driver_id;

  -- Optionally store throttled breadcrumb for active trip audit trail
  IF p_active_request_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.rescue_requests r
      WHERE r.id = p_active_request_id
        AND r.driver_id = v_driver_id
        AND r.status IN (
          'driver_assigned'::public.trip_status,
          'en_route_to_pickup'::public.trip_status,
          'arrived_at_pickup'::public.trip_status,
          'vehicle_loaded'::public.trip_status,
          'en_route_to_dropoff'::public.trip_status
        )
    ) THEN
      INSERT INTO public.trip_location_history (
        request_id,
        driver_id,
        lat,
        lng,
        heading,
        speed_kmh
      )
      VALUES (
        p_active_request_id,
        v_driver_id,
        p_lat,
        p_lng,
        p_heading,
        p_speed_kmh
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'driver_id', v_driver_id,
    'lat', p_lat,
    'lng', p_lng,
    'recorded_at', now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. Admin Workflow RPCs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_review_driver(
  p_driver_id        uuid,
  p_decision         public.driver_approval_status,
  p_rejection_reason text DEFAULT NULL,
  p_verify_winches   boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := (SELECT auth.uid());
BEGIN
  IF NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.drivers
  SET
    approval_status = p_decision,
    rejection_reason = CASE WHEN p_decision IN ('rejected'::public.driver_approval_status, 'suspended'::public.driver_approval_status) THEN p_rejection_reason ELSE NULL END,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    is_online = CASE WHEN p_decision <> 'approved'::public.driver_approval_status THEN false ELSE is_online END
  WHERE id = p_driver_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_decision = 'approved'::public.driver_approval_status AND p_verify_winches THEN
    UPDATE public.driver_winches
    SET is_verified = true
    WHERE driver_id = p_driver_id
      AND is_active = true;
  END IF;

  RETURN jsonb_build_object(
    'driver_id', p_driver_id,
    'approval_status', p_decision,
    'reviewed_by', v_admin_id,
    'reviewed_at', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_document(
  p_document_id      uuid,
  p_status           public.document_review_status,
  p_rejection_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := (SELECT auth.uid());
BEGIN
  IF NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.driver_documents
  SET
    review_status = p_status,
    rejection_reason = CASE WHEN p_status = 'rejected'::public.document_review_status THEN p_rejection_reason ELSE NULL END,
    reviewed_by = v_admin_id,
    reviewed_at = now()
  WHERE id = p_document_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'document_id', p_document_id,
    'review_status', p_status,
    'reviewed_by', v_admin_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_complaint(
  p_complaint_id uuid,
  p_status       public.complaint_status,
  p_admin_notes  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := (SELECT auth.uid());
BEGIN
  IF NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.complaints
  SET
    status = p_status,
    admin_notes = COALESCE(p_admin_notes, admin_notes),
    resolved_by = CASE WHEN p_status IN ('resolved'::public.complaint_status, 'dismissed'::public.complaint_status) THEN v_admin_id ELSE resolved_by END,
    resolved_at = CASE WHEN p_status IN ('resolved'::public.complaint_status, 'dismissed'::public.complaint_status) THEN now() ELSE resolved_at END
  WHERE id = p_complaint_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complaint not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'complaint_id', p_complaint_id,
    'status', p_status,
    'resolved_by', v_admin_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_active(
  p_user_id   uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles
  SET is_active = p_is_active
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_is_active = false THEN
    UPDATE public.drivers
    SET is_online = false
    WHERE id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'is_active', p_is_active
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
BEGIN
  IF NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'total_customers', (SELECT COUNT(*) FROM public.profiles WHERE role = 'customer'::public.app_role),
    'total_drivers', (SELECT COUNT(*) FROM public.drivers),
    'approved_drivers', (SELECT COUNT(*) FROM public.drivers WHERE approval_status = 'approved'::public.driver_approval_status),
    'pending_driver_approvals', (SELECT COUNT(*) FROM public.drivers WHERE approval_status IN ('pending'::public.driver_approval_status, 'under_review'::public.driver_approval_status)),
    'online_drivers_now', (SELECT COUNT(*) FROM public.drivers WHERE approval_status = 'approved'::public.driver_approval_status AND is_online = true AND last_location_at >= now() - interval '10 minutes'),
    'searching_requests_now', (SELECT COUNT(*) FROM public.rescue_requests WHERE status = 'searching'::public.trip_status),
    'active_trips_now', (SELECT COUNT(*) FROM public.rescue_requests WHERE status IN ('driver_assigned'::public.trip_status, 'en_route_to_pickup'::public.trip_status, 'arrived_at_pickup'::public.trip_status, 'vehicle_loaded'::public.trip_status, 'en_route_to_dropoff'::public.trip_status)),
    'delivered_today', (SELECT COUNT(*) FROM public.rescue_requests WHERE status = 'delivered'::public.trip_status AND completed_at >= date_trunc('day', now())),
    'revenue_today', (SELECT COALESCE(SUM(COALESCE(final_price, estimated_price)), 0) FROM public.rescue_requests WHERE status = 'delivered'::public.trip_status AND completed_at >= date_trunc('day', now())),
    'open_complaints', (SELECT COUNT(*) FROM public.complaints WHERE status IN ('open'::public.complaint_status, 'in_progress'::public.complaint_status)),
    'average_driver_rating', (SELECT COALESCE(ROUND(AVG(score)::numeric, 2), 5.00) FROM public.ratings)
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. Admin Dashboard Views (`WITH (security_invoker = true)` - Postgres 15+)
-- ----------------------------------------------------------------------------
-- Important: Always set `security_invoker = true` so views never bypass RLS.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_admin_driver_applications
WITH (security_invoker = true) AS
SELECT
  d.id AS driver_id,
  p.full_name,
  p.phone,
  p.email,
  p.avatar_url,
  p.is_active,
  d.national_id_number,
  d.license_number,
  d.license_expiry,
  d.approval_status,
  d.rejection_reason,
  d.reviewed_at,
  d.is_online,
  d.is_available,
  d.avg_rating,
  d.total_trips,
  d.created_at,
  COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'winch_id', dw.id,
          'winch_type_id', dw.winch_type_id,
          'winch_type_ar', wt.name_ar,
          'winch_type_en', wt.name_en,
          'plate_number', dw.plate_number,
          'brand', dw.brand,
          'model', dw.model,
          'year', dw.year,
          'is_verified', dw.is_verified,
          'is_active', dw.is_active,
          'photo_paths', dw.photo_paths
        )
      )
      FROM public.driver_winches dw
      JOIN public.winch_types wt ON wt.id = dw.winch_type_id
      WHERE dw.driver_id = d.id
    ),
    '[]'::jsonb
  ) AS winches,
  COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'document_id', doc.id,
          'document_type', doc.document_type,
          'storage_path', doc.storage_path,
          'review_status', doc.review_status,
          'rejection_reason', doc.rejection_reason,
          'expires_at', doc.expires_at,
          'updated_at', doc.updated_at
        )
      )
      FROM public.driver_documents doc
      WHERE doc.driver_id = d.id
    ),
    '[]'::jsonb
  ) AS documents
FROM public.drivers d
JOIN public.profiles p ON p.id = d.id;

CREATE OR REPLACE VIEW public.v_admin_active_trips
WITH (security_invoker = true) AS
SELECT
  r.id,
  r.request_code,
  r.status,
  r.created_at,
  r.accepted_at,
  r.pickup_lat,
  r.pickup_lng,
  r.pickup_address,
  r.dropoff_lat,
  r.dropoff_lng,
  r.dropoff_address,
  r.estimated_distance_km,
  r.estimated_price,
  r.final_price,
  r.payment_method,
  wt.name_ar AS winch_type_ar,
  wt.name_en AS winch_type_en,
  c.id AS customer_id,
  c.full_name AS customer_name,
  c.phone AS customer_phone,
  dp.id AS driver_id,
  dp.full_name AS driver_name,
  dp.phone AS driver_phone,
  d.current_lat AS driver_lat,
  d.current_lng AS driver_lng,
  dw.plate_number AS winch_plate_number
FROM public.rescue_requests r
JOIN public.winch_types wt ON wt.id = r.winch_type_id
JOIN public.profiles c ON c.id = r.customer_id
LEFT JOIN public.drivers d ON d.id = r.driver_id
LEFT JOIN public.profiles dp ON dp.id = d.id
LEFT JOIN public.driver_winches dw ON dw.id = r.winch_id
WHERE r.status NOT IN ('delivered'::public.trip_status, 'cancelled'::public.trip_status, 'expired'::public.trip_status);

CREATE OR REPLACE VIEW public.v_admin_complaints_queue
WITH (security_invoker = true) AS
SELECT
  cmp.id,
  cmp.complaint_code,
  cmp.category,
  cmp.status,
  cmp.subject,
  cmp.description,
  cmp.evidence_paths,
  cmp.admin_notes,
  cmp.created_at,
  cmp.resolved_at,
  r.id AS request_id,
  r.request_code,
  rep.id AS reporter_id,
  rep.full_name AS reporter_name,
  rep.phone AS reporter_phone,
  rep.role AS reporter_role,
  tgt.id AS reported_user_id,
  tgt.full_name AS reported_user_name,
  tgt.role AS reported_user_role
FROM public.complaints cmp
JOIN public.profiles rep ON rep.id = cmp.reporter_id
LEFT JOIN public.profiles tgt ON tgt.id = cmp.reported_user_id
LEFT JOIN public.rescue_requests r ON r.id = cmp.request_id;

-- ----------------------------------------------------------------------------
-- 12. Explicit Function Execution Grants
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION
  public.calculate_winch_quote(uuid, double precision, double precision, double precision, double precision, numeric),
  public.find_nearest_drivers(double precision, double precision, uuid, integer, integer, uuid),
  public.dispatch_rescue_request(uuid, integer, integer, integer, integer),
  public.create_rescue_request(uuid, double precision, double precision, text, double precision, double precision, text, uuid, text, text, smallint, text, text, public.vehicle_category, text, text, text[], public.payment_method, numeric, integer),
  public.accept_rescue_offer(uuid),
  public.reject_rescue_offer(uuid, text),
  public.driver_update_trip_stage(uuid, public.trip_status, double precision, double precision, text, numeric),
  public.cancel_rescue_request(uuid, text),
  public.driver_update_location(double precision, double precision, numeric, numeric, boolean, uuid),
  public.admin_review_driver(uuid, public.driver_approval_status, text, boolean),
  public.admin_review_document(uuid, public.document_review_status, text),
  public.admin_resolve_complaint(uuid, public.complaint_status, text),
  public.admin_set_user_active(uuid, boolean),
  public.admin_get_dashboard_stats()
FROM PUBLIC, anon, authenticated;

-- Supabase grants function execution to API roles by default for the postgres
-- owner. New public-schema functions must receive explicit grants instead.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

-- Allow quote estimation even before login (optional onboarding estimate)
GRANT EXECUTE ON FUNCTION
  public.calculate_winch_quote(uuid, double precision, double precision, double precision, double precision, numeric)
TO anon, authenticated, service_role;

-- Transactional RPCs require authenticated users
GRANT EXECUTE ON FUNCTION
  public.find_nearest_drivers(double precision, double precision, uuid, integer, integer, uuid),
  public.dispatch_rescue_request(uuid, integer, integer, integer, integer),
  public.create_rescue_request(uuid, double precision, double precision, text, double precision, double precision, text, uuid, text, text, smallint, text, text, public.vehicle_category, text, text, text[], public.payment_method, numeric, integer),
  public.accept_rescue_offer(uuid),
  public.reject_rescue_offer(uuid, text),
  public.driver_update_trip_stage(uuid, public.trip_status, double precision, double precision, text, numeric),
  public.cancel_rescue_request(uuid, text),
  public.driver_update_location(double precision, double precision, numeric, numeric, boolean, uuid),
  public.admin_review_driver(uuid, public.driver_approval_status, text, boolean),
  public.admin_review_document(uuid, public.document_review_status, text),
  public.admin_resolve_complaint(uuid, public.complaint_status, text),
  public.admin_set_user_active(uuid, boolean),
  public.admin_get_dashboard_stats()
TO authenticated, service_role;
