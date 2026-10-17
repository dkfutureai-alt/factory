# Phase 11 — Maintenance Management

Status: **complete and CI validated**.

## Workflow

**Asset / Equipment → Maintenance Request or Preventive Plan → Work Order → Technician Assignment → Checklist / Work Updates → Downtime / Spare Usage → Completion → Cost & Downtime Reporting**

Phase 11 extends the existing FactoryOS tenant, HR, Production and Inventory primitives instead of introducing parallel identities or stock records.

## Design-first checkpoint

Created before implementation and preserved in the repository:

- `docs/designs/phase11_maintenance_admin.svg`
- `docs/designs/phase11_maintenance_mobile.svg`

The Admin reference covers maintenance KPIs, assets, work orders, preventive maintenance, requests, spare usage and downtime. The Technician reference covers assigned work, QR asset scanning, checklist execution, updates/photos, requests and PM schedule.

## Backend

Migrations:

- `supabase/migrations/0024_maintenance_operations.sql`
- `supabase/migrations/0025_maintenance_media_storage.sql`
- `supabase/migrations/0026_maintenance_pm_integrity.sql`

Operational tables:

- `maintenance_assets`
- `maintenance_requests`
- `maintenance_plans`
- `maintenance_plan_tasks`
- `maintenance_work_orders`
- `maintenance_work_order_tasks`
- `maintenance_work_updates`
- `maintenance_spare_usage`
- `maintenance_downtime_events`

Assets can link to existing Production work centers and FactoryOS stock locations. Technician identity reuses existing HR employees and factory membership.

## Asset & request lifecycle

Maintenance assets support machine/equipment/utility/tool/other classifications, criticality, running/idle/maintenance/down/retired status, serial/model/manufacturer metadata, work-center/location linkage and QR identification.

Employees can raise maintenance requests for visible assets. Planning roles can approve/reject them and convert requests into work orders.

## Preventive maintenance

Preventive plans support:

- preventive, inspection and calibration types;
- day/week/month frequencies;
- next-due date;
- default technician and priority;
- estimated duration and instructions;
- reusable checklist tasks;
- due-work-order generation.

A partial unique index guarantees that one preventive plan cannot have more than one active work order at the same time. Completing a plan-derived work order advances the plan's next due date.

## Work orders & technician execution

Work orders support open, assigned, in-progress, on-hold, completed and cancelled states.

Technicians can execute only work orders assigned to their employee identity unless they hold a planning/admin role. Execution includes:

- start/resume;
- required checklist completion;
- timestamped work updates;
- optional private work photos;
- spare/consumable usage;
- downtime start/end;
- resolution, labor minutes and external cost on completion.

Completion is blocked while required checklist items or an active downtime event remain open.

## Inventory truth for spare parts

Maintenance does not maintain a second stock balance.

`maintenance_use_spare` validates current stock from `stock_ledger_entries`, creates the normal FactoryOS Inventory `issue` transaction, posts the negative ledger entry and records the transaction reference in `maintenance_spare_usage`.

Only active Inventory items classified as `spare` or `consumable` can be issued through Maintenance.

## Downtime

Generic Maintenance downtime is asset/work-order scoped and intentionally separate from Production batch downtime. Only one open downtime event is allowed per work order. Start/end timestamps and derived duration feed maintenance reporting.

## Security

- RLS is enabled on every Maintenance operational table.
- Tenant/factory visibility reuses existing FactoryOS factory membership rules.
- Asset and planning mutations are restricted to authorized planning roles.
- Employee requests remain visible to their requester and planners.
- Work-order tasks, updates, spare usage and downtime are visible/executable only to planners or the assigned technician.
- Cross-factory actions are rejected.
- Maintenance changes write into the existing audit log.

## Secure maintenance media

Private Storage bucket: `maintenance-media`.

Object path:

`<organization_id>/<factory_id>/<work_order_id>/<user_id>/<filename>`

Storage policies enforce work-order visibility for reads and authenticated uploader-folder ownership for mutations. Images are limited to JPEG/PNG/WebP and 10 MB per object.

## Admin Web

`apps/admin_web/lib/maintenance_management.dart`

Connected through the existing `maintenance` module.

Admin features include:

- factory-scoped KPI cards;
- recent work orders and asset status;
- asset/equipment creation with work-center/location linkage;
- maintenance request review/approval/rejection/conversion;
- preventive schedule creation and due-WO generation;
- work-order creation and technician assignment;
- spare-usage cost visibility;
- downtime visibility;
- loading/error states and responsive FactoryOS layout.

## Technician / Employee Mobile

`apps/mobile/lib/maintenance_technician.dart`

The Maintenance workspace includes:

- home counters and assigned-work summary;
- My Work Orders;
- start/resume work;
- checklist task execution;
- work updates with real camera/gallery image upload;
- spare-part issue against the Inventory ledger;
- downtime start/end;
- work-order completion;
- asset list and QR/barcode scanning;
- maintenance request creation from asset or scan;
- preventive maintenance schedule.

## Demo data

`supabase/seed_phase11.sql`

The fictional demo includes compressor, generator, filling-line, RO-plant and pump assets, preventive plans/checklists, requests, assigned/in-progress/completed work orders, spare stock, historical spare usage and downtime.

## Automated validation

SQL/schema/security coverage:

- `supabase/tests/0024_maintenance_smoke.sql`
- `supabase/tests/0025_maintenance_media_smoke.sql`
- `supabase/tests/0026_maintenance_integrity_smoke.sql`

Authenticated workflow:

- `supabase/tests/maintenance_auth_e2e.sh`

The E2E validates manager planning, employee denial for asset administration, blocked-factory denial, employee request creation, PM creation/checklists, due-WO generation, assigned-technician visibility, dashboard authorization, work start, downtime, ledger-backed spare issue, updates, checklist completion, work completion, asset recovery, next-due advancement and audit logging.

Flutter validation covers shared core tests, Admin analysis/release web build, Mobile analysis and Maintenance snapshot tests for QR matching, spare filtering and active downtime selection.

## Phase boundary

Phase 11 delivers operational maintenance execution and module-level KPIs/reports. Cross-module executive analytics, consolidated management dashboards and broader report-builder surfaces remain the next phase.

**Next: Phase 12 — Reports & Dashboards.**
