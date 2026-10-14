# FactoryOS Work Log

Last updated: 2026-10-14

| Area | Status | UI Design | Frontend | Backend | Seed Data | Testing | Known Issues |
|---|---|---:|---:|---:|---:|---:|---|
| Phase 0 Repository Audit | COMPLETE | N/A | N/A | N/A | N/A | VERIFIED | Repository was empty at start |
| System Architecture | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | PARTIAL | Dedicated backend deployment pending |
| Multi-tenancy | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | Dedicated FactoryOS Supabase project required |
| RBAC | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | Permission-scope hardening + real RLS/role tests required |
| Design System | DEVELOPING | DEFINED + 47 SVG SPECS | IMPLEMENTING | N/A | N/A | VISUAL + CI REVIEW | Remaining mobile platform/runtime integration pending |
| Authentication | DEVELOPING | LOGIN DESIGNED | PREVIEW IMPLEMENTED | NOT CONNECTED | N/A | FLUTTER VERIFIED | Real Supabase auth pending |
| Organization / Factory Setup | DEVELOPING | FOUNDATION | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | Core schema exists in repo only |
| Admin Dashboard | DEVELOPING | DESIGNED | IMPLEMENTED | REPOSITORY INTERFACE | PREVIEW ADAPTER | ANALYZE + WIDGET TEST PASS | Real aggregate repository pending |
| Employee Mobile Home | DEVELOPING | DESIGNED | IMPLEMENTED + NOTIFICATION ENTRY | NOT CONNECTED | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Driver Mobile Home | DEVELOPING | DRIVER + DELIVERY DESIGNED | TRIP/FUEL/DELIVERY/NOTIFICATION NAVIGATION IMPLEMENTED | FLEET + DELIVERY SELF-SERVICE FOUNDATION | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Inventory | DEVELOPING | DASHBOARD + SCANNER + ITEM DETAIL | DASHBOARD + ITEM DETAIL IMPLEMENTED | INVENTORY LEDGER SCHEMA | DEMO | DOMAIN + NAVIGATION PASS | Real Supabase repository/DB tests pending |
| Scanner | DEVELOPING | DESIGNED | MANUAL FLOW IMPLEMENTED | PORT ABSTRACTION | PREVIEW LOOKUP | UNIT + NAVIGATION PASS | Camera/barcode platform integration pending |
| Production | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PRODUCTION/QUALITY SCHEMA | DEMO | DOMAIN + NAVIGATION PASS | Real Supabase repository/DB tests pending |
| Quality | DEVELOPING | INCLUDED IN PRODUCTION | QC STATE IMPLEMENTED | SCHEMA | DEMO | NAVIGATION + MANUAL SCHEMA REVIEW | DB execution/RLS tests pending |
| Warehouse | DEVELOPING | DASHBOARD | IMPLEMENTED | PREVIEW REPOSITORY ONLY | PREVIEW | NAVIGATION PASS | Transactional warehouse schema/actions pending |
| Dispatch | DEVELOPING | DASHBOARD | DASHBOARD + DELIVERY HANDOFF | PREVIEW REPOSITORY ONLY | PREVIEW | NAVIGATION PASS | Full dispatch transactional schema/actions pending |
| Purchase | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PURCHASE + GRN SCHEMA | DEMO SEEDED | DOMAIN + NAVIGATION PASS | Real DB/RLS/receipt RPC tests pending |
| HR | DEVELOPING | DASHBOARD + EMPLOYEE + ATTENDANCE/LEAVE + HOLIDAYS | IMPLEMENTED | HR/ATTENDANCE/LEAVE/HOLIDAY SCHEMA | 40-EMPLOYEE DEMO | DOMAIN + NAVIGATION PASS | Real DB/RLS and live commands pending |
| Sales | DEVELOPING | DASHBOARD + CUSTOMER + ORDER + PAYMENT/DELIVERY | IMPLEMENTED | CUSTOMER/ORDER/PAYMENT SCHEMA | DEMO SEEDED | DOMAIN + NAVIGATION PASS | Real DB/RLS/payment commands + full Dispatch integration pending |
| Vehicles / Drivers | DEVELOPING | FLEET + VEHICLE + DRIVER | IMPLEMENTED | FLEET/ASSIGNMENT/DRIVER PROFILE SCHEMA | 10 VEHICLES + 10 HR-LINKED DRIVERS | DOMAIN + ADMIN/MOBILE NAVIGATION PASS | Real DB/RLS/assignment tests pending |
| Trips / Fuel | DEVELOPING | TRIP + FUEL | IMPLEMENTED | TRIP/INSPECTION/FUEL SCHEMA + COMMAND RPCs | DEMO SEEDED | DOMAIN + ADMIN/MOBILE NAVIGATION PASS | Real DB/RPC/approval tests pending |
| Delivery | DEVELOPING | DASHBOARD + DETAIL/POD + DRIVER + EXCEPTION/RETURN | IMPLEMENTED | DELIVERY/POD/EXCEPTION/EVENT SCHEMA + DRIVER RPCs + RETURN LEDGER VALIDATION | DEMO SEEDED | DOMAIN + DESKTOP/MOBILE NAVIGATION PASS | Real DB/RLS/RPC/POD storage tests pending |
| Maintenance | DEVELOPING | 6 SVG DESIGNS | DASHBOARD + ASSET + WORK ORDER + PM + BREAKDOWN/SPARES + REPORTS IMPLEMENTED | SCHEMA + RLS + LIFECYCLE COMMAND RPCs | FICTIONAL ASSET/ORDER/SPARE SEED | ANALYZE + DOMAIN + NAVIGATION PASS | Real DB/RLS/RPC tests and live repositories pending |
| Reporting / Analytics | DEVELOPING | 6 SVG DESIGNS | REPORTS CENTER + EXECUTIVE + OPERATIONS + COMMERCIAL + WORKFORCE/FLEET + BUILDER IMPLEMENTED | TYPED REPOSITORY/DOMAIN FOUNDATION; EXISTING `report.read` ACCESS MODEL | FICTIONAL CROSS-MODULE PREVIEW | ANALYZE + REGRESSION PASS | Live Supabase aggregates/views and real PDF/CSV/Excel generation pending |
| Notifications | DEVELOPING | 4 SVG DESIGNS | ADMIN CENTER + RULES + EMPLOYEE/DRIVER INBOX + PREFERENCES IMPLEMENTED | NOTIFICATION/RULE/TOKEN/PREFERENCE/RECIPIENT/DELIVERY-ATTEMPT SCHEMA + MARK-READ RPC + PUSH PORT | FICTIONAL RULES/EVENTS | ANALYZE + 53 TESTS PASS | Real Supabase execution, trusted dispatcher and Firebase/FCM platform setup pending |
| Audit / Security | DEVELOPING | N/A | NOT STARTED | CORE FOUNDATION + MODULE VALIDATION/GUARDS | N/A | MANUAL REVIEW | Permission helper scope + Supabase advisors + cross-tenant/RLS tests pending |
| Full E2E QA | NOT STARTED | N/A | N/A | N/A | N/A | NOT STARTED | Requires deployed workflows |

