# Phase 8 — Warehouse

Status: **complete and CI validated**.

## Workflow

Phase 8 turns the existing Inventory location tree into an operational warehouse flow while preserving the Inventory ledger as the only stock truth:

**Warehouse → Zone → Bin → Put-away → Stock Availability/Reservation → Pick List → Picking → Staging → Dispatch Handoff → Cycle Count → Stock Adjustment → Reports**

Physical dispatch/Inventory issue remains reserved for the Dispatch & Delivery phase. Warehouse handoff stops at staged stock ready for Dispatch.

## Location hierarchy

Migration: `supabase/migrations/0015_warehouse_operations.sql`

`stock_locations` remains the canonical location master and now supports:

- warehouse;
- zone;
- bin;
- receiving;
- staging;
- existing production, quality, dispatch, vehicle, quarantine and other locations.

Warehouse metadata includes capacity, aisle, rack, level and sequence fields. Parent location links provide warehouse → zone → bin hierarchy without duplicating Inventory locations.

## Operational tables

- `warehouse_putaway_tasks`
- `warehouse_pick_lists`
- `warehouse_pick_lines`
- `warehouse_dispatch_handoffs`
- `warehouse_cycle_counts`
- `warehouse_cycle_count_lines`
- `warehouse_stock_adjustments`

All operational tables use RLS and factory visibility. Direct stock-changing writes are performed through server RPCs.

## Put-away

- Supervisors/managers create put-away tasks from available source stock to an active warehouse bin.
- Open tasks reserve source quantity operationally so the same stock cannot be assigned twice.
- Employees/supervisors can start and complete assigned-factory put-away operations.
- Completion performs an atomic Inventory transfer and signed stock-ledger movement.
- Optional Goods Receipt linkage supports Purchase → GRN → Incoming Quality → release → put-away continuity.

## Picking and staging

- Pick lists are generated from active Sales Order allocations.
- Only allocated/dispatch-ready orders can enter warehouse picking.
- Staging must be an active staging/dispatch location in the same factory.
- Each pick line references the existing Sales allocation rather than creating another reservation system.
- Confirming a pick transfers physical stock from the allocation source to staging using the Inventory ledger.
- The Sales allocation location is synchronized to staging after the physical move.
- A list becomes `picked` only when all lines are completed.
- Staging creates a Dispatch handoff record.
- Supervisor handoff marks the Warehouse side complete while the Sales Order remains dispatch-ready for the later Dispatch module.

## Cycle counts and adjustments

- Cycle count creation snapshots ledger-derived stock at one warehouse location.
- Employees/supervisors record physical counted quantities.
- Every line must be counted before submission.
- Manager approval checks that stock has not moved since the snapshot; stale counts are rejected instead of silently adjusting changed stock.
- Variances create ledger-backed receive/issue adjustments atomically.
- Manual warehouse adjustments are manager-only, require a reason, reject negative stock, and create immutable adjustment history.

## Reports

Database report surfaces:

- `warehouse_dashboard_summary`
- `warehouse_bin_stock_report`
- `warehouse_putaway_report`
- `warehouse_pick_report`
- `warehouse_cycle_count_report`

`warehouse_bin_stock_report` exposes on-hand, Sales-reserved and available quantities by warehouse location, using the existing stock ledger and Sales allocation records.

## Admin Web

`apps/admin_web/lib/warehouse_management.dart`

Connected sections:

- Dashboard
- Warehouse / Zone / Bin locations
- Put-away
- Picking / Staging / Dispatch handoff
- Cycle counts
- Stock adjustments
- Warehouse reports

The Warehouse tab is enabled from the existing organization module configuration.

## Mobile

`apps/mobile/lib/warehouse_operations.dart`

Employee/supervisor operations include:

- start/complete put-away;
- start pick list;
- confirm individual pick lines;
- stage fully picked orders;
- supervisor handoff to Dispatch;
- physical cycle-count entry and submission.

The Warehouse module card routes into this operational workspace.

## Demo data

`supabase/seed_phase8.sql`

The fictional Aarohan demo includes:

- raw receiving area;
- raw-material zone and bin;
- finished-goods zone and bin;
- dispatch staging location;
- pending PPE put-away task;
- released medical-oxygen pick list;
- historical zero-variance cycle count.

No real company/person data is used.

## Automated validation

SQL smoke coverage: `supabase/tests/0015_warehouse_smoke.sql`

Authenticated E2E: `supabase/tests/warehouse_auth_e2e.sh`

Validated behaviors include:

- supervisor put-away planning;
- employee put-away execution;
- ledger-backed source → bin transfer;
- employee pick-list planning denial;
- supervisor pick-list creation;
- employee pick confirmation;
- physical source → staging transfer;
- Sales allocation location synchronization;
- staging and supervisor Dispatch handoff;
- employee cycle-count execution/submission;
- employee approval denial and manager approval;
- employee manual-adjustment denial;
- manager ledger-backed adjustment;
- Factory Manager cross-factory warehouse denial;
- warehouse dashboard and location stock/reservation report visibility.

Final CI validation passed:

- clean Supabase start/reset;
- migrations `0001`–`0015`;
- base + Phase 5 + Phase 6 + Phase 7 + Phase 8 seed layers;
- every SQL smoke/integrity test;
- full authenticated HR → Inventory → Production → Quality → Purchase/Sales → Warehouse flow;
- shared Flutter core analyze/tests;
- Admin Analyze including Warehouse;
- Admin release web build including Warehouse;
- Mobile Analyze including Warehouse.

## Next

Phase 9: Vehicles, Drivers, Trips & Fuel — vehicle/driver masters, assignments, trip lifecycle, odometer/fuel controls, driver mobile workflow, route/dispatch linkage, service reminders and fleet reports.
