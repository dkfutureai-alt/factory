# FactoryOS

FactoryOS is a multi-tenant, modular, white-label factory operations and management platform for real factory clients.

## Product Goal

Connect the end-to-end operating chain:

Purchase -> Raw Material -> Inventory -> Production -> Quality -> Finished Goods -> Warehouse -> Sales -> Dispatch -> Vehicle/Driver -> Delivery -> Customer -> Payment/Return

and support HR, attendance, leave, maintenance, assets, fuel, documents, approvals, audit history, notifications, reporting and client configuration.

## Applications

- `apps/admin_web` — responsive Supabase-aware administration portal
- `apps/mobile` — role-aware employee, supervisor and driver Flutter app
- `packages/factoryos_core` — shared roles, module model and design primitives
- `supabase` — PostgreSQL migrations, RLS policies, Edge Functions, fictional seed data and automated access/workflow tests
- `docs` — architecture, workflows, product decisions, QA and release documentation

## Backend

Primary backend: Supabase/PostgreSQL with mandatory tenant isolation and RLS. FCM may be used for mobile push notifications.

## Engineering Rules

- Repository and connected database are the source of truth.
- No permanent hardcoded dashboard statistics.
- Inventory changes must be ledger-backed.
- Production material consumption, finished-goods receipt, Quality quarantine/release and Purchase goods receipt/release must use that same Inventory ledger.
- Sales allocation reserves ledger-derived stock without issuing stock before dispatch.
- Critical multi-step business operations must be atomic.
- Every client organization is isolated using organization context plus RLS.
- Major UI screens are designed before implementation and compared with the approved visual specification.
- No module is complete until database, CRUD, permissions, validation, loading/error states, realistic fictional seed data and workflow tests are verified.

## Current Status

- Phase 0: repository audit — complete.
- Phase 1: architecture, tenancy, RBAC and database core — complete and CI validated.
- Phase 2: authentication, invitation, onboarding, role assignment and factory assignment — complete and CI validated.
- Phase 3: HR, employees, departments/designations, shifts, attendance, leave, holidays and HR reporting — complete at the core application/database level and CI validated.
- Phase 4: Inventory, item/category/unit masters, locations, ledger movements, scanning, reorder and reports — complete at the core application/database level and CI validated.
- Phase 5: Production, BOM/recipes, work centers, orders, batch/shift execution, material consumption, WIP, output, scrap/downtime, finished-goods receipt and reports — complete at the core application/database level and CI validated.
- Phase 6: Quality, plans/checklists, incoming/in-process/final inspection, results, NCR, quarantine/release, certificates and reports — complete at the core application/database level and CI validated.
- Phase 7: Purchase & Sales, suppliers/customers, requisitions, PO/GRN, incoming Quality, supplier billing, quotation/SO, stock allocation, dispatch readiness, customer billing and reports — complete at the core application/database level and CI validated.
- Phase 8: Warehouse, zones/bins, put-away, availability/reservation, picking, staging, dispatch handoff, cycle counts, adjustments and reports — complete at the core application/database level and CI validated.
- Phase 9: Vehicles, Drivers, Trips & Fuel — backend, Admin Fleet UI and Driver mobile workspace complete and CI validated.
- Phase 10: Dispatch, Delivery & Returnables — backend, Admin Dispatch UI and Driver Delivery/POD/Returnables workspace complete and CI validated.
- Phase 11: Maintenance — next development phase.

Latest validated checks through Phase 10:

