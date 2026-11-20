-- ============================================================================
-- Wenshy (ونشي) - Migration 007: Notifications, Device Tokens,
-- Dispatch Wave Automation & Self-Service Account Deletion
-- ============================================================================
-- Conventions enforced:
-- 1. All trigger functions live in `private` with `SECURITY DEFINER` and
--    `SET search_path = ''`.
-- 2. RLS enabled on all new tables in `public`, using `(SELECT auth.uid())`
--    and `(SELECT private.is_admin())` for Postgres InitPlan caching.
-- 3. Explicit `REVOKE` / `GRANT` execution privileges on every new RPC.
-- 4. Guarded `pg_cron` scheduling so migrations succeed even when `pg_cron`
--    is not enabled on the target Postgres instance.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Device Tokens Table (`public.device_tokens`)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      text NOT NULL,
  platform   text NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT device_tokens_user_token_unique UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_active_idx
  ON public.device_tokens (user_id, is_active)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS device_tokens_token_idx
  ON public.device_tokens (token);

DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER trg_device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_select_own_or_admin" ON public.device_tokens;
CREATE POLICY "device_tokens_select_own_or_admin"
  ON public.device_tokens FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

DROP POLICY IF EXISTS "device_tokens_insert_own_or_admin" ON public.device_tokens;
CREATE POLICY "device_tokens_insert_own_or_admin"
  ON public.device_tokens FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

DROP POLICY IF EXISTS "device_tokens_update_own_or_admin" ON public.device_tokens;
CREATE POLICY "device_tokens_update_own_or_admin"
  ON public.device_tokens FOR UPDATE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

DROP POLICY IF EXISTS "device_tokens_delete_own_or_admin" ON public.device_tokens;
CREATE POLICY "device_tokens_delete_own_or_admin"
  ON public.device_tokens FOR DELETE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

-- ----------------------------------------------------------------------------
-- 2. Notifications Table (`public.notifications`)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title_ar   text NOT NULL,
  title_en   text NOT NULL,
  body_ar    text NOT NULL,
  body_en    text NOT NULL,
  type       text NOT NULL,
  data       jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read    boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_user_unread_idx
  ON public.notifications (user_id, created_at DESC)
  WHERE is_read = false;

-- Guard non-admin clients so they can only toggle `is_read` on their own rows
CREATE OR REPLACE FUNCTION private.guard_notification_updates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') AND NOT (SELECT private.is_admin()) THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.title_ar IS DISTINCT FROM OLD.title_ar
       OR NEW.title_en IS DISTINCT FROM OLD.title_en
       OR NEW.body_ar IS DISTINCT FROM OLD.body_ar
       OR NEW.body_en IS DISTINCT FROM OLD.body_en
       OR NEW.type IS DISTINCT FROM OLD.type
       OR NEW.data IS DISTINCT FROM OLD.data
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Only notification read state may be updated by users' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_guard_updates ON public.notifications;
CREATE TRIGGER trg_notifications_guard_updates
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION private.guard_notification_updates();

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_select_own_or_admin"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

DROP POLICY IF EXISTS "notifications_update_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_update_own_or_admin"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

DROP POLICY IF EXISTS "notifications_insert_admin_only" ON public.notifications;
CREATE POLICY "notifications_insert_admin_only"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.is_admin()));

DROP POLICY IF EXISTS "notifications_delete_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_delete_own_or_admin"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

-- Add `public.notifications` to `supabase_realtime` publication (idempotent)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1
       FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'notifications'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;

-- ----------------------------------------------------------------------------
-- 3. Auto-Notification Triggers
-- ----------------------------------------------------------------------------

-- A) New pending dispatch offer -> notify candidate driver
CREATE OR REPLACE FUNCTION private.notify_on_dispatch_offer_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_req           public.rescue_requests%ROWTYPE;
  v_distance_km   text;
