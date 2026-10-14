# FactoryOS Work Log

Last updated: 2026-10-14

| Area | Status | UI Design | Frontend | Backend | Seed Data | Testing | Known Issues |
|---|---|---:|---:|---:|---:|---:|---|
| Phase 0 Repository Audit | COMPLETE | N/A | N/A | N/A | N/A | VERIFIED | Repository was empty at start |
| System Architecture | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | PARTIAL | Dedicated backend deployment pending |
| Multi-tenancy | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | Dedicated FactoryOS Supabase project required |
| RBAC | DEVELOPING | N/A | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | RLS/role tests require real FactoryOS project |
| Design System | DEVELOPING | DEFINED + 22 SVG SPECS | IMPLEMENTING | N/A | N/A | VISUAL + CI REVIEW | More module screens pending |
| Authentication | DEVELOPING | LOGIN DESIGNED | PREVIEW IMPLEMENTED | NOT CONNECTED | N/A | FLUTTER VERIFIED | Real Supabase auth pending |
| Organization / Factory Setup | DEVELOPING | FOUNDATION | FOUNDATION | DEVELOPING | DEVELOPING | NOT DEPLOYED | Core schema exists in repo only |
| Admin Dashboard | DEVELOPING | DESIGNED | IMPLEMENTED | REPOSITORY INTERFACE | PREVIEW ADAPTER | ANALYZE + WIDGET TEST PASS | Real aggregate repository pending |
| Employee Mobile Home | DEVELOPING | DESIGNED | IMPLEMENTED | NOT CONNECTED | PREVIEW UI | ANALYZE + NAVIGATION TEST PASS | Real self-service attendance/leave commands pending |
| Driver Mobile Home | DEVELOPING | DESIGNED | IMPLEMENTED | NOT CONNECTED | PREVIEW UI | ANALYZE PASS | Trip/vehicle backend pending |
| Inventory | DEVELOPING | DASHBOARD + SCANNER + ITEM DETAIL DESIGNED | DASHBOARD + ITEM DETAIL IMPLEMENTED | INVENTORY SCHEMA IMPLEMENTED | DEVELOPING | ANALYZE + DOMAIN + NAVIGATION PASS | Real Supabase repository / DB tests pending |
| Scanner | DEVELOPING | DESIGNED | MANUAL FLOW IMPLEMENTED | PORT ABSTRACTION | PREVIEW LOOKUP | UNIT + NAVIGATION PASS | Camera/barcode plugin + platform permissions pending |
| Production | DEVELOPING | DASHBOARD + ORDER DETAIL DESIGNED | DASHBOARD + ORDER DETAIL IMPLEMENTED | PRODUCTION/QUALITY SCHEMA IMPLEMENTED | DEVELOPING | ANALYZE + DOMAIN + NAVIGATION PASS | Real Supabase repository / DB tests pending |
| Quality | DEVELOPING | INCLUDED IN PRODUCTION FLOW | ORDER DETAIL QC STATE IMPLEMENTED | SCHEMA IMPLEMENTED | DEVELOPING | UI NAVIGATION + MANUAL SCHEMA REVIEW | DB execution/RLS tests pending |
| Warehouse | DEVELOPING | DASHBOARD DESIGNED | DASHBOARD IMPLEMENTED | PREVIEW REPOSITORY ONLY | PREVIEW DATA | ANALYZE + NAVIGATION PASS | Operational warehouse schema/actions pending |
| Dispatch | DEVELOPING | DASHBOARD DESIGNED | DASHBOARD IMPLEMENTED | PREVIEW REPOSITORY ONLY | PREVIEW DATA | ANALYZE + NAVIGATION PASS | Dispatch workflow schema/actions pending |
| Purchase | DEVELOPING | DASHBOARD + ORDER DETAIL DESIGNED | DASHBOARD + ORDER DETAIL IMPLEMENTED | PURCHASE + GRN SCHEMA IMPLEMENTED | DEMO SEEDED | ANALYZE + DOMAIN + NAVIGATION PASS | Real Supabase execution/RLS/receipt RPC tests pending; create/receipt buttons preview-only |
| HR | DEVELOPING | DASHBOARD + EMPLOYEE + ATTENDANCE/LEAVE + HOLIDAYS DESIGNED | IMPLEMENTED | HR/ATTENDANCE/LEAVE/HOLIDAY SCHEMA IMPLEMENTED | 40-EMPLOYEE DEMO SEEDED | ANALYZE + DOMAIN + NAVIGATION PASS | Real DB/RLS tests and transactional approval/self-service commands pending |
| Sales | DEVELOPING | DASHBOARD + CUSTOMER + ORDER + PAYMENT/DELIVERY DESIGNED | IMPLEMENTED | CUSTOMER/SALES ORDER/PAYMENT SCHEMA IMPLEMENTED | DEMO SEEDED | ANALYZE + DOMAIN + NAVIGATION PASS | Real Supabase execution/RLS/credit/payment commands and Dispatch/Trip integration pending |
| Vehicles / Drivers | DEVELOPING | DRIVER HOME DESIGNED | DRIVER HOME IMPLEMENTED | NOT STARTED | NOT STARTED | FLUTTER ANALYZE PASS | Fleet workflow schema pending |
| Trips / Fuel | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | — |
| Delivery | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | — |
| Maintenance | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | — |
| Reporting | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | PARTIAL HISTORY | NOT STARTED | More historical data required |
| Notifications | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | NOT STARTED | FCM later |
| Audit / Security | DEVELOPING | N/A | NOT STARTED | FOUNDATION + HR PRIVATE-DATA ISOLATION + SALES REFERENCE VALIDATION | NOT STARTED | MANUAL REVIEW | Supabase advisors/RLS tests pending |
| Full E2E QA | NOT STARTED | N/A | N/A | N/A | N/A | NOT STARTED | Requires deployed workflows |

