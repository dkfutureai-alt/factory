# FactoryOS Work Log

Last updated: 2026-10-15

| Area | Status | UI Design | Frontend | Backend | Seed Data | Testing | Known Issues |
|---|---|---:|---:|---:|---:|---:|---|
| Phase 0 Repository Audit | COMPLETE | N/A | N/A | N/A | N/A | VERIFIED | Repository was empty at start |
| System Architecture | DEVELOPING | N/A | FOUNDATION | PREVIEW/LIVE SERVICE GRAPH + POSTGRES FOUNDATION | DEVELOPING | FLUTTER + POSTGRES CI | Dedicated backend deployment pending |
| Multi-tenancy | DEVELOPING | N/A | FOUNDATION | EXPLICIT ORG/FACTORY/WAREHOUSE/DEPARTMENT SCOPE FOUNDATION | DEVELOPING | POSTGRES CROSS-SCOPE TESTS PASS | Dedicated FactoryOS Supabase project required for final deployed verification |
| RBAC | DEVELOPING | N/A | FOUNDATION | HARDENED SCOPE HELPERS + ROLE-ASSIGNMENT GUARDS + SCOPE-AWARE RLS | DEVELOPING | POSTGRES RBAC/RLS CI PASS | Real Supabase Auth/JWT/RLS + advisors still pending |
| Design System | DEVELOPING | DEFINED + 50 SVG SPECS | IMPLEMENTING | N/A | N/A | VISUAL + CI REVIEW | Remaining mobile platform/runtime integration pending |
| Authentication | DEVELOPING | LOGIN + SUPABASE-READY LOGIN DESIGNED | REPOSITORY-DRIVEN LOGIN + SESSION STARTUP IMPLEMENTED | PREVIEW + SUPABASE AUTH ADAPTER | N/A | CONFIG/AUTH UNIT + FULL FLUTTER PASS | Dedicated Supabase project/users not connected yet |
| Organization / Factory Setup | DEVELOPING | FOUNDATION | FOUNDATION | CORE + SCOPE-AWARE STRUCTURAL RLS | DEVELOPING | POSTGRES CI PASS | Live Supabase deployment pending |
| Admin Dashboard | DEVELOPING | DESIGNED | IMPLEMENTED | REPOSITORY INTERFACE | PREVIEW ADAPTER | ANALYZE + WIDGET TEST PASS | Real aggregate repository pending |
| Employee Mobile Home | DEVELOPING | DESIGNED | IMPLEMENTED + NOTIFICATION ENTRY | NOT CONNECTED | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Driver Mobile Home | DEVELOPING | DRIVER + DELIVERY DESIGNED | TRIP/FUEL/DELIVERY/NOTIFICATION NAVIGATION IMPLEMENTED | FLEET + DELIVERY SELF-SERVICE FOUNDATION | PREVIEW UI | ANALYZE + MOBILE NAVIGATION PASS | Real auth/repository commands pending |
| Inventory | DEVELOPING | DASHBOARD + SCANNER + ITEM DETAIL | DASHBOARD + ITEM DETAIL IMPLEMENTED | INVENTORY LEDGER + SCOPE-HARDENED CHILD RLS + WAREHOUSE-SCOPED POSTING | DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE/POST PASS | General live Supabase repository/RPC verification pending |
| Scanner | DEVELOPING | DESIGNED | MANUAL FLOW IMPLEMENTED | PORT ABSTRACTION | PREVIEW LOOKUP | UNIT + NAVIGATION PASS | Camera/barcode platform integration pending |
| Production | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PRODUCTION/QUALITY SCHEMA + PARENT-SCOPED CHILD RLS | DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Real Supabase repository/RPC tests pending |
| Quality | DEVELOPING | INCLUDED IN PRODUCTION | QC STATE IMPLEMENTED | SCHEMA + PARENT-SCOPED PARAMETER RLS | DEMO | NAVIGATION + POSTGRES SCHEMA PASS | Deployed Supabase RLS/RPC tests pending |
| Warehouse | DEVELOPING | DASHBOARD + TRANSFER DETAIL | DASHBOARD + TRANSFER DETAIL + LIVE COMMAND STATE | TRANSFER/LINES SCHEMA + WAREHOUSE RLS + ATOMIC TRANSFER RPC + SUPABASE REPOSITORY ADAPTER | FICTIONAL STAGING + TRF-2026-00218 | FLUTTER LIVE-COMMAND UI + POSTGRES COMMAND/IDEMPOTENCY PASS | Adapter still unverified against deployed Supabase |
| Dispatch | DEVELOPING | DASHBOARD + LOAD DETAIL | DASHBOARD + LOAD DETAIL + LIVE STOCK/FINALIZE COMMAND STATE + DELIVERY HANDOFF | DISPATCH SCHEMA + SALES_DISPATCH LEDGER + FINALIZE/HANDOFF RPCs + SUPABASE REPOSITORY ADAPTER + FULL-LOAD GUARD | FICTIONAL DSP-2026-00417 + POSTED LEDGER | FLUTTER LIVE-COMMAND UI + POSTGRES CHECK/LEDGER/HANDOFF/IDEMPOTENCY/PARTIAL-LOAD PASS | Adapter still unverified against deployed Supabase |
| Purchase | DEVELOPING | DASHBOARD + ORDER DETAIL | IMPLEMENTED | PURCHASE + GRN SCHEMA + FACTORY-SCOPED CHILD RLS | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED/SCOPE PASS | Live receipt repository/RPC verification pending |
| HR | DEVELOPING | DASHBOARD + EMPLOYEE + ATTENDANCE/LEAVE + HOLIDAYS | IMPLEMENTED | HR SCHEMA + EMPLOYEE-PARENT SCOPE HARDENING | 40-EMPLOYEE DEMO | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase self-service/manager RLS and commands pending |
| Sales | DEVELOPING | DASHBOARD + CUSTOMER + ORDER + PAYMENT/DELIVERY | IMPLEMENTED | CUSTOMER/ORDER/PAYMENT SCHEMA + ORDER-PARENT CHILD RLS + DISPATCH STATUS HANDOFF | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES DISPATCH HANDOFF PASS | Live payment commands/repository pending |
| Vehicles / Drivers | DEVELOPING | FLEET + VEHICLE + DRIVER | IMPLEMENTED | FLEET/ASSIGNMENT/DRIVER PROFILE SCHEMA + TABLE-SAFE REF TRIGGERS | 10 VEHICLES + 10 HR-LINKED DRIVERS | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase assignment/RPC tests pending |
| Trips / Fuel | DEVELOPING | TRIP + FUEL | IMPLEMENTED | TRIP/INSPECTION/FUEL SCHEMA + COMMAND RPCs + DISPATCH READY HANDOFF | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES DISPATCH/TRIP HANDOFF PASS | Real Supabase driver/fuel command tests pending |
| Delivery | DEVELOPING | DASHBOARD + DETAIL/POD + DRIVER + EXCEPTION/RETURN | IMPLEMENTED | DELIVERY/POD/EXCEPTION/EVENT SCHEMA + DRIVER RPCs + PARENT-SCOPED RLS + TABLE-SAFE TRIGGERS + DISPATCH CREATE/REUSE HANDOFF | DEMO SEEDED | FLUTTER DOMAIN/NAV + POSTGRES DISPATCH→DELIVERY HANDOFF PASS | Real Supabase RPC/POD storage and return E2E tests pending |
| Maintenance | DEVELOPING | 6 SVG DESIGNS | DASHBOARD + ASSET + WORK ORDER + PM + BREAKDOWN/SPARES + REPORTS IMPLEMENTED | SCHEMA + RLS + LIFECYCLE COMMAND RPCs | FICTIONAL ASSET/ORDER/SPARE SEED | FLUTTER DOMAIN/NAV + POSTGRES SCHEMA/SEED PASS | Real Supabase RPC tests and live repositories pending |
| Reporting / Analytics | DEVELOPING | 6 SVG DESIGNS | REPORTS CENTER + EXECUTIVE + OPERATIONS + COMMERCIAL + WORKFORCE/FLEET + BUILDER IMPLEMENTED | TYPED REPOSITORY/DOMAIN FOUNDATION; EXISTING `report.read` ACCESS MODEL | FICTIONAL CROSS-MODULE PREVIEW | ANALYZE + REGRESSION PASS | Live Supabase aggregates/views and real PDF/CSV/Excel generation pending |
| Notifications | DEVELOPING | 4 SVG DESIGNS | ADMIN CENTER + RULES + EMPLOYEE/DRIVER INBOX + PREFERENCES IMPLEMENTED | NOTIFICATION/RULE/TOKEN/PREFERENCE/RECIPIENT/DELIVERY-ATTEMPT SCHEMA + MARK-READ RPC + PUSH PORT + READ-MEMBERSHIP GUARD | FICTIONAL RULES/EVENTS | NOTIFICATION SECURITY + FULL FLUTTER 66 PASS; POSTGRES SCHEMA/SEED PASS | Real Supabase execution, trusted dispatcher and Firebase/FCM platform setup pending |
| Audit / Security | DEVELOPING | N/A | N/A | EXPLICIT SCOPE HELPERS + ROLE-SCOPE VALIDATION + MODULE RLS HARDENING + FAIL-FAST/ISOLATED DB CI | N/A | POSTGRES RBAC-RLS + NOTIFICATIONS + WAREHOUSE/DISPATCH/PARTIAL-LOAD GATES PASS | Dedicated Supabase advisors, Auth/RLS/RPC and storage-policy validation pending |
| Full E2E QA | NOT STARTED | N/A | N/A | N/A | N/A | NOT STARTED | Requires deployed workflows |

