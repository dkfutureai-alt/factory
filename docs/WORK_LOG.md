# FactoryOS Work Log

Last updated: 2026-10-14

| Area | Status | UI Design | Frontend | Backend | Seed Data | Testing | Known Issues |
|---|---|---:|---:|---:|---:|---:|---|
| Phase 0 Repository Audit | COMPLETE | N/A | N/A | N/A | N/A | VERIFIED | Repository was empty at start |
| System Architecture | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | FLUTTER + POSTGRES CI | Dedicated backend deployment pending |
| Multi-tenancy | DEVELOPING | N/A | FOUNDATION | EXPLICIT ORG/FACTORY/WAREHOUSE/DEPARTMENT SCOPE FOUNDATION | DEVELOPING | POSTGRES CROSS-SCOPE TESTS PASS | Dedicated FactoryOS Supabase project required for final deployed verification |
| RBAC | DEVELOPING | N/A | FOUNDATION | HARDENED SCOPE HELPERS + ROLE-ASSIGNMENT GUARDS + SCOPE-AWARE RLS | DEVELOPING | POSTGRES RBAC/RLS CI PASS | Real Supabase Auth/JWT/RLS + advisors still pending |
| Design System | DEVELOPING | DEFINED + 47 SVG SPECS | IMPLEMENTING | N/A | N/A | VISUAL + CI REVIEW | Remaining mobile platform/runtime integration pending |
| Authentication | DEVELOPING | LOGIN DESIGNED | PREVIEW IMPLEMENTED | NOT CONNECTED | N/A | FLUTTER VERIFIED | Real Supabase auth pending |
| Organization / Factory Setup | DEVELOPING | FOUNDATION | FOUNDATION | CORE + SCOPE-AWARE STRUCTURAL RLS | DEVELOPING | POSTGRES CI PASS | Live Supabase deployment pending |
| Admin Dashboard | DEVELOPING | DESIGNED | IMPLEMENTED | REPOSITORY INTERFACE | PREVIEW ADAPTER | ANALYZE + WIDGET TEST PASS | Real aggregate repository pending |
| Employee Mobile Home | DEVELOPING | DESIGNED | IMPLEMENTED + NOTIFICATION ENTRY | NOT CONNECTED | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Driver Mobile Home | DEVELOPING | DRIVER + DELIVERY DESIGNED | TRIP/FUEL/DELIVERY/NOTIFICATION NAVIGATION IMPLEMENTED | FLEET + DELIVERY SELF-SERVICE FOUNDATION | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Inventory | DEVELOPING | DASHBOARD + SCANNER + ITEM DETAIL | DASHBOARD + ITEM DETAIL IMPLEMENTED | INVENTORY LEDGER + SCOPE-HARDENED CHILD RLS | DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Real Supabase repository/RPC tests pending |
| Scanner | DEVELOPING | DESIGNED | MANUAL FLOW IMPLEMENTED | PORT ABSTRACTION | PREVIEW LOOKUP | UNIT + NAVIGATION PASS | Camera/barcode platform integration pending |
| Production | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PRODUCTION/QUALITY SCHEMA + PARENT-SCOPED CHILD RLS | DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Real Supabase repository/RPC tests pending |
| Quality | DEVELOPING | INCLUDED IN PRODUCTION | QC STATE IMPLEMENTED | SCHEMA + PARENT-SCOPED PARAMETER RLS | DEMO | NAVIGATION + POSTGRES SCHEMA PASS | Deployed Supabase RLS/RPC tests pending |
| Warehouse | DEVELOPING | DASHBOARD | IMPLEMENTED | PREVIEW REPOSITORY ONLY | PREVIEW | NAVIGATION PASS | Transactional warehouse schema/actions pending |
| Dispatch | DEVELOPING | DASHBOARD | DASHBOARD + DELIVERY HANDOFF | PREVIEW REPOSITORY ONLY | PREVIEW | NAVIGATION PASS | Full dispatch transactional schema/actions pending |
| Purchase | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PURCHASE + GRN SCHEMA + FACTORY-SCOPED CHILD RLS | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Live receipt RPC/RLS verification pending |
| HR | DEVELOPING | DASHBOARD + EMPLOYEE + ATTENDANCE/LEAVE + HOLIDAYS | IMPLEMENTED | HR SCHEMA + EMPLOYEE-PARENT SCOPE HARDENING | 40-EMPLOYEE DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase self-service/manager RLS and commands pending |
| Sales | DEVELOPING | DASHBOARD + CUSTOMER + ORDER + PAYMENT/DELIVERY | IMPLEMENTED | CUSTOMER/ORDER/PAYMENT SCHEMA + ORDER-PARENT CHILD RLS | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Live payment commands + full Dispatch integration pending |
| Vehicles / Drivers | DEVELOPING | FLEET + VEHICLE + DRIVER | IMPLEMENTED | FLEET/ASSIGNMENT/DRIVER PROFILE SCHEMA + TABLE-SAFE REF TRIGGERS | 10 VEHICLES + 10 HR-LINKED DRIVERS | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase assignment/RPC tests pending |
| Trips / Fuel | DEVELOPING | TRIP + FUEL | IMPLEMENTED | TRIP/INSPECTION/FUEL SCHEMA + COMMAND RPCs | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase driver/fuel command tests pending |
| Delivery | DEVELOPING | DASHBOARD + DETAIL/POD + DRIVER + EXCEPTION/RETURN | IMPLEMENTED | DELIVERY/POD/EXCEPTION/EVENT SCHEMA + DRIVER RPCs + PARENT-SCOPED RLS + TABLE-SAFE TRIGGERS | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Real Supabase RPC/POD storage tests pending |
| Maintenance | DEVELOPING | 6 SVG DESIGNS | DASHBOARD + ASSET + WORK ORDER + PM + BREAKDOWN/SPARES + REPORTS IMPLEMENTED | SCHEMA + RLS + LIFECYCLE COMMAND RPCs | FICTIONAL ASSET/ORDER/SPARE SEED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase RPC tests and live repositories pending |
| Reporting / Analytics | DEVELOPING | 6 SVG DESIGNS | REPORTS CENTER + EXECUTIVE + OPERATIONS + COMMERCIAL + WORKFORCE/FLEET + BUILDER IMPLEMENTED | TYPED REPOSITORY/DOMAIN FOUNDATION; EXISTING `report.read` ACCESS MODEL | FICTIONAL CROSS-MODULE PREVIEW | ANALYZE + REGRESSION PASS | Live Supabase aggregates/views and real PDF/CSV/Excel generation pending |
| Notifications | DEVELOPING | 4 SVG DESIGNS | ADMIN CENTER + RULES + EMPLOYEE/DRIVER INBOX + PREFERENCES IMPLEMENTED | NOTIFICATION/RULE/TOKEN/PREFERENCE/RECIPIENT/DELIVERY-ATTEMPT SCHEMA + MARK-READ RPC + PUSH PORT | FICTIONAL RULES/EVENTS | FLUTTER 53 TESTS + POSTGRES SCHEMA/SEED PASS | Real Supabase execution, trusted dispatcher and Firebase/FCM platform setup pending |
| Audit / Security | DEVELOPING | N/A | N/A | EXPLICIT SCOPE HELPERS + ROLE-SCOPE VALIDATION + MODULE RLS HARDENING + DB CI | N/A | POSTGRES SCHEMA/SEED/RBAC-RLS GATE PASS | Dedicated Supabase advisors, Auth/RLS/RPC and storage-policy validation pending |
| Full E2E QA | NOT STARTED | N/A | N/A | N/A | N/A | NOT STARTED | Requires deployed workflows |

