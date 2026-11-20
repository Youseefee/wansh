# Wenshy (ونشي) — Roadside Assistance & Winch Dispatch Platform

Bilingual (Arabic RTL / English LTR) monorepo for the **Wenshy** tow-truck & roadside rescue platform, powered by Flutter, React/Vite, and Supabase (PostgreSQL + PostGIS + Realtime + Storage + Edge Functions).

---

## Repository Structure

| Path | Description |
| --- | --- |
| `apps/customer_app/` | Flutter Customer app — place search & road routing (Nominatim + OSRM), instant quote calculation, live trip tracking, direct driver call, Forgot Password / Phone OTP / Account Deletion, and Realtime notifications inbox. |
| `apps/driver_app/` | Flutter Driver app — KYC onboarding & document uploads, online/offline dispatch offers, live trip stage workflow, Android foreground / iOS background GPS tracking, Google Maps & Waze navigation, editable profile, and Realtime notifications inbox. |
| `apps/admin_web/` | React + Vite + TypeScript + Tailwind CSS Admin Dashboard — KPI overview, KYC driver & document verification, live Leaflet operations map, complaints queue, user status management, and winch pricing catalog. |
| `packages/wenshy_core/` | Shared Flutter/Dart package — Supabase schema constants, domain models/enums, auth, geocoding & routing (`WenshyGeoService`), notifications (`NotificationService`), and Arabic-first theme/labels. |
| `supabase/` | SQL migrations (`001`–`007`), `seed.sql`, Deno Edge Functions (`dispatch-scheduler`, `send-push-notification`), and backend deployment docs. |
| `docs/` | Architecture documentation (`docs/backend_erd_and_flutter_realtime.md`). |

---

## Running Each App

### 1. Shared Core Package (`packages/wenshy_core`)

```bash
cd packages/wenshy_core
flutter pub get
flutter analyze
flutter test
```

### 2. Customer App (`apps/customer_app`)

```bash
cd apps/customer_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Optional compile-time overrides:
`flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable_key>`

For Android release signing, copy `apps/customer_app/android/key.properties.example` to `apps/customer_app/android/key.properties` and supply your keystore credentials.

### 3. Driver App (`apps/driver_app`)

```bash
cd apps/driver_app
flutter pub get
flutter analyze
flutter test
flutter run
```

For Android release signing, copy `apps/driver_app/android/key.properties.example` to `apps/driver_app/android/key.properties`.

### 4. Admin Web Dashboard (`apps/admin_web`)

```bash
cd apps/admin_web
npm install
# Copy .env.example to .env and set VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY
npm run dev
```

Production build & typecheck:

```bash
cd apps/admin_web
npx tsc --noEmit
npm run build
```

---

## Supabase Backend Deployment (`supabase/`)

Target project ref: `ytwpenavwybfmxawiadj` (`https://ytwpenavwybfmxawiadj.supabase.co`).

```bash
# 1. Authenticate and link
npx supabase login
npx supabase link --project-ref ytwpenavwybfmxawiadj

# 2. Push SQL migrations (001 through 007)
npx supabase db push

# 3. Deploy Edge Functions
npx supabase functions deploy dispatch-scheduler --no-verify-jwt
npx supabase functions deploy send-push-notification --no-verify-jwt

# 4. Set optional production secrets
npx supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<firebase-service-account-json>'
npx supabase secrets set SCHEDULER_SECRET='<random-scheduler-secret>'
npx supabase secrets set PUSH_WEBHOOK_SECRET='<random-webhook-secret>'
```

See `supabase/README.md` for full details on seeding `winch_types` (`supabase/seed.sql`), `pg_cron` vs external cron setup, and Database Webhook configuration for push notifications.
