# Wenshy (ونشي) — Supabase Backend

Backend schema, Row Level Security policies, PostgreSQL RPCs, Realtime triggers, and Deno Edge Functions for the Wenshy roadside assistance platform.

- **Project ref:** `ytwpenavwybfmxawiadj`
- **Project URL:** `https://ytwpenavwybfmxawiadj.supabase.co`

---

## Migrations (`supabase/migrations/`)

1. `20261112212957_extensions_and_types.sql` — `extensions` + `private` schemas, PostGIS, domain ENUMs.
2. `20261112213011_core_tables_and_indexes.sql` — 12 core tables (`profiles`, `customer_vehicles`, `winch_types`, `drivers`, `driver_winches`, `driver_documents`, `rescue_requests`, `dispatch_offers`, `trip_status_logs`, `trip_location_history`, `ratings`, `complaints`) + spatial GiST indexes.
3. `20261112213041_triggers_and_guards.sql` — Private RLS helpers, auth signup trigger, PostGIS sync triggers, privilege escalation guards, Realtime broadcast triggers, and `supabase_realtime` publication.
4. `20261112213102_rpc_functions_and_views.sql` — Quoting, PostGIS nearest-driver lookup, atomic offer acceptance, trip lifecycle RPCs, admin workflow RPCs, and `security_invoker` admin views.
5. `20261112213122_rls_and_storage_policies.sql` — RLS policies on all 12 core tables (including full admin CRUD on `winch_types`), 4 Storage buckets + object policies, and `realtime.messages` RLS.
6. `20261112213735_rpc_execution_privileges.sql` — Explicit `REVOKE`/`GRANT` execution privileges.
7. `20261120170000_notifications_automation_and_account_deletion.sql`:
   - `public.device_tokens` table + RLS (own tokens CRUD, admin read/manage).
   - `public.notifications` table + RLS + update guard + `supabase_realtime` publication.
   - Auto-notification triggers for new `dispatch_offers`, `rescue_requests.status` changes, and `drivers.approval_status` changes.
   - `public.expire_stale_requests_and_advance_waves()` RPC (wave 2: 25 km, wave 3: 45 km, 5-minute search TTL) + guarded `pg_cron` job.
   - `public.delete_my_account(p_reason text DEFAULT NULL)` RPC (blocks active trips, anonymizes profile, takes driver offline, deactivates device tokens).

---

## Edge Functions (`supabase/functions/`)

| Function | Purpose | Auth |
| --- | --- | --- |
| `dispatch-scheduler` | Invokes `expire_stale_requests_and_advance_waves()` via service client and returns JSON summary. | `Authorization: Bearer <SCHEDULER_SECRET or SERVICE_ROLE_KEY>` or `x-scheduler-secret` |
| `send-push-notification` | Sends localized FCM HTTP v1 push notifications for a `notifications` insert (DB Webhook or direct POST). Cleanly skips if `FCM_SERVICE_ACCOUNT_JSON` is not set. | `Authorization: Bearer <PUSH_WEBHOOK_SECRET or SERVICE_ROLE_KEY>` or `x-webhook-secret` |

---

## Deployment Commands

### 1. Authenticate & Link Project

```bash
npx supabase login
npx supabase link --project-ref ytwpenavwybfmxawiadj
```

### 2. Push SQL Migrations (and Optional Seed Data)

```bash
npx supabase db push
```

If seeding `winch_types` on a fresh database, run `supabase/seed.sql` via the Supabase SQL Editor or `psql` (uses `ON CONFLICT (code) DO UPDATE`, safe to re-run).

### 3. Deploy Edge Functions

```bash
npx supabase functions deploy dispatch-scheduler --no-verify-jwt
npx supabase functions deploy send-push-notification --no-verify-jwt
```

> `--no-verify-jwt` is recommended because both functions enforce their own constant-time shared secret / `SUPABASE_SERVICE_ROLE_KEY` bearer check (supporting external cron callers and DB webhooks).

### 4. Configure Secrets (Optional / Production)

```bash
# Optional: Firebase Cloud Messaging HTTP v1 service account JSON (single-line JSON string)
npx supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"project_id":"...","client_email":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"}'

# Optional: Dedicated shared secrets for cron & DB webhook callers
npx supabase secrets set SCHEDULER_SECRET="your-random-scheduler-secret"
npx supabase secrets set PUSH_WEBHOOK_SECRET="your-random-webhook-secret"
```

### 5. Wire Automation (Production)

1. **Dispatch wave scheduler**:
   - If `pg_cron` is enabled in Supabase (**Database -> Extensions -> `pg_cron`**), Migration 007 automatically registers the 1-minute job `wenshy-dispatch-wave-automation`.
   - Alternatively, schedule a 1-minute `POST` to `https://ytwpenavwybfmxawiadj.supabase.co/functions/v1/dispatch-scheduler` with header `x-scheduler-secret: <SCHEDULER_SECRET>`.
2. **Push notification webhook**:
   - In Supabase Dashboard (**Database -> Webhooks -> Create a new hook**):
     - Table: `public.notifications`
     - Event: `INSERT`
     - Type: `Supabase Edge Functions` -> `send-push-notification`
     - HTTP Header: `x-webhook-secret: <PUSH_WEBHOOK_SECRET>` (or `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`).