See [Maintenance checkpoint](MAINTENANCE_PROGRESS.md), [Reporting checkpoint](REPORTING_PROGRESS.md), [Notifications checkpoint](NOTIFICATIONS_PROGRESS.md), [Security checkpoint](SECURITY_PROGRESS.md), [Warehouse/Dispatch checkpoint](WAREHOUSE_DISPATCH_PROGRESS.md) and [Supabase integration readiness checkpoint](SUPABASE_INTEGRATION_READINESS.md) for verified repository milestones and remaining production gates.

## Landed in repository

- Initialized repository architecture, RBAC/tenancy, business-flow and design-system documentation.
- Added declarative PostgreSQL foundation for organizations, factories, memberships, roles, permissions, modules and audit records.
- Added explicit `has_any_permission`, `has_org_permission`, `has_factory_permission`, `has_warehouse_permission`, `has_department_permission` and scope-aware structural visibility helpers.
- Hardened compatibility `has_permission(..., NULL)` so NULL means organization-wide authority instead of any narrower role assignment.
- Added `user_roles` assignment-integrity validation for tenant/factory/warehouse/department relationships and invalid mixed scopes.
- Hardened core factory/warehouse/department visibility and self/admin membership/role-assignment visibility.
- Added module RLS hardening so Inventory, Production, Purchase, HR, Sales, Fleet, Delivery and Notification child/master policies resolve the correct parent or explicit scope rather than widening NULL checks.
- Added immutable Inventory ledger with posting rules, derived balances and review hardening.
- Extended Inventory posting for legitimate warehouse-scoped operators only when every ledger line remains inside an authorized warehouse.
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
- Added Notification read-membership hardening and executable notification-security regression coverage.
- Added Warehouse transfer schema/RLS and `complete_warehouse_transfer`, which atomically posts idempotent `transfer_out` + `transfer_in` ledger transactions before completion.
- Added Dispatch orders/lines/checks/events, immutable posted-line protection, `post_dispatch_stock` and `finalize_dispatch` command RPCs.
- Dispatch finalization requires fully loaded quantities, exact posted `sales_dispatch` ledger reconciliation, complete required checks and a valid same-order Trip before creating/reusing Delivery and advancing Trip/Sales states.
- Added `11d_dispatch_full_load_guard.sql` so stock cannot post while any dispatch line remains partially loaded; partial posting leaves no ledger side effects.
- Added fictional staging locations, `TRF-2026-00218` and ledger-backed `DSP-2026-00417` aligned with Flutter previews.
- Added Warehouse Transfer Detail and Dispatch Load Detail surfaces plus Dispatch → Delivery navigation.
- Added explicit backend configuration and preview/Supabase service composition using `FACTORYOS_BACKEND`, `FACTORYOS_SUPABASE_URL` and `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`.
- Added `supabase_flutter` client dependency, Supabase Auth repository and safe startup/session bootstrap with no service-role key in the client.
- Added Supabase Warehouse and Dispatch repository adapters. Live stock-changing UI calls only verified RPCs; preview repositories remain mutation-disabled.
- Added connected-backend Login design and **50 design-first SVG specifications** total.
- Flutter application includes Login, Admin, Employee/Driver Home, Inventory, Production, Warehouse, Dispatch, Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications surfaces.
- `.github/workflows/factoryos_db_ci.yml` applies the complete schema chain, all fictional seeds, RBAC/RLS, Notifications security, Warehouse/Dispatch command and Dispatch partial-load assertions.
- Added CI-only Supabase `auth.uid()` compatibility bootstrap and executable scope-security assertions; this is test infrastructure, not a production Auth replacement.
- Database CI exposed and fixed earlier Fleet/Delivery SQL defects plus Warehouse/Dispatch idempotency/PLpgSQL issues during real execution.
- Hardened the PostgreSQL assertion harness so boolean failures produce SQL errors under `ON_ERROR_STOP=1`.
- Isolated the Notifications suspension test so it restores RBAC fixture state instead of contaminating later command suites.

