# Phase 11 — Maintenance

## Goal

Connect factory asset maintenance to the existing FactoryOS tenancy, HR, Inventory, audit and mobile execution model without creating a separate maintenance silo.

Operational chain:

**Asset → Preventive Plan / Breakdown Request → Work Order → Technician → Spare Consumption → Downtime → Completion → History / Report**

## Design Lock

Phase 11 keeps the approved FactoryOS visual language:

- existing responsive Admin navigation rail and compact mobile shell;
- white operational cards with strong hierarchy;
- concise status chips and action-first forms;
- factory selector on management surfaces;
- mobile-first technician execution;
- no hardcoded production dashboard statistics.

The Maintenance Admin workspace exposes KPI cards, work-order master/detail execution, asset cards, preventive-plan scheduling and breakdown requests. The mobile workspace prioritizes assigned work and issue reporting.

## Backend

Migration:

- `supabase/migrations/0024_maintenance_operations.sql`

Seed:

- `supabase/seed_phase11.sql`

Operational tables:

- `maintenance_assets`
- `maintenance_plans`
- `maintenance_requests`
- `maintenance_work_orders`
- `maintenance_part_usages`
- `maintenance_downtime_events`
- `maintenance_work_logs`

All operational tables are organization/factory scoped and use RLS.

## Asset Master

Assets support:

- stable asset code and name;
- category, manufacturer, model and serial number;
- plant area;
- criticality;
- operating status;
- commissioning / warranty dates;
- optional hours, cycles or kilometre meter;
- current meter reading;
- active / retired lifecycle.

Organization and factory scope are immutable after creation.

## Preventive Maintenance

Maintenance plans support:

- preventive service;
- inspection;
- calibration;
- lubrication;
- cleaning;
- other recurring work;
- date-frequency scheduling;
- meter-interval scheduling;
- checklist JSON;
- estimated execution time;
- last completed date / meter;
- next due date / meter.

`maintenance_generate_due_work_orders` creates due work while preventing duplicate active work orders for the same plan.

## Breakdown / Corrective Requests

Factory staff may report maintenance requests from the mobile app.

A request records:

- asset;
- type;
- priority;
- title and description;
- reporter;
- safety-stop flag;
- lifecycle state and resolution.

Breakdown or safety-stop reporting moves the asset to `down` until maintenance execution takes control.

## Work Orders

Work orders may originate from:

- a breakdown/corrective request;
- a preventive plan;
- direct manager/supervisor planning.

Lifecycle:

`planned → assigned → in_progress → on_hold / in_progress → completed`

Closed work cannot be reopened by execution RPCs.

Work orders capture:

- asset, request and plan relationship;
- work type and priority;
- assigned employee;
- planned/start/completion timestamps;
- meter at start/completion;
- root cause;
- resolution;
- downtime minutes;
- execution notes.

## Technician Permissions

Factory Managers and Organization Admins retain management rights.

Assigned Supervisors may supervise their factory Maintenance operations.

Employees do not receive broad maintenance-management or Inventory-manager permissions. Instead, an employee may execute only a work order assigned to their active employee record and factory.

Execution RPCs enforce this relationship before starting, holding, resuming, logging, issuing parts or completing work.

## Inventory Integration

Maintenance spare consumption is ledger-backed.

`maintenance_issue_part`:

1. verifies that the work order is in progress;
2. verifies the current user may operate that work order;
3. accepts only active `spare`, `consumable` or `other` Inventory items;
4. verifies the source location is active and belongs to the work-order factory;
5. calculates stock from immutable `stock_ledger_entries`;
6. rejects insufficient stock;
7. creates an `inventory_transactions` issue;
8. creates the negative stock-ledger movement;
9. creates immutable `maintenance_part_usages` history;
10. creates a work log.

Maintenance therefore never keeps a second independent spare-stock balance.

## Downtime

Breakdown/corrective work creates a downtime event when work starts.

Completion closes open downtime, calculates elapsed minutes and stores the summed downtime on the work order.

Only one open downtime event may exist for a work order.

## Completion

`maintenance_complete_work_order` atomically:

- validates active execution;
- validates monotonic meter reading;
- closes downtime;
- completes the work order;
- returns the asset to active service;
- resolves a linked request;
- advances linked preventive-plan due date / meter;
- records completion history.

## Reporting

`maintenance_dashboard_summary` provides database-derived factory metrics including:

- assets;
- assets down;
- assets in maintenance;
- critical assets;
- open / critical requests;
- open / in-progress work orders;
- completed work in the last 30 days;
- downtime minutes in the last 30 days;
- due preventive plans.

`maintenance_work_order_report` provides work-order history with asset, status, technician, schedule, completion, downtime and spare quantity.

Organization-wide reporting is restricted to Platform Owner / Organization Admin. Factory-scoped reporting follows factory visibility.

## Admin Web

`apps/admin_web/lib/maintenance_management.dart`

Admin capabilities:

- factory-scoped Maintenance dashboard;
- asset creation;
- preventive plan creation;
- due-work generation;
- request triage into work orders;
- technician assignment;
- work-order start / hold / resume / completion;
- Inventory-backed spare issue;
- work logs and spare history;
- responsive master/detail layout.

The existing Admin implementation is retained in `main_legacy.dart`; the Phase 11 entry shell reuses all earlier screens and adds Maintenance as a first-class navigation item.

## Mobile

`apps/mobile/lib/maintenance_execution.dart`

Mobile capabilities:

- report breakdown / corrective / safety / service requests;
- safety-stop flag;
- assigned technician work list;
- manager/supervisor factory work visibility when permitted;
- start work with optional meter reading;
- hold and resume;
- add work notes;
- issue Inventory spare/consumable stock;
- complete with resolution, root cause and optional meter reading;
- recent request history;
- factory Maintenance summary.

The Phase 11 mobile entry shell retains all prior mobile modules and routes the existing `maintenance` module tile to the new execution workspace.

## Seed Data

Phase 11 seed data is fictional and interconnected with the existing demo tenant.

It includes:

- oxygen booster compressor;
- cylinder filling manifold;
- diesel generator;
- fire hydrant pump;
- recurring date/meter preventive plans;
- an active breakdown request;
- assigned work in progress;
- an overdue preventive work order;
- open downtime and work-log history.

## Automated Validation

SQL smoke coverage:

- `supabase/tests/0024_maintenance_smoke.sql`

Authenticated flow coverage:

- `supabase/tests/maintenance_auth_e2e.sh`

The authenticated test exercises:

- employee work-order-planning denial;
- manager cross-factory denial;
- employee cross-factory request denial;
- breakdown report → asset down;
- manager work creation and assignment;
- assigned employee start → asset maintenance;
- ledger-backed spare issue;
- negative-stock denial;
- hold → resume → work log;
- completion → asset active + request resolved + downtime closed;
- due preventive work generation;
- factory RLS isolation;
- organization-wide employee dashboard denial;
- factory-scoped dashboard and maintenance report.

Flutter quality gates analyze shared core, Admin and mobile, and build the Admin release web bundle.

## Completion Rule

Phase 11 is complete only when:

- Supabase reset applies migrations and all phase seeds cleanly;
- all SQL smoke tests pass;
- all authenticated E2E flows including Maintenance pass;
- Admin Flutter analysis and release web build pass;
- mobile Flutter analysis passes;
- no previous Phase 1–10 workflow regresses.
