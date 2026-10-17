# Phase 10 — Dispatch, Delivery & Returnables

Status: **complete and CI validated**.

## Workflow

**Warehouse handoff → Delivery creation → Vehicle load → Fleet trip start → In transit → Arrive customer → POD delivery → Returnable pickup → Exception resolution → Close**

Phase 10 consumes the validated Phase 8 Warehouse handoff and Phase 9 Fleet trip. Inventory movement remains ledger-backed and immutable.

## Design-first checkpoint

Committed before implementation:

- `docs/designs/phase10_dispatch_admin.svg`
- `docs/designs/phase10_driver_delivery.svg`

The Admin design covers queue/status KPIs, vehicle-load confirmation, delivery detail, POD/returnables direction and exceptions. The Driver design covers assigned load, delivery confirmation, POD capture and returnable pickup.

## Backend

Migrations:

- `supabase/migrations/0020_dispatch_delivery_returnables.sql`
- `supabase/migrations/0021_dispatch_scope_hardening.sql`
- `supabase/migrations/0022_delivery_pod_storage.sql`
- `supabase/migrations/0023_dispatch_returnable_hardening.sql`

Operational tables:

- `dispatch_deliveries`
- `dispatch_delivery_lines`
- `dispatch_returnable_pickups`
- `dispatch_returnable_lines`
- `dispatch_delivery_exceptions`

Inventory items include `is_returnable` for explicit returnable configuration; cylinder items are also accepted as returnables.

## Inventory truth

Vehicle load posts an Inventory transfer from the Warehouse staging location to the vehicle's Fleet stock location.

Completed delivery posts an Inventory issue from the vehicle location to the external customer.

Returnable pickup posts an Inventory receive into the vehicle location and records condition separately so a later Warehouse return-intake workflow can route good/damaged/rejected units appropriately.

Completed or cancelled returnable pickups are immutable: `dispatch_record_returnable` locks the pickup and rejects any new line or Inventory receipt once the pickup is no longer open.

The Phase 10 seed owns dedicated Sales, Warehouse and Fleet fixtures so later-phase demos do not mutate or invalidate earlier phase smoke-test baselines.

## Security

- RLS is enabled on every Dispatch table.
- Admin/supervisor planning is required for delivery creation and vehicle-load confirmation.
- Driver execution is restricted to the signed-in driver's own assigned delivery through the Fleet identity chain.
- Unassigned employees cannot read or execute driver deliveries.
- Aggregate Dispatch dashboard access is restricted to authorized planning/admin roles.
- Inventory helper functions are internal and not granted to application roles directly.
- Delivery completion requires receiver identity plus proof of delivery.
- Returnable pickups cannot accept stock after they are completed or cancelled.
- Exceptions are driver-reportable and manager-resolvable.
- POD media uses the private `delivery-pod` Storage bucket.
- POD object paths are scoped to organization/factory/delivery/user and protected by Storage RLS.
- POD media is image-only and limited to 10 MB per object.
- Authorized Dispatch viewers can read delivery proof; upload/update/delete ownership is constrained to the authenticated uploader folder.

## RPCs

- `dispatch_create_delivery`
- `dispatch_confirm_vehicle_load`
- `dispatch_begin_delivery`
- `dispatch_mark_arrived`
- `dispatch_complete_delivery`
- `dispatch_record_returnable`
- `dispatch_complete_returnables`
- `dispatch_report_exception`
- `dispatch_resolve_exception`
- `dispatch_dashboard_summary`

Internal ledger helpers:

- `dispatch_post_transfer`
- `dispatch_post_issue`
- `dispatch_post_receive`

## Admin Web

`apps/admin_web/lib/dispatch_management.dart`

Connected through the existing `delivery` module when the required Sales, Warehouse and Fleet dependencies are enabled.

Features include:

- factory-scoped Dispatch KPIs;
- ready/loaded/in-transit/arrived/delivered status filtering;
- Warehouse handoff + Fleet trip pairing;
- delivery creation;
- vehicle-load confirmation;
- customer, order, vehicle and driver context;
- delivery line planned/loaded/delivered quantities;
- returnable pickup state;
- delivery exception review and manager resolution.

## Driver Mobile

`apps/mobile/lib/delivery_driver.dart`

The delivery execution workspace includes:

- assigned delivery selection;
- customer/address and vehicle context;
- loaded-item quantities;
- Fleet trip start and odometer capture;
- customer arrival confirmation;
- real camera/gallery POD photo selection;
- private Supabase Storage upload;
- receiver name/phone and delivery note;
- delivery completion;
- returnable item/quantity/condition capture;
- returnable pickup close;
- delivery exception reporting;
- vehicle-trip completion after delivery.

If delivery completion fails after the POD file uploads, the mobile client attempts to remove the orphaned Storage object before surfacing the original error.

## Demo data

`supabase/seed_phase10.sql`

The fictional Phase 10 demo contains its own sales order/allocation, additive finished-goods stock, Warehouse pick/staging/handoff, fictional delivery truck/driver/assignment/trip and ready-to-load Dispatch record. It does not advance the Phase 8 Warehouse demo or Phase 9 Fleet demo lifecycle.

## Automated validation

SQL/schema/security smoke coverage:

- `supabase/tests/0020_dispatch_delivery_smoke.sql`
- `supabase/tests/0021_dispatch_scope_smoke.sql`
- `supabase/tests/0022_delivery_pod_storage_smoke.sql`
- `supabase/tests/0023_dispatch_returnable_hardening_smoke.sql`

Authenticated business-flow E2E:

- `supabase/tests/dispatch_auth_e2e.sh`

The authenticated flow validates manager planning, cross-factory denial, driver aggregate-dashboard denial, assigned-driver visibility, unassigned-employee denial, manager-only vehicle loading, staging → vehicle Inventory transfer, trip start/arrival, vehicle → customer issue, POD completion, customer returnable → vehicle receipt, returnable close, exception report/resolution, trip completion, KPI update and audit logging.

Flutter CI validates the shared core, Admin web analysis/release build and Mobile analysis including real `image_picker` POD capture/upload code.

The final Phase 10 checkpoint passes both required gates on the merge candidate:

- **Flutter Application Quality** — success;
- **Supabase Foundation Checks** — success.

## Phase boundary

Phase 10 closes customer delivery and captures returnables onto the vehicle. Physical return-trip unloading, inspection and movement from vehicle stock back into Warehouse good/damaged locations is intentionally kept outside this phase so Warehouse return intake can be implemented as its own auditable workflow.