- invitation Edge Function type-check — pass;
- clean local Supabase start/reset, migrations `0001`–`0023`, base seed + Phase 5 + Phase 6 + Phase 7 + Phase 8 + Phase 9 + Phase 10 seeds — pass;
- Foundation, Access, HR, Inventory, Production, Quality, Purchase/Sales, Warehouse, Fleet and Dispatch SQL smoke/integrity tests — pass;
- factory metadata visibility is restricted to assigned factories for factory-scoped roles while organization admins retain organization-wide visibility — pass;
- real signup -> password login -> JWT -> PostgREST factory/HR RLS — pass;
- employee self-profile, check-in and leave-request flows — pass;
- Inventory scan, receive/transfer/issue, negative-stock denial, cross-factory denial and employee-write denial — pass;
- Production manager order creation and employee order-creation denial — pass;
- Production employee batch start, BOM consumption, finished-goods receipt and completion — pass;
- Production negative-stock, output-over-plan and cross-factory denial — pass;
- Quality inspection start, checklist capture, pass/fail/hold completion and numeric tolerance auto-fail — pass;
- employee Quality certificate issue denial and manager certificate issue — pass;
- employee NCR creation and Quality quarantine ledger transfer — pass;
- employee quarantine-release denial and manager NCR closure/release — pass;
- Quality quarantine/release Inventory balance verification — pass;
- Factory Manager cross-factory Quality denial — pass;
- Purchase requisition create/approve and Purchase Order manager enforcement — pass;
- ledger-backed Goods Receipt, automatic incoming Quality creation, Quality-to-GRN status sync and Inventory release — pass;
- supplier invoice/payment and over-scope permission protections — pass;
- quotation -> Sales Order conversion, stock allocation and dispatch readiness — pass;
- customer invoice/payment and cross-factory commercial denial — pass;
- Warehouse zone/bin/staging hierarchy, put-away, pick/stage/handoff, cycle count and stock-adjustment flows — pass;
- Warehouse employee/manager permissions, ledger movement, reservation-location sync and cross-factory denial — pass;
- Fleet manager vehicle/driver/trip planning permissions and Driver-role execution — pass;
- Fleet odometer monotonicity, assignment checks, licence-expiry start protection and handoff uniqueness — pass;
- Fleet driver fuel scope, service reminder lifecycle, report authorization and cross-factory isolation — pass;
- Dispatch manager planning, Warehouse handoff/Fleet trip pairing and vehicle-load permissions — pass;
- staging → vehicle transfer, vehicle → customer issue and customer returnable → vehicle receipt remain Inventory-ledger-backed — pass;
- assigned-driver delivery visibility, unassigned-user denial, POD completion, returnable closure, exception report/resolution and dashboard authorization — pass;
- closed returnable pickups reject later stock receipts — pass;
- private POD Storage bucket/path/RLS policy checks — pass;
- shared Flutter core analysis and permission tests — pass;
- admin web analysis and release web build including Inventory + Production + Quality + Purchase/Sales + Warehouse + Fleet + Dispatch — pass;
- mobile Flutter analysis including HR, Inventory scan, Production, Quality, commercial, Warehouse, Fleet and Driver Delivery/POD operations — pass.

Production deployment still needs project-specific SMTP/invite redirect configuration and generated Android/iOS platform/release configuration; these are environment/release tasks rather than missing Phase 2–10 business logic.

See `docs/PHASE_1_FOUNDATION.md`, `docs/PHASE_2_AUTH_SHELLS.md`, `docs/PHASE_3_HR.md`, `docs/PHASE_4_INVENTORY.md`, `docs/PHASE_5_PRODUCTION.md`, `docs/PHASE_6_QUALITY.md`, `docs/PHASE_7_PURCHASE_SALES.md`, `docs/PHASE_8_WAREHOUSE.md`, `docs/PHASE_9_FLEET.md` and `docs/PHASE_10_DISPATCH_DELIVERY.md`.

## Local Supabase

```bash
supabase start
supabase db reset
for test_file in supabase/tests/*.sql; do
  psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
    -v ON_ERROR_STOP=1 \
    -f "$test_file"
done
source supabase/tests/auth_login_e2e.sh
source supabase/tests/inventory_auth_e2e.sh
bash supabase/tests/production_auth_e2e.sh
bash supabase/tests/quality_auth_e2e.sh
bash supabase/tests/purchase_sales_auth_e2e.sh
bash supabase/tests/warehouse_auth_e2e.sh
bash supabase/tests/fleet_auth_e2e.sh
bash supabase/tests/dispatch_auth_e2e.sh
```

## Development Sequence

1. Repository audit
2. Foundation: architecture, tenancy, RBAC and database core
3. Authentication + organization/factory setup + app shells
4. HR
5. Inventory
6. Production
7. Quality
8. Purchase and Sales
9. Warehouse
10. Vehicles, drivers, trips and fuel
11. Dispatch, delivery and returnables
12. Maintenance
13. Reports and dashboards
14. Notifications
15. Audit/security hardening
16. Full QA/performance
17. Production release

## Demo Tenant

The demo seed uses a clearly fictional factory and interconnected records. Release dashboards are generated from database data rather than UI constants.
