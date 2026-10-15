# Reporting & Analytics development checkpoint (2026-10-14)

## Scope

Design-first system-wide Reporting foundation for FactoryOS. SVG designs 38–43 cover Reports Center, Executive Analytics, Operations Report, Commercial Report, Workforce & Fleet Report and Report Builder / Export Preview.

## Flutter implementation

- Added a typed Reporting domain for date/factory scope, KPI metrics, trend points, scorecards, Operations, Commercial and Workforce/Fleet analytics.
- Added a replaceable `ReportingRepository` with a fictional DKIM preview adapter.
- Added Admin → Reports navigation and named routes for all six Reporting surfaces.
- Reports Center provides cross-module KPI cards, report library navigation and performance trend.
- Executive Analytics provides Revenue, Production, On-time Delivery, Attendance and Asset Availability scorecards plus management attention items.
- Operations Report combines Production, Quality, Inventory and Maintenance indicators.
- Commercial Report combines Sales, Collections, Receivables, Purchase and customer performance.
- Workforce & Fleet Report combines Attendance, Leave, Fleet Availability, Trips and Fuel indicators.
- Report Builder supports report type, report date/factory scope, metric selection and PDF/CSV/Excel **format selection for preview only**.
- Real PDF/CSV/Excel file generation is intentionally not connected until production repositories and server-side export authorization/rules exist.

## Access model

- Reporting reuses the existing `report.read` RBAC permission and enabled Reports module from the FactoryOS foundation seed.
- No new permission vocabulary was introduced for the preview milestone.
- Real repository queries must preserve organization/factory authorization and report scope when Supabase is connected.

## Verification

- Flutter 3.47.7 analysis passes with `--fatal-infos` on the accepted Reporting code head `639314e9f1e6c81d46cf36a3bf00630db3cf8c37`.
- Complete Flutter suite passes **45 tests** at that code milestone.
- Admin → Reports → Executive → Operations → Commercial → Workforce & Fleet → Report Builder is widget-tested at 1440×1024.
- Reporting domain tests cover inclusive/reversed date ranges, non-negative commercial receivables, bounded collection/fleet/line rates, inventory aggregation and export-preview range validity.
- QA caught an unavailable Material icon, a syntax defect, a 14 px Report Library card overflow and a 28 px Reporting KPI overflow before acceptance.
- Shared Reporting KPI cards now use a minimum height rather than a hard height so content can expand without clipping.

## Backend / export status

- This milestone is repository/frontend/domain architecture only; no dedicated Reporting SQL views/materialized views have been deployed.
- Reporting currently reads fictional preview data rather than live Supabase aggregates.
- No real export files are generated yet.
- No scheduled reports, emailed reports, background jobs or notification delivery are implemented yet.

## Next work

1. Notifications / FCM foundation and report/operations alert surfaces.
2. Create/connect a dedicated FactoryOS Supabase project; never use `janseva-production`.
3. Review permission helper scope semantics before deployment.
4. Add authorized Supabase Reporting repositories/views/query functions with organization/factory/date filters.
5. Add server-side export generation/audit rules and real PDF/CSV/Excel downloads after live repositories exist.
6. Database/RLS/report-scope tests and security/performance advisor review.

**This is a verified repository development milestone, not a production-completion claim.**
