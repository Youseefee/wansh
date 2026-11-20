-- Remove API-role defaults from public SECURITY DEFINER functions. The local
-- migrations explicitly grant quote estimates to anon and transactional RPCs
-- to authenticated users.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

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

GRANT EXECUTE ON FUNCTION
  public.calculate_winch_quote(uuid, double precision, double precision, double precision, double precision, numeric)
TO anon, authenticated, service_role;

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

-- This Supabase event-trigger function is internal and must not be callable
-- through the public Data API.
REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
