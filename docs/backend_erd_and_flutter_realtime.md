# Wenshy (ونشي) — Backend Architecture, ERD & Flutter Realtime Guide

## 1. Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : "1:1 via trigger"
    PROFILES ||--o{ CUSTOMER_VEHICLES : "owns"
    PROFILES ||--o| DRIVERS : "1:1 if role=driver"
    DRIVERS ||--o{ DRIVER_WINCHES : "operates"
    WINCH_TYPES ||--o{ DRIVER_WINCHES : "categorizes"
    DRIVERS ||--o{ DRIVER_DOCUMENTS : "uploads KYC"
    DRIVER_WINCHES ||--o{ DRIVER_DOCUMENTS : "optional winch doc"

    PROFILES ||--o{ RESCUE_REQUESTS : "requests (customer_id)"
    DRIVERS ||--o{ RESCUE_REQUESTS : "fulfills (driver_id)"
    WINCH_TYPES ||--o{ RESCUE_REQUESTS : "requires"
    DRIVER_WINCHES ||--o{ RESCUE_REQUESTS : "assigned winch"
    CUSTOMER_VEHICLES ||--o{ RESCUE_REQUESTS : "broken vehicle"

    RESCUE_REQUESTS ||--o{ DISPATCH_OFFERS : "dispatches waves"
    DRIVERS ||--o{ DISPATCH_OFFERS : "receives offer"
    RESCUE_REQUESTS ||--o{ TRIP_STATUS_LOGS : "audits stages"
    RESCUE_REQUESTS ||--o{ TRIP_LOCATION_HISTORY : "stores breadcrumbs"
    RESCUE_REQUESTS ||--o| RATINGS : "1 rating per trip"
    RESCUE_REQUESTS ||--o{ COMPLAINTS : "disputes"
```

## 2. Trip Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> searching: create_rescue_request()
    searching --> driver_assigned: accept_rescue_offer()
    searching --> cancelled: cancel_rescue_request()
    searching --> expired: all waves timed out

    driver_assigned --> en_route_to_pickup: driver_update_trip_stage()
    driver_assigned --> cancelled: cancel_rescue_request()

    en_route_to_pickup --> arrived_at_pickup: driver_update_trip_stage()
    en_route_to_pickup --> cancelled: cancel_rescue_request()

    arrived_at_pickup --> vehicle_loaded: driver_update_trip_stage()
    arrived_at_pickup --> cancelled: cancel_rescue_request()

    vehicle_loaded --> en_route_to_dropoff: driver_update_trip_stage()
    en_route_to_dropoff --> delivered: driver_update_trip_stage()

    delivered --> [*]
    cancelled --> [*]
    expired --> [*]
```

## 3. Hybrid Realtime Architecture for Flutter (`supabase_flutter`)

### Why Hybrid (Private Broadcast + Database Triggers + Throttled PostGIS Sync)?
1. **High-Frequency Live GPS (2–3s) via Ephemeral Broadcast (`trip:<request_id>`):**
   - Sending GPS coordinates every 2 seconds into PostgreSQL tables creates heavy WAL write amplification and slows down Postgres Changes replication.
   - Instead, the Driver app broadcasts `{ lat, lng, heading, speed }` directly over a **Private Broadcast Channel** (`trip:<request_id>`), authorized via `realtime.messages` RLS so **only the assigned driver** can publish and **only the trip customer, driver, and admins** can subscribe.
2. **Reliable Trip State & Dispatch Notifications via `realtime.broadcast_changes`:**
   - Database triggers on `rescue_requests` and `dispatch_offers` call `realtime.broadcast_changes(...)` to push authoritative committed state changes to `trip:<request_id>` and `driver:<driver_id>`.
3. **Throttled PostGIS Location Sync (`driver_update_location` RPC every 15–30s or 100m):**
   - Keeps `drivers.current_location` (`geography(Point, 4326)`) fresh for PostGIS nearest-driver matching (`ST_DWithin`) and records trip route breadcrumbs in `trip_location_history` without overloading Postgres.
4. **Online Fleet Presence (`fleet:online`):**
   - Tracks real-time WebSocket connectivity of approved online drivers.

### Migration Execution Order
1. `supabase/migrations/20261112212957_extensions_and_types.sql`
2. `supabase/migrations/20261112213011_core_tables_and_indexes.sql`
3. `supabase/migrations/20261112213041_triggers_and_guards.sql`
4. `supabase/migrations/20261112213102_rpc_functions_and_views.sql`
5. `supabase/migrations/20261112213122_rls_and_storage_policies.sql`
6. `supabase/migrations/20261112213735_rpc_execution_privileges.sql`
6. `supabase/seed.sql`
