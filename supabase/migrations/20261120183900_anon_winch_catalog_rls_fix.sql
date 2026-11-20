-- ============================================================================
-- Wenshy (ونشي) - Migration 009: Allow `anon` evaluation of `winch_types` RLS
-- ============================================================================
-- `winch_types_select_active_public` targets `TO anon, authenticated` and
-- references `(SELECT private.is_admin())`. Granting `USAGE` on `private` and
-- `EXECUTE` on read-only `private.is_admin()` to `anon` lets unauthenticated
-- catalog queries evaluate cleanly (always returning false when auth.uid() IS NULL).
-- ============================================================================

GRANT USAGE ON SCHEMA private TO anon;
GRANT EXECUTE ON FUNCTION private.is_admin() TO anon;