See [Maintenance checkpoint](MAINTENANCE_PROGRESS.md), [Reporting checkpoint](REPORTING_PROGRESS.md) and [Notifications checkpoint](NOTIFICATIONS_PROGRESS.md) for verified repository milestones and remaining production gates.

## Landed in repository

- Initialized the repository, architecture, RBAC/tenancy, business-flow and design-system documentation.
- Added declarative Supabase/PostgreSQL foundation for organizations, factories, memberships, roles, permissions, modules and audit records.
- Added immutable Inventory ledger with posting rules, derived balances and review hardening.
- Added Production/Quality orders, batches, material-consumption/output links and QC foundation.
- Added Purchase suppliers, purchase orders, GRNs and receipt-to-ledger linkage.
- Added HR employees, isolated private data, attendance, leave and holidays.
- Added Sales customers, addresses, orders, order lines, payments and derived financials.
- Added Fleet vehicles, HR-linked driver profiles, assignments, trips, inspections and fuel records plus driver/fuel command RPCs.
- Added Delivery records, delivery lines, POD, exceptions, events, assigned-driver commands, anti-overship checks and `customer_return` ledger validation.
- Added Maintenance assets, preventive schedules, work orders, spare requirements, events, factory-scoped RLS and lifecycle command RPCs.
- Maintenance spare consumption is never a direct stock update. A required spare is considered consumed only when linked to a valid posted `maintenance_issue` Inventory ledger line for the same work order/item/tenant/factory.
- Maintenance work-order completion requires valid active state, safety clearance, root cause, resolution and all required posted spare issues.
- Preventive work-order creation is idempotent per plan occurrence and cannot create a duplicate work order for the same plan/date.
- Maintenance status-transition guards prevent invalid work-order lifecycle jumps.
- Added system-wide Reporting domain/repository foundation using the existing `report.read` permission instead of introducing a parallel access model.
- Reporting frontend includes Reports Center, Executive Analytics, Operations Report, Commercial Report, Workforce & Fleet Report and Report Builder / Export Preview.
- Reporting calculations include bounded rates, inclusive date ranges, non-negative receivables/outstanding values, inventory aggregation and zero-safe fleet availability.
- Report Builder preserves report type, date/factory scope, metric selection and export-format selection in preview; real PDF/CSV/Excel generation is not connected yet.
- Added Notifications domain/repository foundation with normal/high/critical priority, in-app/push channels, mandatory-critical preferences and zero-safe notification KPIs.
- Added Admin Notification Center + Alert Rules, Employee/Driver mobile inboxes and Notification Preferences from the existing bell entry points.
- Added a replaceable push transport boundary. Preview mode explicitly reports push unsupported; no Firebase credentials or fake delivery behavior are bundled.
- Added repo-only Notifications schema for templates, role/factory rules, self-owned device tokens, preferences/quiet hours, events, recipients/read state, push status and service-only delivery attempts.
- Added tenant/reference guards, mandatory critical-alert preference enforcement and self-only mark-read RPC foundation.
- Device-token RLS is self-only; authenticated managers do not receive raw token/delivery-attempt access. Notification event/recipient creation remains trusted server-side work.
- Added fictional DKIM notification templates/rules/events without seeding auth users, recipients, device tokens or real FCM tokens.
- Added fictional DKIM demo data across Inventory, Production/QC, Purchase, HR, Sales, Fleet, Delivery and Maintenance plus cross-module Reporting/Notification preview data. Protected/private employee details remain intentionally unseeded.
- HR demo remains 40 fictional employees; Fleet reuses existing employees for driver roles instead of duplicating identities.
- Added **47 design-first SVG specifications** through Notification Rules / Templates.
- Flutter application now includes Login, Admin, Employee/Driver Home, Inventory, Production, Warehouse, Dispatch, Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications surfaces.
- Modular route registries preserve the existing named-route structure as modules grow.
- Scanner manual SKU/barcode/QR lookup works through a replaceable port; camera support remains intentionally disabled pending mobile platform setup.

