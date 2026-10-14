# Maintenance development checkpoint (2026-10-14)

## Scope
Design-first Maintenance foundation: assets, preventive schedules, work orders, spare requirements and maintenance events. SVG designs 32–34 cover dashboard, asset detail and work-order detail. The PM planner screen is implemented as Flutter UI.

## Code and preview
- Typed Maintenance domain with zero-safe asset availability, spare reconciliation and closure readiness.
- Repository interface and fictional preview data; dashboard, asset, work order and preventive planner screens.
- Standalone preview entrypoint: `flutter run -t lib/maintenance_preview.dart` from `apps/factoryos`.
- Domain and widget tests. Main Admin sidebar route is **not yet wired**; do not call the module integrated into the main app.

## Database foundation
- Declarative schema: `09_maintenance.sql`, then `09a_maintenance_security.sql`.
- Demo seed ordering: `08_demo_maintenance_assets.sql` → `08a_demo_maintenance_orders.sql` → `08b_demo_maintenance_spares.sql`.
- Asset, plan, work order, spare and event scope validation; factory-scoped RLS.
- Spare issue linkage accepts only a posted `maintenance_issue` stock transaction with matching item, organization, factory and work-order reference. No direct stock quantity updates.
- Finalized work-order protection and closure preconditions are schema foundations; production RPCs, RLS tests and DB execution remain pending.

## Not yet verified / next work
1. Wire Admin sidebar and main routes without disturbing prior modules.
2. Add idempotent preventive occurrence creation and transactional close/approval RPCs; audit and strengthen state transitions.
3. Run actual PostgreSQL/Supabase schema execution, RLS cross-tenant tests, posted/reversed spare-ledger tests, seed idempotency tests and security advisors in a **dedicated FactoryOS** project.
4. Connect live Auth/Supabase repositories and real work-order actions. Preview controls must not pretend to mutate production data.
5. Run full Flutter CI, fix failures, then update `docs/WORK_LOG.md` and PR #1 with verified results.

**Never modify `janseva-production`.** This checkpoint is not a production-complete milestone.
