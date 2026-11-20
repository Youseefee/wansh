# Wenshy Admin Web Dashboard (`apps/admin_web`)

Operations and administration portal for **Wenshy (ونشي)** — built with **React + Vite + TypeScript + Tailwind CSS + Supabase + Leaflet**.

## Features

- **Bilingual Arabic-first (RTL default) & English (LTR) Toggle** with Cairo / Inter typography and Wenshy brand styling (`#F59E0B` amber primary, `#0F172A` deep slate dark accents, `#10B981` emerald, `#EF4444` red).
- **Admin Authentication & Role Guard**: Signs in via Supabase Auth and verifies `profiles.role === 'admin'` and `profiles.is_active === true`. Non-admin or suspended accounts are blocked with a localized notice and sign-out option.
- **Overview Dashboard**: Live KPI metrics via `admin_get_dashboard_stats()` with Realtime auto-refresh on `rescue_requests`, `drivers`, `driver_documents`, and `complaints`, plus priority quick links.
- **Driver Applications & KYC Verification**: Queries `v_admin_driver_applications` with status tabs and search, previews public `winch-photos`, generates signed URLs for private `driver-documents`, and executes `admin_review_document` and `admin_review_driver`.
- **Live Active Trips Operations Monitor**: Queries `v_admin_active_trips` + Realtime updates, plots pickup pins, dropoff pins, and live driver truck locations on an interactive Leaflet map with click-to-focus, and supports administrative trip cancellation via `cancel_rescue_request`.
- **Complaints & Disputes Queue**: Queries `v_admin_complaints_queue`, previews private `complaint-evidence` files via signed URLs, and updates complaint status/admin notes via `admin_resolve_complaint`.
- **Users Management**: Lists `profiles` by role (`customer`, `driver`, `admin`) with search and Activate/Suspend toggle via `admin_set_user_active`.
- **Winch Types & Pricing Catalog**: Manages `winch_types` (Arabic/English labels, base fare, price per km, minimum fare, road factor, surge multiplier, max capacity, active state) with a live 10 km sample quote calculator.

## Environment Configuration

Copy `.env.example` to `.env` (already pre-configured with the project Supabase URL and publishable key, with built-in fallbacks in `src/lib/supabase.ts`):

```env
VITE_SUPABASE_URL=https://ytwpenavwybfmxawiadj.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_WC2QHX2G2TdN0jvUAkrM_Q_QT7kYxL5
```

## Run & Build

```bash
cd apps/admin_web
npm install

# Start local dev server (http://localhost:5173)
npm run dev

# TypeScript typecheck
npx tsc --noEmit

# Production build
npm run build

# Preview production bundle
npm run preview
```