## Verified repository-level behavior

- GitHub repository/branch/PR writes are confirmed through the connected GitHub account.
- `janseva-production` has not been modified for FactoryOS.
- Flutter 3.47.7 CI passes `flutter analyze --fatal-infos`.
- At accepted Notifications code milestone `eb1cea5b2cd0530d8b161d1c9fc57e0dd1be5ba5`, the complete Flutter suite passes **53 tests**.
- Admin → Notifications → Alert Rules is regression-tested at 1440×1024 with zero render exceptions.
- Employee → notification bell → inbox → preferences and Driver → notification bell → assigned alerts are regression-tested at 390×844 with zero render exceptions.
- Notification domain tests verify unread/critical/action derivations, bounded zero-safe push-enabled rates, mandatory critical preferences, push-channel rules and device-registration validation.
- QA exposed and fixed existing Employee/Driver quick-action mobile overflows while adding strict notification journeys; the corrected grids now render at mobile width.
- QA also hardened the older Driver → Delivery test so it settles viewport scrolling before tapping a below-fold card.
- Admin → Reports → Executive → Operations → Commercial → Workforce & Fleet → Report Builder remains regression-tested at 1440×1024.
- Reporting domain tests verify inclusive/reversed date ranges, non-negative receivables/customer outstanding values, bounded collection/line/fleet rates, inventory aggregation and report-preview validity.
- Previously accepted Inventory, Scanner, Production, Purchase, HR, Sales, Fleet, Delivery, Warehouse, Dispatch, Maintenance and Reporting navigation/domain coverage remains green.
- Maintenance regression coverage verifies zero-safe/bounded asset availability, posted-spare reconciliation, closure readiness, preventive due counting, non-negative spare pending quantity, PM compliance, cost and MTTR derivation.
- Delivery reconciliation/POD/return derivation, Fleet service/fuel calculations, Sales financial calculations, HR attendance/leave calculations, Purchase quantities/values, Production shortage and Inventory stock classification remain regression-tested.