BEGIN
  IF NEW.status <> 'pending'::public.offer_status THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_req
  FROM public.rescue_requests
  WHERE id = NEW.request_id;

  v_distance_km := ROUND((NEW.distance_meters::numeric / 1000.0), 1)::text;

  INSERT INTO public.notifications (
    user_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    data
  )
  VALUES (
    NEW.driver_id,
    'طلب إنقاذ جديد بالقرب منك',
    'New Rescue Offer Nearby',
    'طلب ' || COALESCE(v_req.request_code, '') || ' على بُعد ' || v_distance_km || ' كم — السعر التقديري ' || COALESCE(v_req.estimated_price::text, '0') || ' ج.م',
    'Request ' || COALESCE(v_req.request_code, '') || ' is ' || v_distance_km || ' km away — Est. ' || COALESCE(v_req.estimated_price::text, '0') || ' ' || COALESCE(v_req.currency, 'EGP'),
    'dispatch_offer_new',
    jsonb_build_object(
      'offer_id', NEW.id,
      'request_id', NEW.request_id,
      'request_code', v_req.request_code,
      'distance_meters', NEW.distance_meters,
      'eta_minutes', NEW.eta_minutes,
      'wave_number', NEW.wave_number,
      'expires_at', NEW.expires_at
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dispatch_offers_notify_insert ON public.dispatch_offers;
CREATE TRIGGER trg_dispatch_offers_notify_insert
  AFTER INSERT ON public.dispatch_offers
  FOR EACH ROW
  WHEN (NEW.status = 'pending'::public.offer_status)
  EXECUTE FUNCTION private.notify_on_dispatch_offer_insert();

-- B) Rescue request status transition -> notify customer (and driver on cancellation)
CREATE OR REPLACE FUNCTION private.notify_on_rescue_request_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_title_ar    text;
  v_title_en    text;
  v_body_ar     text;
  v_body_en     text;
  v_type        text;
  v_payload     jsonb;
  v_driver_id   uuid := COALESCE(NEW.driver_id, OLD.driver_id);
  v_reason_text text := NULLIF(TRIM(COALESCE(NEW.cancellation_reason, '')), '');
  v_price_text  text := COALESCE(NEW.final_price, NEW.estimated_price)::text;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  v_payload := jsonb_build_object(
    'request_id', NEW.id,
    'request_code', NEW.request_code,
    'old_status', OLD.status,
    'new_status', NEW.status,
    'driver_id', v_driver_id
  );

  CASE NEW.status
    WHEN 'driver_assigned'::public.trip_status THEN
      v_type     := 'trip_driver_assigned';
      v_title_ar := 'تم تعيين سائق الونش';
      v_title_en := 'Driver Assigned';
      v_body_ar  := 'تم قبول طلبك (' || NEW.request_code || ') وسيتجه سائق الونش إليك قريباً.';
      v_body_en  := 'Your rescue request (' || NEW.request_code || ') was accepted. Your driver is preparing to head out.';

    WHEN 'en_route_to_pickup'::public.trip_status THEN
      v_type     := 'trip_en_route_to_pickup';
      v_title_ar := 'السائق في الطريق إليك';
      v_title_en := 'Driver En Route';
      v_body_ar  := 'سائق الونش تحرك الآن نحو موقع العطل للطلب ' || NEW.request_code || '.';
      v_body_en  := 'Your tow truck driver is on the way to your pickup location (' || NEW.request_code || ').';

    WHEN 'arrived_at_pickup'::public.trip_status THEN
      v_type     := 'trip_arrived_at_pickup';
      v_title_ar := 'وصل السائق لموقع العطل';
      v_title_en := 'Driver Arrived';
      v_body_ar  := 'وصل سائق الونش إلى موقع سيارتك للطلب ' || NEW.request_code || '.';
      v_body_en  := 'Your tow truck driver has arrived at the pickup location (' || NEW.request_code || ').';

    WHEN 'vehicle_loaded'::public.trip_status THEN
      v_type     := 'trip_vehicle_loaded';
      v_title_ar := 'تم تحميل السيارة على الونش';
      v_title_en := 'Vehicle Loaded';
      v_body_ar  := 'تم تحميل سيارتك بأمان على الونش للطلب ' || NEW.request_code || '.';
      v_body_en  := 'Your vehicle has been safely loaded onto the tow truck (' || NEW.request_code || ').';

    WHEN 'en_route_to_dropoff'::public.trip_status THEN
      v_type     := 'trip_en_route_to_dropoff';
      v_title_ar := 'في الطريق إلى وجهة التسليم';
      v_title_en := 'Heading to Drop-off';
      v_body_ar  := 'الونش الآن في طريقه لتوصيل سيارتك إلى الوجهة المحددة (' || NEW.request_code || ').';
      v_body_en  := 'Your vehicle is on the way to the drop-off destination (' || NEW.request_code || ').';

    WHEN 'delivered'::public.trip_status THEN
      v_type     := 'trip_delivered';
      v_title_ar := 'تم توصيل السيارة بنجاح';
      v_title_en := 'Vehicle Delivered';
      v_body_ar  := 'اكتملت رحلة الإنقاذ (' || NEW.request_code || '). الإجمالي: ' || v_price_text || ' ج.م.';
      v_body_en  := 'Rescue trip (' || NEW.request_code || ') completed. Total: ' || v_price_text || ' ' || NEW.currency || '.';

    WHEN 'cancelled'::public.trip_status THEN
      v_type     := 'trip_cancelled';
      v_title_ar := 'تم إلغاء الطلب';
      v_title_en := 'Request Cancelled';
      v_body_ar  := 'تم إلغاء طلب الإنقاذ ' || NEW.request_code || CASE WHEN v_reason_text IS NOT NULL THEN ' — السبب: ' || v_reason_text ELSE '.' END;
      v_body_en  := 'Rescue request ' || NEW.request_code || ' was cancelled' || CASE WHEN v_reason_text IS NOT NULL THEN ': ' || v_reason_text ELSE '.' END;

    WHEN 'expired'::public.trip_status THEN
      v_type     := 'trip_expired';
      v_title_ar := 'انتهت مهلة البحث عن ونش';
      v_title_en := 'Search Timed Out';
      v_body_ar  := 'لم يتم العثور على سائق متاح للطلب ' || NEW.request_code || '. يمكنك إعادة المحاولة الآن.';
      v_body_en  := 'No available tow truck accepted request ' || NEW.request_code || '. Please try requesting again.';

    ELSE
      RETURN NEW;
  END CASE;

  -- Notify customer
  INSERT INTO public.notifications (
    user_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    data
  )
  VALUES (
    NEW.customer_id,
    v_title_ar,
    v_title_en,
    v_body_ar,
    v_body_en,
    v_type,
    v_payload
  );

  -- Also notify assigned driver if cancelled by customer or admin
  IF NEW.status = 'cancelled'::public.trip_status
     AND v_driver_id IS NOT NULL
     AND NEW.cancelled_by IS DISTINCT FROM v_driver_id THEN
    INSERT INTO public.notifications (
      user_id,
      title_ar,
      title_en,
      body_ar,
      body_en,
      type,
      data
    )
    VALUES (
      v_driver_id,
      'تم إلغاء الرحلة',
      'Trip Cancelled',
      'تم إلغاء طلب الإنقاذ ' || NEW.request_code || CASE WHEN NEW.cancelled_by = NEW.customer_id THEN ' من قبل العميل' ELSE ' من قبل الإدارة' END || CASE WHEN v_reason_text IS NOT NULL THEN ' — السبب: ' || v_reason_text ELSE '.' END,
      'Rescue request ' || NEW.request_code || CASE WHEN NEW.cancelled_by = NEW.customer_id THEN ' was cancelled by the customer' ELSE ' was cancelled by admin' END || CASE WHEN v_reason_text IS NOT NULL THEN ': ' || v_reason_text ELSE '.' END,
      'trip_cancelled',
      v_payload
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rescue_requests_notify_status ON public.rescue_requests;
CREATE TRIGGER trg_rescue_requests_notify_status
  AFTER UPDATE OF status ON public.rescue_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION private.notify_on_rescue_request_status_change();

-- C) Driver approval workflow change -> notify driver
CREATE OR REPLACE FUNCTION private.notify_on_driver_approval_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_title_ar    text;
  v_title_en    text;
  v_body_ar     text;
  v_body_en     text;
  v_type        text;
  v_reason_text text := NULLIF(TRIM(COALESCE(NEW.rejection_reason, '')), '');
BEGIN
  IF OLD.approval_status IS NOT DISTINCT FROM NEW.approval_status THEN
    RETURN NEW;
  END IF;

  CASE NEW.approval_status
    WHEN 'approved'::public.driver_approval_status THEN
      v_type     := 'driver_approved';
      v_title_ar := 'تم اعتماد حسابك كسائق';
      v_title_en := 'Driver Account Approved';
      v_body_ar  := 'تهانينا! تمت مراجعة واعتماد حسابك ويمكنك الآن الاتصال لاستقبال طلبات الإنقاذ.';
      v_body_en  := 'Congratulations! Your driver account is approved and you can now go online to accept rescue requests.';

    WHEN 'rejected'::public.driver_approval_status THEN
      v_type     := 'driver_rejected';
      v_title_ar := 'تم رفض طلب التسجيل';
      v_title_en := 'Driver Application Rejected';
      v_body_ar  := 'تم رفض طلب اعتماد حساب السائق' || CASE WHEN v_reason_text IS NOT NULL THEN ' — السبب: ' || v_reason_text ELSE '. يرجى مراجعة المستندات وإعادة الإرسال.' END;
      v_body_en  := 'Your driver application was rejected' || CASE WHEN v_reason_text IS NOT NULL THEN ': ' || v_reason_text ELSE '. Please review your documents and resubmit.' END;

    WHEN 'suspended'::public.driver_approval_status THEN
      v_type     := 'driver_suspended';
      v_title_ar := 'تم إيقاف حساب السائق';
      v_title_en := 'Driver Account Suspended';
      v_body_ar  := 'تم تعليق حساب السائق مؤقتاً' || CASE WHEN v_reason_text IS NOT NULL THEN ' — السبب: ' || v_reason_text ELSE '. يرجى التواصل مع الدعم الفني.' END;
      v_body_en  := 'Your driver account has been suspended' || CASE WHEN v_reason_text IS NOT NULL THEN ': ' || v_reason_text ELSE '. Please contact support.' END;

    ELSE
      RETURN NEW;
  END CASE;

  INSERT INTO public.notifications (
    user_id,
    title_ar,
    title_en,
    body_ar,
    body_en,
    type,
    data
  )
  VALUES (
    NEW.id,
    v_title_ar,
    v_title_en,
    v_body_ar,
    v_body_en,
    v_type,
    jsonb_build_object(
      'driver_id', NEW.id,
      'old_status', OLD.approval_status,
      'new_status', NEW.approval_status,
      'rejection_reason', v_reason_text
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_drivers_notify_approval ON public.drivers;
CREATE TRIGGER trg_drivers_notify_approval
  AFTER UPDATE OF approval_status ON public.drivers
  FOR EACH ROW
  WHEN (OLD.approval_status IS DISTINCT FROM NEW.approval_status)
  EXECUTE FUNCTION private.notify_on_driver_approval_change();

-- ----------------------------------------------------------------------------
-- 4. Automated Dispatch Wave Advancement & Stale Request Expiration RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_stale_requests_and_advance_waves()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_expired_offers_count    integer := 0;
  v_advanced_requests_count integer := 0;
  v_dispatched_offers_count integer := 0;
  v_expired_requests_count  integer := 0;
  v_req                     public.rescue_requests%ROWTYPE;
  v_next_wave               integer;
  v_next_radius             integer;
  v_dispatch_result         jsonb;
  v_reason                  text;
BEGIN
  -- Restrict execution to service_role / postgres (cron) or authenticated admins.
  -- Note: Inside SECURITY DEFINER, `current_user` is the function owner (`postgres`),
  -- so we inspect the caller's JWT role, `auth.uid()`, and session GUC `role`.
  IF (
    COALESCE((SELECT auth.jwt()) ->> 'role', '') IN ('anon', 'authenticated')
    OR COALESCE(current_setting('role', true), '') IN ('anon', 'authenticated')
    OR (SELECT auth.uid()) IS NOT NULL
  ) AND NOT (SELECT private.is_admin()) THEN
    RAISE EXCEPTION 'Only service_role or administrators can execute dispatch automation'
      USING ERRCODE = '42501';
  END IF;

  -- Step 1: Expire all timed-out pending dispatch offers
  UPDATE public.dispatch_offers
  SET status = 'expired'::public.offer_status,
      responded_at = now()
  WHERE status = 'pending'::public.offer_status
    AND expires_at <= now();

  GET DIAGNOSTICS v_expired_offers_count = ROW_COUNT;

  -- Step 2: Advance waves or expire stale searching requests
  FOR v_req IN
    SELECT r.*
    FROM public.rescue_requests r
    WHERE r.status = 'searching'::public.trip_status
      AND (
        r.created_at <= (now() - interval '5 minutes')
        OR NOT EXISTS (
          SELECT 1
          FROM public.dispatch_offers o
          WHERE o.request_id = r.id
            AND o.status = 'pending'::public.offer_status
            AND o.expires_at > now()
        )
      )
    ORDER BY r.created_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    IF v_req.current_wave < 3 AND v_req.created_at > (now() - interval '5 minutes') THEN
      v_next_wave := v_req.current_wave + 1;
      v_next_radius := CASE
        WHEN v_next_wave = 2 THEN 25000
        ELSE 45000
      END;

      v_dispatch_result := public.dispatch_rescue_request(
        v_req.id,
        v_next_radius,
        v_next_wave,
        5,
        45
      );

      v_advanced_requests_count := v_advanced_requests_count + 1;
      v_dispatched_offers_count := v_dispatched_offers_count + COALESCE((v_dispatch_result ->> 'dispatched_count')::integer, 0);
    ELSE
      -- Cancel any lingering pending offers before marking request expired
      UPDATE public.dispatch_offers
      SET status = 'expired'::public.offer_status,
          responded_at = now()
      WHERE request_id = v_req.id
        AND status = 'pending'::public.offer_status;

      UPDATE public.rescue_requests
      SET status = 'expired'::public.trip_status
      WHERE id = v_req.id
        AND status = 'searching'::public.trip_status;

      v_reason := CASE
        WHEN v_req.created_at <= (now() - interval '5 minutes')
          THEN 'Search window (5 minutes) elapsed with no driver acceptance'
        ELSE 'All dispatch waves exhausted with no driver acceptance'
      END;

      INSERT INTO public.trip_status_logs (
        request_id,
        from_status,
        to_status,
        changed_by,
        notes
      )
      VALUES (
        v_req.id,
        'searching'::public.trip_status,
        'expired'::public.trip_status,
        NULL,
        v_reason
      );

      v_expired_requests_count := v_expired_requests_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'expired_offers', v_expired_offers_count,
    'advanced_requests', v_advanced_requests_count,
    'dispatched_offers', v_dispatched_offers_count,
    'expired_requests', v_expired_requests_count,
    'processed_at', now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Guarded `pg_cron` Schedule (Safe when `pg_cron` is not installed)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    EXECUTE 'SELECT jobid FROM cron.job WHERE jobname = $1 LIMIT 1'
      INTO v_job_id
      USING 'wenshy-dispatch-wave-automation';

    IF v_job_id IS NOT NULL THEN
      EXECUTE 'SELECT cron.unschedule($1)' USING v_job_id;
    END IF;

    EXECUTE 'SELECT cron.schedule($1, $2, $3)'
      USING
        'wenshy-dispatch-wave-automation',
        '* * * * *',
        'SELECT public.expire_stale_requests_and_advance_waves();';
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR undefined_table OR undefined_function THEN
    RAISE NOTICE 'Skipping pg_cron job registration; use the dispatch-scheduler Edge Function or enable pg_cron.';
END
$$;

-- ----------------------------------------------------------------------------
-- 6. Self-Service Account Deletion RPC (`public.delete_my_account`)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_my_account(
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid              uuid := (SELECT auth.uid());
  v_profile          public.profiles%ROWTYPE;
  v_has_active_trip  boolean := false;
  v_clean_reason     text := NULLIF(TRIM(COALESCE(p_reason, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'P0002';
  END IF;

  -- Block account deletion while caller participates in any active trip
  SELECT EXISTS (
    SELECT 1
    FROM public.rescue_requests r
    WHERE (r.customer_id = v_uid OR r.driver_id = v_uid)
      AND r.status IN (
        'searching'::public.trip_status,
        'driver_assigned'::public.trip_status,
        'en_route_to_pickup'::public.trip_status,
        'arrived_at_pickup'::public.trip_status,
        'vehicle_loaded'::public.trip_status,
        'en_route_to_dropoff'::public.trip_status
      )
  ) INTO v_has_active_trip;

  IF v_has_active_trip THEN
    RAISE EXCEPTION 'Cannot delete account while you have an active rescue trip in progress. Please complete or cancel your active trip first.'
      USING ERRCODE = 'P0001';
  END IF;

  -- Soft-delete and anonymize profile while preserving immutable trip/rating audit history
  UPDATE public.profiles
  SET
    is_active = false,
    full_name = 'Deleted User',
    phone = NULL,
    avatar_url = NULL,
    fcm_token = NULL
  WHERE id = v_uid;

  -- Take driver offline & unavailable if caller has a driver record
  UPDATE public.drivers
  SET
    is_online = false,
    is_available = false
  WHERE id = v_uid;

  -- Cancel any pending dispatch offers targeted at this driver
  UPDATE public.dispatch_offers
  SET
    status = 'cancelled'::public.offer_status,
    rejection_reason = COALESCE(v_clean_reason, 'Account deleted'),
    responded_at = now()
  WHERE driver_id = v_uid
    AND status = 'pending'::public.offer_status;

  -- Deactivate all registered push device tokens
  UPDATE public.device_tokens
  SET is_active = false
  WHERE user_id = v_uid
    AND is_active = true;

  RETURN jsonb_build_object(
    'deleted', true,
    'user_id', v_uid,
    'reason', v_clean_reason,
    'deleted_at', now()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. Explicit Function Execution Privileges
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION
  private.guard_notification_updates(),
  private.notify_on_dispatch_offer_insert(),
  private.notify_on_rescue_request_status_change(),
  private.notify_on_driver_approval_change()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
  public.expire_stale_requests_and_advance_waves(),
  public.delete_my_account(text)
FROM PUBLIC, anon, authenticated;

-- `expire_stale_requests_and_advance_waves` enforces service_role or admin inside body
GRANT EXECUTE ON FUNCTION
  public.expire_stale_requests_and_advance_waves()
TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION
  public.delete_my_account(text)
TO authenticated, service_role;