## Completed / landed in repository

- Confirmed repository began completely empty and initialized project source of truth.
- Created and maintained `factoryos-foundation` branch and PR #1.
- Added architecture, RBAC/tenancy, business-flow and design-system documentation.
- Added declarative core PostgreSQL/Supabase schema for organizations, factories, memberships, roles, permissions, modules and audit foundation.
- Added inventory ledger schema with items, categories, units, batches, serials, stock transactions, immutable posted movements and derived inventory balances.
- Added production and quality schema with lines, orders, material requirements, production batches, material-consumption links, outputs and QC records.
- Added Purchase schema with suppliers, purchase orders, PO lines, goods receipts, GRN lines, RLS policies, tenant/reference validation and receipt-to-ledger linkage rules.
- Added HR schema with shifts, employees, isolated private HR details, attendance, attendance corrections, leave types/balances/requests and holidays.
- Added HR review fixes for nullable linked-user uniqueness, strict tenant/factory/department/shift/manager reference integrity, leave-type scope, attendance-correction scope and leave-balance allocation limits.
- Added Sales schema with customers, business contacts, delivery addresses, sales orders/lines, customer payments, derived order financials, RLS policies and tenant/reference validation.
- Sales order lines are protected from mutation after confirmation; received payments cannot be deleted and must be reversed instead.
- Added realistic fictional demo organization/factory/warehouse/item/stock/production/QC/Purchase/HR/Sales data.
- HR demo contains 40 fictional active employees, attendance snapshot, leave balances/requests and holiday calendar. Protected employee contact/banking fields are intentionally not seeded.
- Sales demo contains fictional customers, delivery addresses, orders, order lines and payment records. Seed ordering preserves the line-immutability rule by creating draft orders, inserting lines, then finalizing lifecycle status.
- Added 22 SVG design specifications through Sales Dashboard, Customer Detail, Sales Order Detail and Payment & Delivery Tracking.
- Added Flutter application foundation with centralized theme and repository-driven screens.
- Implemented login preview, admin dashboard, employee home, driver home, Inventory dashboard, Inventory Item Detail, Production dashboard, Production Order Detail, Warehouse dashboard, Dispatch dashboard, Purchase dashboard, Purchase Order Detail, HR dashboard, Employee Detail, Attendance & Leave, Holiday Calendar, Sales Dashboard, Customer Detail, Sales Order Detail and Payment & Delivery Tracking.
- Implemented scanner workflow abstraction with functioning manual SKU/barcode/QR lookup. Camera support remains intentionally disabled until mobile plugin/platform setup exists.
- Wired Admin → Inventory / Purchase / Production / Warehouse / Dispatch / HR / Sales; Sales → Customer Detail / Sales Order Detail / Payment & Delivery Tracking; HR → Employee Detail / Attendance & Leave / Holiday Calendar; Purchase → Purchase Order Detail; Production → Production Order Detail; Inventory → Item Detail / Scanner; and Employee → Scanner / Production routes.
- Made the growing Admin module navigation scroll-safe for additional modules.
- Added HR domain regression tests for attendance rate, non-negative leave availability and attendance exception derivation.
- Added Sales domain regression tests for non-negative outstanding/reservation shortage, bounded payment collection rate and zero-credit-limit handling.
- Added full Sales widget navigation/layout coverage alongside the existing login, Inventory/Scanner, Purchase, HR and multi-module tests.