## Not yet verified / production blockers

- FactoryOS schemas have **not** been executed against a dedicated FactoryOS Supabase project.
- Core, Inventory, Production/QC, Purchase, HR, Sales, Fleet, Delivery, Maintenance and Notifications RLS/permission isolation have not been database-tested.
- Known permission-helper factory/org scope semantics require hardening before deployment.
- Inventory posting, Production completion, Fleet, Delivery, Maintenance and Notification RPC/guards have not been executed against a real FactoryOS database.
- Real authentication is not connected; current login is a preview implementation.
- Operational, Reporting and Notification repositories remain replaceable preview adapters until dedicated Supabase is connected.
- Reporting does not yet use live SQL views/query functions/materialized aggregates, and report scope authorization has not been DB-tested.
- Real PDF/CSV/Excel files are **not** generated yet; Report Builder currently produces an on-screen preview only.
- Notifications have no connected Firebase project, no real FCM token lifecycle, no Android/iOS/web platform configuration and no trusted server-side dispatcher/retry worker yet.
- Notification read/preferences preview behavior is not synced to Supabase, and Notifications RLS/trigger/RPC behavior remains unexecuted.
- Warehouse and Dispatch full transactional schemas/actions are still missing; therefore Dispatch → Trip → Delivery → Return → Warehouse is not yet production-complete end to end.
- Purchase/HR/Sales/Fleet/Delivery/Maintenance mutation controls are not connected to live repositories.
- POD object storage and scanner camera permissions/runtime integrations are pending.
- Full E2E QA requires deployed workflows.

## Pending dependency order

1. Harden **RBAC / permission scope** and add database integration/security test harness repo-side before deployment.
2. Create/connect a dedicated FactoryOS Supabase project after required organization/cost confirmation; never reuse `janseva-production`.
3. Apply schemas in dependency order: core → Inventory + review fixes → Production/Quality + review fixes → Purchase → HR + review fixes → Sales → Fleet + review fixes + commands → Delivery + review fixes → Maintenance + security + commands → Notifications → demo seeds.
4. Run cross-tenant/RLS tests, command/RPC integrity tests, notification scope/token tests, ledger/report-scope tests and Supabase security/performance advisors.
5. Replace preview Auth/repositories with Supabase-backed implementations and connect mutation actions.
6. Add trusted notification dispatch plus real FCM Android/iOS/web token registration, foreground/background handling, retry and delivery auditing.
7. Add authorized Reporting SQL views/query functions/repositories and real server-side PDF/CSV/Excel generation/audit rules.
8. Add Warehouse/Dispatch transactional backends and verify the full Dispatch → Trip → Delivery → Return → Warehouse flow.
9. Add Android/iOS camera/barcode/POD capture setup and permissions, then run full production E2E QA.

## Rule

Statuses describe verified repository/database reality. A design, schema file, passing Flutter screen or unexecuted SQL file alone is not a production-complete module.
