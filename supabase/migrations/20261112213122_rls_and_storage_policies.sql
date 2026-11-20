-- ============================================================================
-- Wenshy (ونشي) - Migration 005: Row Level Security, Storage & Realtime RLS
-- ============================================================================
-- Security standards enforced across every table:
-- 1. RLS enabled on ALL tables in `public`.
-- 2. Explicit `TO authenticated` / `TO anon` targets (no deprecated `auth.role()`).
-- 3. `(SELECT auth.uid())` and `(SELECT private.*)` wrapped in scalar subselects
--    for Postgres InitPlan caching.
-- 4. Every `UPDATE` policy specifies both `USING` and `WITH CHECK`.
-- 5. Storage upsert operations are backed by `SELECT` + `INSERT` + `UPDATE`.
-- 6. Private Realtime channels authorized via `realtime.messages` RLS.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable RLS on all public tables
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.winch_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_winches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rescue_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_status_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_location_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. `profiles` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "profiles_select_own_counterparty_or_admin"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR (SELECT private.is_active_trip_counterparty(id))
    OR (SELECT private.is_admin())
  );

CREATE POLICY "profiles_update_own_or_admin"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "profiles_delete_admin_only"
  ON public.profiles FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 3. `customer_vehicles` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "customer_vehicles_select_own_or_admin"
  ON public.customer_vehicles FOR SELECT
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "customer_vehicles_insert_own_or_admin"
  ON public.customer_vehicles FOR INSERT
  TO authenticated
  WITH CHECK (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "customer_vehicles_update_own_or_admin"
  ON public.customer_vehicles FOR UPDATE
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "customer_vehicles_delete_own_or_admin"
  ON public.customer_vehicles FOR DELETE
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

-- ----------------------------------------------------------------------------
-- 4. `winch_types` Policies (Public active catalog, Admin full management)
-- ----------------------------------------------------------------------------
CREATE POLICY "winch_types_select_active_public"
  ON public.winch_types FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    OR (SELECT private.is_admin())
  );

CREATE POLICY "winch_types_insert_admin_only"
  ON public.winch_types FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.is_admin()));

CREATE POLICY "winch_types_update_admin_only"
  ON public.winch_types FOR UPDATE
  TO authenticated
  USING ((SELECT private.is_admin()))
  WITH CHECK ((SELECT private.is_admin()));

CREATE POLICY "winch_types_delete_admin_only"
  ON public.winch_types FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 5. `drivers` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "drivers_select_own_assigned_customer_or_admin"
  ON public.drivers FOR SELECT
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR (SELECT private.is_active_trip_counterparty(id))
    OR (SELECT private.is_admin())
  );

CREATE POLICY "drivers_insert_own_or_admin"
  ON public.drivers FOR INSERT
  TO authenticated
  WITH CHECK (
    id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "drivers_update_own_or_admin"
  ON public.drivers FOR UPDATE
  TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "drivers_delete_admin_only"
  ON public.drivers FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 6. `driver_winches` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "driver_winches_select_own_trip_customer_or_admin"
  ON public.driver_winches FOR SELECT
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.rescue_requests r
      WHERE r.winch_id = driver_winches.id
        AND r.customer_id = (SELECT auth.uid())
    )
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_winches_insert_own_or_admin"
  ON public.driver_winches FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_winches_update_own_or_admin"
  ON public.driver_winches FOR UPDATE
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_winches_delete_own_or_admin"
  ON public.driver_winches FOR DELETE
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

-- ----------------------------------------------------------------------------
-- 7. `driver_documents` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "driver_documents_select_own_or_admin"
  ON public.driver_documents FOR SELECT
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_documents_insert_own_or_admin"
  ON public.driver_documents FOR INSERT
  TO authenticated
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_documents_update_own_or_admin"
  ON public.driver_documents FOR UPDATE
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "driver_documents_delete_own_or_admin"
  ON public.driver_documents FOR DELETE
  TO authenticated
  USING (
    (driver_id = (SELECT auth.uid()) AND review_status <> 'approved'::public.document_review_status)
    OR (SELECT private.is_admin())
  );

-- ----------------------------------------------------------------------------
-- 8. `rescue_requests` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "rescue_requests_select_participant_offered_or_admin"
  ON public.rescue_requests FOR SELECT
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR driver_id = (SELECT auth.uid())
    OR (
      status = 'searching'::public.trip_status
      AND (SELECT private.driver_has_pending_offer(id))
    )
    OR (SELECT private.is_admin())
  );

CREATE POLICY "rescue_requests_insert_customer_or_admin"
  ON public.rescue_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "rescue_requests_update_customer_notes_or_admin"
  ON public.rescue_requests FOR UPDATE
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "rescue_requests_delete_admin_only"
  ON public.rescue_requests FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 9. `dispatch_offers` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "dispatch_offers_select_driver_customer_or_admin"
  ON public.dispatch_offers FOR SELECT
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR (SELECT private.is_request_customer(request_id))
    OR (SELECT private.is_admin())
  );

CREATE POLICY "dispatch_offers_insert_admin_only"
  ON public.dispatch_offers FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.is_admin()));

CREATE POLICY "dispatch_offers_update_admin_only"
  ON public.dispatch_offers FOR UPDATE
  TO authenticated
  USING ((SELECT private.is_admin()))
  WITH CHECK ((SELECT private.is_admin()));