## Verified

- GitHub repository/branch/PR writes confirmed through connected GitHub.
- Connected Supabase account exposes only `janseva-production`; it has not been modified for FactoryOS.
- Flutter 3.47.7 CI passes `flutter analyze --fatal-infos`.
- Complete current Flutter test suite passes, including Login → Admin → Inventory → Scanner, Admin → Production → Production Order → Inventory Item → Warehouse → Dispatch, Admin → Purchase → Purchase Order Detail, Admin → HR → Employee Detail → Attendance & Leave → Holiday Calendar, and Admin → Sales → Customer Detail → Sales Order Detail → Payment & Delivery Tracking navigation.
- Sales order outstanding value and reservation shortage are regression-tested to never become negative.
- Sales payment collection rate is regression-tested to remain bounded and payment-derived outstanding value is tested.
- Customer credit utilization handles a zero credit limit without division errors.
- Sales Dashboard, Customer Detail, Sales Order Detail and Payment & Delivery Tracking have zero-render-exception checks at the 1440×1024 test surface.
- HR attendance rate is regression-tested, including zero-active-employee handling.
- Leave available balance is regression-tested to never produce a negative UI value.
- Attendance late/absent exception derivation has regression coverage.
- HR Dashboard, Employee Detail, Attendance & Leave and Holiday Calendar have zero-render-exception checks at the 1440×1024 test surface.
- Purchase order pending quantity cannot go negative; Purchase order/received/pending value derivations have regression coverage.
- Purchase Dashboard and Purchase Order Detail have explicit zero-render-exception checks.
- Production material shortage calculations are regression-tested and never return a negative shortage.
- Inventory Item Detail available quantity and low-stock classification are regression-tested.
- Scanner preview lookup resolves SKU, barcode and QR forms consistently and returns no result for unknown codes.
- QA caught and fixed deprecated Flutter dropdown APIs, Inventory dropdown overflow, KPI-card vertical overflows, production-alert navigation ambiguity, preview SKU inconsistency, Purchase detail overflow, sidebar growth risk, Holiday Calendar const-evaluation failure, HR KPI overflow, Sales Dashboard KPI overflow and Sales Order Detail KPI overflow before accepting these milestones.
- Manual schema review found and fixed nullable-unique, delete-trigger, HR cross-reference and Sales seed lifecycle issues before any database deployment.

## Not yet verified

- SQL schemas, including Purchase/GRN, HR and Sales schemas, have NOT been executed against a dedicated FactoryOS Supabase project.
- RLS, permission isolation, inventory posting RPCs, production-completion RPCs, Purchase/GRN behavior, HR policies and Sales customer/order/payment policies have NOT yet been database-tested.
- Real authentication is NOT connected; current login route is a preview implementation.
- Dashboard and operational modules currently use replaceable preview repository adapters where applicable. Real Supabase repositories are pending.
- Purchase create/receipt, HR add/edit employee, attendance correction, leave approval, holiday management, Sales create/update order and customer payment mutation controls are UI-only until real transactional commands are connected.
- Sales delivery status currently uses a repository handoff model; full Dispatch/Trip foreign-key integration is pending the Fleet/Trip schema.
- Warehouse and Dispatch operational actions are UI/repository foundations only; their full business schema, transactional commands and DB constraints are still pending.
- Scanner camera/barcode runtime integration is NOT implemented yet; manual entry is the verified workflow.

## Pending immediate dependencies

1. Connect or create a dedicated FactoryOS Supabase project; never reuse `janseva-production`.
2. Apply core → inventory → inventory review fixes → production/quality → production review fixes → purchase → HR → HR review fixes → Sales → seed scripts.
3. Run RLS cross-tenant tests plus Supabase security/performance advisors and ledger/HR/Sales policy-integrity tests.
4. Replace preview auth/dashboard/operational repositories with Supabase-backed implementations.
5. Add Warehouse and Dispatch transactional schemas/actions after their approved UI flows.
6. Add Android/iOS mobile scaffold and camera/barcode plugin permissions before enabling real scanning.
7. Continue repo-only design/development with Fleet / Vehicles / Drivers → Trips / Fuel → Delivery → Maintenance → Reporting while backend deployment remains blocked.

## Rule

Statuses describe verified repository/database reality. A design, schema file or compiling screen alone is not a completed production module.
