# Phase 12 — Reports & Dashboards

## Goal

Turn the operational truth already captured by FactoryOS into a scope-safe management reporting layer without duplicating balances or introducing hardcoded production KPIs.

The reporting chain is:

**Existing module records → tenant/factory authorization → reporting RPCs → executive dashboard / report workspace → saved view / export**

Phase 12 composes HR, Inventory, Production, Quality, Purchase/Sales, Warehouse, Fleet, Dispatch, Maintenance and Audit data. Operational modules remain the source of truth.

## Design First

The approved Phase 12 design reference is:

- `docs/designs/phase12_reports_dashboard.svg`

The implementation keeps the established FactoryOS visual system:

- dark navigation rail with the existing module hierarchy;
- responsive white operational cards;
- factory and period filters;
- high-signal KPI cards;
- planned-vs-actual trend visualization;
- prioritized exception queue;
- module scorecards;
- dense but readable report tables;
- recent audited activity;
- mobile-first management summary.

No KPI is permanently hardcoded in the release UI.

## Backend

Migration:

- `supabase/migrations/0027_reports_dashboards.sql`

Reporting does not create a second operational ledger. All values are calculated from the existing module tables and immutable Inventory/Audit records.

### Saved report views

`report_saved_views` stores only user presentation preferences:

- organization/factory scope;
- owner user;
- report key;
- JSON filters;
- optional default state;
- timestamps.

Saved views do not cache business totals.

RLS restricts every saved view to its owning user and an authorized reporting scope. Factory managers cannot save organization-wide views, and users cannot save views for factories they cannot report on.

## Reporting authorization

`reports_scope_allowed` is the common reporting authorization boundary.

Organization-wide reporting is available only to:

- Platform Owner;
- Organization Admin.

Factory-scoped management reporting is available to:

- Platform Owner;
- Organization Admin;
- Factory Manager with access to that factory;
- Supervisor assigned to that factory.

Employee and Driver roles cannot use the management reporting RPCs.

This is intentionally stricter than generic module visibility.

## Executive dashboard

`reports_executive_dashboard` accepts:

- organization;
- optional factory;
- from date;
- to date.

It derives management KPIs including:

- sales billed and previous-period sales;
- purchase billed and previous-period purchases;
- Inventory on-hand quantity;
- low-stock item count;
- planned and actual Production output;
- Quality completed inspections and pass rate;
- open NCR count;
- open Sales Orders;
- customer receivable and supplier payable;
- Warehouse open picks/staging;
- active Fleet trips;
- completed deliveries;
- open Dispatch exceptions;
- open Maintenance work;
- Maintenance assets down and downtime;
- active employees and present-today count.

The comparison period is calculated from the selected reporting range.

## Trend reporting

`reports_daily_trend` returns one row per day for up to 120 days with:

- sales billed;
- purchase billed;
- Production planned quantity;
- Production actual output;
- completed deliveries.

The Admin trend chart renders these returned values directly.

## Operational exceptions

`reports_operational_exceptions` normalizes actionable exceptions from existing modules into one prioritized queue.

Sources include:

- Inventory items at/below reorder level;
- open Quality NCRs;
- due/overdue Sales Orders;
- due/overdue Purchase Orders;
- open Dispatch delivery exceptions;
- Maintenance assets down;
- overdue Maintenance work.

Every exception includes module, severity, title, detail, entity type/id and timestamp so the UI can remain module-neutral.

## Recent activity

`reports_recent_activity` reads existing `audit_logs` and resolves the actor profile when available.

The dashboard therefore shows audited system activity rather than inventing a separate activity feed.

## Admin Web

Primary implementation:

- `apps/admin_web/lib/reports_dashboard.dart`

Phase 11 Admin entrypoint is retained in:

- `apps/admin_web/lib/main_phase11.dart`

The Phase 12 `main.dart` extends that validated shell rather than replacing earlier module implementations.

Admin functionality includes:

- Executive Dashboard on Overview when Dashboard/Reports is enabled;
- first-class Reports navigation item;
- factory scope selector;
- organization-wide scope only for eligible roles;
- 7/30/90-day period selector;
- KPI cards;
- Production planned-vs-actual trend visualization;
- commercial period totals;
- operational exception queue;
- module scorecards;
- report table;
- recent audited activity;
- saved report views;
- CSV-formatted copy to clipboard;
- responsive desktop/compact layouts;
- loading and error states.

## Mobile

Primary implementation:

- `apps/mobile/lib/reports_mobile.dart`

Phase 11 mobile entrypoint is retained in:

- `apps/mobile/lib/main_phase11.dart`

Reports are exposed only to management roles in the mobile module list.

Mobile functionality includes:

- factory selector;
- organization-wide scope for eligible roles;
- 7/30/90-day filter;
- sales, Inventory and Production KPI cards;
- Production/Quality/Fleet/Delivery/Maintenance/People health summaries;
- prioritized operational exceptions;
- pull-to-refresh;
- loading/error states.

## Tests

SQL smoke test:

- `supabase/tests/0027_reports_dashboards_smoke.sql`

Authenticated workflow test:

- `supabase/tests/reports_auth_e2e.sh`

Validated reporting behavior includes:

- factory manager factory-scoped executive dashboard;
- 30-day trend shape;
- operational exception response shape;
- audited activity response shape;
- Factory Manager organization-wide denial;
- Factory Manager cross-factory denial;
- Employee management-report denial;
- Organization Admin organization-wide reporting;
- authorized saved report view creation;
- organization-wide saved-view denial for Factory Manager.

## Quality gates

Phase 12 is considered complete only when both pipelines are green:

### Supabase Foundation Checks

- clean local Supabase start/reset;
- all migrations through `0027`;
- all previous seeds and workflow tests;
- Reports/Dashboards SQL smoke checks;
- authenticated reporting/RLS flow.

Validated Phase 12 backend run:

- GitHub Actions run `39001138976` — success.

### Flutter Application Quality

- shared core dependency/analyze/test;
- Admin dependencies/analyze;
- Admin release web build;
- mobile dependencies/analyze;
- all earlier module integration preserved.

Validated Phase 12 Flutter run:

- GitHub Actions run `39001447664` — success.

## Completion

Phase 12 is complete when these changes are merged with both PR quality gates green.

Next development phase:

**Phase 13 — Notifications**
