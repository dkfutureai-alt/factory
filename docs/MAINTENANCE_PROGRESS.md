# Maintenance development checkpoint (2026-10-14)

## Scope
Design-first Maintenance foundation now covers assets, preventive schedules, work orders, breakdowns, spare requirements, maintenance events and Maintenance-specific reporting. SVG designs 32–37 cover Maintenance Dashboard, Asset Detail, Work Order, Preventive Maintenance Planner, Breakdown & Spare Parts and Maintenance Reports.

## Code and preview
- Typed Maintenance domain with zero-safe asset availability, spare reconciliation, closure readiness, PM compliance, maintenance cost and MTTR derivation.
- Repository interface and fictional preview data for dashboard, asset, work order, preventive planner, breakdown/spares and reports.
- Main Admin sidebar → Maintenance route and modular FactoryOS route registry are wired, preserving all existing named routes.
- Maintenance Dashboard routes to Preventive Planner, Breakdown & Spares and Maintenance Reports.
- Work-order spare consumption is displayed only from ledger-posted quantities; preview controls never mutate inventory.
- Standalone preview entrypoint remains `flutter run -t lib/maintenance_preview.dart` from `apps/factoryos`.

## Database foundation
- Declarative schema order: `09_maintenance.sql` → `09a_maintenance_security.sql` → `09b_maintenance_commands.sql`.
- Demo seed ordering: `08_demo_maintenance_assets.sql` → `08a_demo_maintenance_orders.sql` → `08b_demo_maintenance_spares.sql`.
- Asset, plan, work-order, spare and event scope validation with factory-scoped RLS.
- Spare issue linkage accepts only a posted `maintenance_issue` stock transaction line with matching item, organization, factory and work-order reference. No direct stock quantity updates.
- Finalized work orders and spare requirements are protected by schema guards.
- Work-order status transitions are constrained to valid lifecycle movements.
- `create_preventive_work_order(plan_id, due_on)` is idempotent for each plan occurrence and requires the occurrence to match the plan's next due date.
- `start_maintenance_work_order(work_order_id)` starts/resumes allowed active states and synchronizes the asset to Maintenance.
- `set_maintenance_safety_clearance(work_order_id, cleared)` records the safety gate only for active work orders.
- `complete_maintenance_work_order(work_order_id, root_cause, resolution)` requires active status, safety clearance, root cause, resolution and all required posted spare issues before completion. It returns an asset to Operational only when no other open work order remains and advances the preventive plan when applicable.

## Code verification
Flutter 3.47.7 CI passes `flutter analyze --fatal-infos` and **39 tests** on commit `e6b28b4c91707aec1b4a29e060947d921b9ab32f`.

Verified Maintenance coverage includes:
- asset availability zero/bounds handling;
- unposted spares never counted as consumed;
- work-order closure readiness requirements;
- preventive due-date counting;
- non-negative breakdown spare pending quantities;
- zero-safe/bounded PM compliance, maintenance cost and MTTR derivation;
- Maintenance Dashboard → Work Order → Preventive Planner → Breakdown & Spares → Maintenance Reports navigation;
- Admin sidebar → Maintenance navigation;
- zero-render-exception checks for the tested 1440×1024 Maintenance surfaces.

## Not yet verified / next work
1. Execute Maintenance schema/security/commands against a **dedicated FactoryOS Supabase project** and run PostgreSQL/RLS/RPC tests. Do not use `janseva-production`.
2. Run cross-tenant isolation, preventive idempotency, invalid-transition, posted/reversed spare-ledger, seed-idempotency and Supabase security/performance advisor tests.
3. Connect live Auth/Supabase repositories and real work-order/PM/spare actions. Preview controls must not pretend to mutate production data.
4. Add technician self-service/mobile workflows when the real authentication/repository layer is available.
5. Continue the system-wide Reporting / Analytics milestone, then Notifications / FCM.

**Never modify `janseva-production`.** This checkpoint is a verified repository milestone, not a production-complete backend claim.