## Verified repository-level behavior

- GitHub repository/branch/PR writes are confirmed through the connected GitHub account.
- `janseva-production` has not been modified for FactoryOS.
- Flutter 3.47.7 CI passes `flutter analyze --fatal-infos` and the complete app regression suite is **66/66 passing tests** on Supabase-readiness code head `f54b647599a692361c75a95a619d401d7e7c760e`.
- Backend config tests verify preview defaults, required Supabase URL/key inputs and HTTPS enforcement outside local development.
- Preview Auth tests verify normalized preview sessions and validation failure behavior.
- Live-command widget tests verify Warehouse completion and Dispatch full-load → stock-post → finalize sequencing through repository boundaries without external credentials.
- Warehouse Dashboard → transfer detail and Dispatch Dashboard → load detail → Delivery detail regression journeys remain green.
- PostgreSQL 16 Database CI run `38687917334` applies the complete current schema/review/command chain and all fictional demo seeds in dependency order.
- Database security assertions execute as `authenticated` and verify organization/factory/warehouse/department scope semantics, no upward escalation, cross-scope/tenant denial, suspended-membership denial and malformed assignment rejection.
- Notifications security assertions verify self-only recipient visibility/read mutation, foreign denial and suspended-member denial, then restore deterministic fixture state.
- Warehouse command tests prove an RM-WH-scoped manager can complete the authorized transfer without factory-level escalation; the posted transfer pair is quantity-neutral and idempotent.
- Dispatch command tests prove `sales_dispatch` posting, required-check blocking, exact ledger linkage, Trip/Delivery/Sales handoff and replay idempotency.
- Dispatch partial-load guard tests prove planned 10 / loaded 5 cannot post stock and leave no stock transaction or ledger linkage.
- Notifications, Reporting, Maintenance, Delivery, Fleet, Sales, HR, Purchase, Production and Inventory previously accepted regression coverage remains green.