See [Maintenance checkpoint](MAINTENANCE_PROGRESS.md), [Reporting checkpoint](REPORTING_PROGRESS.md), [Notifications checkpoint](NOTIFICATIONS_PROGRESS.md) and [Security checkpoint](SECURITY_PROGRESS.md) for verified repository milestones and remaining production gates.

## Landed in repository

- Initialized repository architecture, RBAC/tenancy, business-flow and design-system documentation.
- Added declarative PostgreSQL foundation for organizations, factories, memberships, roles, permissions, modules and audit records.
- Added explicit `has_any_permission`, `has_org_permission`, `has_factory_permission`, `has_warehouse_permission`, `has_department_permission` and scope-aware structural visibility helpers.
- Hardened compatibility `has_permission(..., NULL)` so NULL means organization-wide authority instead of any narrower role assignment.
- Added `user_roles` assignment-integrity validation for tenant/factory/warehouse/department relationships and invalid mixed scopes.
- Hardened core factory/warehouse/department visibility and self/admin membership/role-assignment visibility.
- Added module RLS hardening so Inventory, Production, Purchase, HR, Sales, Fleet, Delivery and Notification child/master policies resolve the correct parent or explicit scope rather than widening NULL checks.
- Added immutable Inventory ledger with posting rules, derived balances and review hardening.
- Added Production/Quality orders, batches, material-consumption/output links and QC foundation.
- Added Purchase suppliers, purchase orders, GRNs and receipt-to-ledger linkage.
- Added HR employees, isolated private data, attendance, leave and holidays.
- Added Sales customers, addresses, orders, order lines, payments and derived financials.
- Added Fleet vehicles, HR-linked driver profiles, assignments, trips, inspections and fuel records plus driver/fuel command RPCs.
- Added Delivery records, lines, POD, exceptions, events, assigned-driver commands, anti-overship checks and `customer_return` ledger validation.
- Added Maintenance assets, preventive schedules, work orders, spare requirements, events, factory-scoped RLS and lifecycle command RPCs.
- Maintenance spare consumption remains Inventory-ledger controlled and preventive work-order creation remains idempotent per plan occurrence.
- Added system-wide Reporting domain/repository foundation and six Reporting surfaces while preserving the existing `report.read` permission.
- Added Notifications domain/repository foundation, four notification surfaces and repo-only Notifications schema for templates, rules, tokens, preferences, recipients/read state and delivery-attempt auditing.
- Added a replaceable notification push boundary; preview mode explicitly reports push unsupported and contains no Firebase credentials/fake delivery behavior.
- Added **47 design-first SVG specifications** through Notification Rules / Templates.
- Flutter application includes Login, Admin, Employee/Driver Home, Inventory, Production, Warehouse, Dispatch, Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications surfaces.
- Added `.github/workflows/factoryos_db_ci.yml`: PostgreSQL 16 now applies the complete schema chain, all fictional seeds and RBAC/RLS assertions on relevant repository changes.
- Added CI-only Supabase `auth.uid()` compatibility bootstrap and executable scope-security assertions; this is test infrastructure, not a production Auth replacement.
- Database CI exposed and fixed three previously hidden SQL defects: Fleet generic trigger `NEW.trip_id`, invalid Fleet review-seed UPDATE syntax, and Delivery generic trigger `NEW.delivery_line_id`.
- Added table-safe Fleet and Delivery trigger hardening migrations and made the Fleet review seed executable in PostgreSQL.

