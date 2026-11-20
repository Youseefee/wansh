-- ============================================================================
-- Wenshy (ونشي) - Migration 008: Explicit Table, View & Sequence Privileges
-- ============================================================================
-- Postgres 17+ Supabase instances require explicit table/view/sequence grants
-- for API roles (`anon`, `authenticated`, `service_role`) in addition to RLS.
-- ============================================================================

-- Service role full access on all public tables, views, and sequences
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Anon: read-only access to public winch catalog (enforced by RLS is_active = true)
GRANT SELECT ON public.winch_types TO anon;

-- Authenticated: table & view privileges strictly gated by RLS policies & guard triggers
GRANT SELECT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.customer_vehicles,
  public.winch_types,
  public.drivers,
  public.driver_winches,
  public.driver_documents,
  public.rescue_requests,
  public.dispatch_offers,
  public.ratings,
  public.complaints,
  public.device_tokens,
  public.notifications
TO authenticated;

GRANT SELECT, INSERT ON
  public.trip_status_logs,
  public.trip_location_history
TO authenticated;

-- Admin dashboard views (all use security_invoker = true so RLS is enforced)
GRANT SELECT ON
  public.v_admin_driver_applications,
  public.v_admin_active_trips,
  public.v_admin_complaints_queue
TO authenticated;

-- Sequences for human-readable request/complaint codes & identity columns
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
