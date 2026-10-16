# Phase 10 — Dispatch, Delivery & Returnables

Status: **backend foundation implemented; validation and UI integration in progress**.

## Workflow

**Warehouse handoff → Delivery creation → Vehicle load → Fleet trip start → In transit → Arrive customer → POD delivery → Returnable pickup → Exception resolution → Close**

Phase 10 consumes the validated Phase 8 Warehouse handoff and Phase 9 Fleet trip. Inventory movement remains ledger-backed and immutable.

## Design-first checkpoint

Committed before implementation:

- `docs/designs/phase10_dispatch_admin.svg`
- `docs/designs/phase10_driver_delivery.svg`

The Admin design covers queue/status KPIs, vehicle-load confirmation, delivery detail, POD visibility and returnables. The Driver design covers assigned load, delivery confirmation, POD capture direction and returnable pickup.

## Backend foundation

Migration:

- `supabase/migrations/0020_dispatch_delivery_returnables.sql`

Tables:

- `dispatch_deliveries`
- `dispatch_delivery_lines`
- `dispatch_returnable_pickups`
- `dispatch_returnable_lines`
- `dispatch_delivery_exceptions`

Inventory items now include `is_returnable` for explicit returnable configuration; cylinder items are also accepted as returnables.

## Inventory truth

Vehicle load posts an Inventory transfer from the Warehouse staging location to the vehicle's existing Fleet stock location.

Completed delivery posts an Inventory issue from the vehicle location to the external customer.

Returnable pickup posts an Inventory receive into the vehicle location and records condition separately so later Warehouse intake can route good/damaged units appropriately.

## Security

- RLS enabled on every Dispatch table.
- Admin/supervisor planning is required for delivery creation and vehicle load.
- Driver execution is restricted to the signed-in driver's own delivery through the existing Fleet identity chain.
- Inventory helper functions are internal and not granted to application roles directly.
- POD completion requires receiver name plus either photo or signature reference.
- Exceptions are driver-reportable and manager-resolvable.

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

## Validation

SQL smoke coverage:

- `supabase/tests/0020_dispatch_delivery_smoke.sql`

Next validation steps:

1. get migration + smoke CI green;
2. add authenticated Manager + Driver E2E for load/delivery/returnable/cross-factory denial;
3. add fictional Phase 10 seed data;
4. implement Admin web Dispatch workspace from the approved SVG;
5. implement Driver mobile delivery/POD/returnables workspace from the approved SVG;
6. connect navigation and repositories;
7. run Flutter analyze/tests and compare implementation against design;
8. fix/retest before Phase 10 is marked complete.