## Verified repository-level behavior

- GitHub repository/branch/PR writes are confirmed through the connected GitHub account.
- `janseva-production` has not been modified for FactoryOS.
- Flutter 3.47.7 CI passes `flutter analyze --fatal-infos` and the complete app regression suite remains **53/53 passing tests** on the accepted security code head.
- PostgreSQL 16 Database CI successfully applies the complete current schema/review/command chain and all current fictional demo seeds in dependency order.
- Database security assertions execute as the `authenticated` role and verify organization/factory/warehouse/department scope semantics, no upward escalation, cross-scope/tenant denial, suspended-membership denial and malformed assignment rejection.
- Factory-scoped manager tests verify only PLANT-01 structural visibility, self-only non-admin membership/role enumeration, denial of organization-module mutation, and legitimate scoped child-row access across Inventory, Production, Purchase, Sales and Delivery.
- Warehouse-scoped tests verify exact RM-WH access without sibling-warehouse escalation; department-scoped tests verify exact PROD access without sibling-department escalation.
- Company Owner test verifies DKIM factory visibility without access to the synthetic second tenant.
- Notifications Flutter journeys remain tested for Admin, Employee and Driver surfaces; Reporting and all previously accepted module navigation/domain coverage remains green.
- Maintenance, Delivery, Fleet, Sales, HR, Purchase, Production and Inventory calculation/flow regression coverage remains green.

## Not yet verified / production blockers

- FactoryOS schemas have **not** been executed against a dedicated FactoryOS Supabase project.
- Local PostgreSQL schema/seed/RBAC-RLS execution is verified, but real Supabase Auth/JWT behavior, Data API behavior and deployed RLS/RPC isolation remain pending.
- Supabase security/performance advisors have not been run for FactoryOS.
- Storage/object policies for POD/media are not deployed or tested.
- Real authentication is not connected; current login remains a preview implementation.
- Operational, Reporting and Notification repositories remain replaceable preview adapters until dedicated Supabase is connected.
- Inventory posting, Production completion, Fleet, Delivery, Maintenance and Notification command functions still require deployed Supabase execution tests under real role/JWT contexts.
- Reporting does not yet use live SQL views/query functions/materialized aggregates; real PDF/CSV/Excel files are not generated yet.
- Notifications have no connected Firebase project, no real FCM token lifecycle, no Android/iOS/web configuration and no trusted server-side dispatcher/retry worker.
- Warehouse and Dispatch full transactional schemas/actions are still missing; therefore Dispatch → Trip → Delivery → Return → Warehouse is not yet production-complete end to end.
- Purchase/HR/Sales/Fleet/Delivery/Maintenance mutation controls are not connected to live repositories.
- POD object storage and scanner camera runtime integrations are pending.
- Full E2E QA requires deployed workflows.

## Pending dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization/cost confirmation**; never reuse `janseva-production`.
2. Apply schemas in verified dependency order: core → RBAC scope hardening → Inventory + review fixes → Production/Quality + review fixes → Purchase → HR + review fixes → Sales → Fleet + review fixes + commands + trigger hardening → Delivery + review fixes + trigger hardening → Maintenance + security + commands → Notifications + module-scope hardening → demo seeds.
3. Run deployed cross-tenant/RLS tests, command/RPC integrity tests, notification scope/token tests, ledger/report-scope tests and Supabase security/performance advisors.
4. Replace preview Auth/repositories with Supabase-backed implementations and connect mutation actions.
5. Add trusted notification dispatch plus real FCM Android/iOS/web registration, foreground/background handling, retry and delivery auditing.
6. Add authorized Reporting SQL views/query functions/repositories and real server-side PDF/CSV/Excel generation/audit rules.
7. Add Warehouse/Dispatch transactional backends and verify the full Dispatch → Trip → Delivery → Return → Warehouse flow.
8. Add Android/iOS camera/barcode/POD capture setup and permissions, then run full production E2E QA.

## Rule

Statuses describe verified repository/database reality. A design, schema file, passing Flutter screen or local PostgreSQL test alone is not a production-complete module. Final production security requires a dedicated deployed FactoryOS Supabase environment and real Auth/RLS/RPC/E2E verification.