CREATE POLICY "dispatch_offers_delete_admin_only"
  ON public.dispatch_offers FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 10. `trip_status_logs` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "trip_status_logs_select_participant_or_admin"
  ON public.trip_status_logs FOR SELECT
  TO authenticated
  USING (
    (SELECT private.is_trip_participant(request_id))
    OR (SELECT private.is_admin())
  );

CREATE POLICY "trip_status_logs_insert_admin_only"
  ON public.trip_status_logs FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 11. `trip_location_history` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "trip_location_history_select_participant_or_admin"
  ON public.trip_location_history FOR SELECT
  TO authenticated
  USING (
    (SELECT private.is_trip_participant(request_id))
    OR (SELECT private.is_admin())
  );

CREATE POLICY "trip_location_history_insert_admin_only"
  ON public.trip_location_history FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 12. `ratings` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "ratings_select_customer_driver_or_admin"
  ON public.ratings FOR SELECT
  TO authenticated
  USING (
    customer_id = (SELECT auth.uid())
    OR driver_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "ratings_insert_customer_or_admin"
  ON public.ratings FOR INSERT
  TO authenticated
  WITH CHECK (
    customer_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "ratings_update_admin_only"
  ON public.ratings FOR UPDATE
  TO authenticated
  USING ((SELECT private.is_admin()))
  WITH CHECK ((SELECT private.is_admin()));

CREATE POLICY "ratings_delete_admin_only"
  ON public.ratings FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ----------------------------------------------------------------------------
-- 13. `complaints` Policies
-- ----------------------------------------------------------------------------
CREATE POLICY "complaints_select_reporter_or_admin"
  ON public.complaints FOR SELECT
  TO authenticated
  USING (
    reporter_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "complaints_insert_reporter_or_admin"
  ON public.complaints FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = (SELECT auth.uid())
    OR (SELECT private.is_admin())
  );

CREATE POLICY "complaints_update_open_reporter_or_admin"
  ON public.complaints FOR UPDATE
  TO authenticated
  USING (
    (reporter_id = (SELECT auth.uid()) AND status = 'open'::public.complaint_status)
    OR (SELECT private.is_admin())
  )
  WITH CHECK (
    (reporter_id = (SELECT auth.uid()) AND status = 'open'::public.complaint_status)
    OR (SELECT private.is_admin())
  );

CREATE POLICY "complaints_delete_admin_only"
  ON public.complaints FOR DELETE
  TO authenticated
  USING ((SELECT private.is_admin()));

-- ============================================================================
-- 14. Supabase Storage Buckets & Object RLS Policies
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('driver-documents', 'driver-documents', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('winch-photos', 'winch-photos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('breakdown-photos', 'breakdown-photos', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('complaint-evidence', 'complaint-evidence', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- A) `driver-documents` (Private: `<driver_id>/<doc_type>/<file>`)
-- Note: `SELECT` + `INSERT` + `UPDATE` required for upsert uploads.
CREATE POLICY "driver_docs_select_own_or_admin"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "driver_docs_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "driver_docs_update_own_or_admin"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  )
  WITH CHECK (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "driver_docs_delete_own_or_admin"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

-- B) `winch-photos` (Public read for non-sensitive vehicle photos; owner-only write `<driver_id>/<file>`)
CREATE POLICY "winch_photos_public_select"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'winch-photos');

CREATE POLICY "winch_photos_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'winch-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "winch_photos_update_own_or_admin"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'winch-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  )
  WITH CHECK (
    bucket_id = 'winch-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "winch_photos_delete_own_or_admin"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'winch-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

-- C) `breakdown-photos` (Private: `<customer_id>/<request_id>/<file>`)
CREATE POLICY "breakdown_photos_select_participants_or_admin"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'breakdown-photos'
    AND (SELECT private.can_view_breakdown_photo(name))
  );

CREATE POLICY "breakdown_photos_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'breakdown-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "breakdown_photos_update_own_or_admin"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'breakdown-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  )
  WITH CHECK (
    bucket_id = 'breakdown-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "breakdown_photos_delete_own_or_admin"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'breakdown-photos'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

-- D) `complaint-evidence` (Private: `<reporter_id>/<file>`)
CREATE POLICY "complaint_evidence_select_own_or_admin"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'complaint-evidence'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "complaint_evidence_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'complaint-evidence'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "complaint_evidence_update_own_or_admin"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'complaint-evidence'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  )
  WITH CHECK (
    bucket_id = 'complaint-evidence'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

CREATE POLICY "complaint_evidence_delete_own_or_admin"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'complaint-evidence'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      OR (SELECT private.is_admin())
    )
  );

-- ============================================================================
-- 15. Supabase Realtime Authorization Policies (`realtime.messages`)
-- ============================================================================
-- Note: RLS is already enabled on `realtime.messages` by Supabase; do NOT run
-- `ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY` in migrations.
-- ============================================================================

CREATE POLICY "realtime_messages_select_authorized_topics"
  ON realtime.messages FOR SELECT
  TO authenticated
  USING ((SELECT private.can_access_realtime_topic(realtime.topic(), 'SELECT')));

CREATE POLICY "realtime_messages_insert_authorized_topics"
  ON realtime.messages FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT private.can_access_realtime_topic(realtime.topic(), 'INSERT')));