## Not yet verified / production blockers

- FactoryOS schemas have **not** been executed against a dedicated FactoryOS Supabase project.
- Local PostgreSQL schema/seed/RBAC-RLS/transaction execution is verified, but real Supabase Auth/JWT behavior, Data API behavior and deployed RLS/RPC isolation remain pending.
- Supabase security/performance advisors have not been run for FactoryOS.
- Storage/object policies for POD/media are not deployed or tested.
- The Supabase Auth adapter and startup session path are implemented, but no dedicated FactoryOS project/users are connected yet.
- Warehouse and Dispatch Supabase adapters are implemented but not yet exercised against deployed FactoryOS RLS/RPCs.
- Other operational, Reporting and Notification repositories remain replaceable preview adapters until their live migrations are implemented.
- Inventory posting, Production completion, Fleet, Delivery, Maintenance and Notification command functions still require deployed Supabase execution tests under real role/JWT contexts.
- Reporting does not yet use live SQL views/query functions/materialized aggregates; real PDF/CSV/Excel files are not generated yet.
- Notifications have no connected Firebase project, no real FCM token lifecycle, no Android/iOS/web configuration and no trusted server-side dispatcher/retry worker.
- Forward Dispatch → Trip → Delivery is repository/local-database verified, but Delivery return → approved `customer_return` → Warehouse receipt still requires deployed full E2E verification.
- Purchase/HR/Sales/Fleet/Delivery/Maintenance mutation controls are not connected to live repositories.
- POD object storage and scanner camera runtime integrations are pending.
- Full E2E QA requires deployed workflows.

## Pending dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization/cost confirmation**; never reuse `janseva-production`.
2. Apply the PostgreSQL-verified schema chain in dependency order through Notifications and Warehouse/Dispatch review guards, then apply fictional demo data only where appropriate for the dedicated test environment.
3. Provision controlled FactoryOS test users/memberships/roles and run deployed Auth/JWT/Data API/RLS/RPC/cross-tenant tests plus Supabase security/performance advisors.
4. Exercise the implemented Supabase Auth, Warehouse and Dispatch adapters against the deployed environment and fix any API/RLS mismatch.
5. Migrate remaining preview operational repositories module-by-module to Supabase, preserving existing command/RBAC/ledger rules.
6. Verify the complete deployed Dispatch → Trip → Delivery → Return → Warehouse flow.
7. Add trusted notification dispatch plus real FCM Android/iOS/web registration, foreground/background handling, retry and delivery auditing.
8. Add authorized Reporting SQL views/query functions/repositories and real server-side PDF/CSV/Excel generation/audit rules.
9. Add Android/iOS camera/barcode/POD capture setup and permissions, then run full production E2E QA.

## Rule

Statuses describe verified repository/database reality. A design, schema file, passing Flutter screen or local PostgreSQL test alone is not a production-complete module. Final production security and operational acceptance require a dedicated deployed FactoryOS Supabase environment and real Auth/RLS/RPC/E2E verification.
