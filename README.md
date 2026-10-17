# FactoryOS

FactoryOS is a multi-tenant, modular, white-label factory operations and management platform for real factory clients.

## Product Goal

Connect the end-to-end operating chain:

Purchase -> Raw Material -> Inventory -> Production -> Quality -> Finished Goods -> Warehouse -> Sales -> Dispatch -> Vehicle/Driver -> Delivery -> Customer -> Payment/Return

and support HR, attendance, leave, maintenance, assets, fuel, documents, approvals, audit history, notifications, reporting and client configuration.

## Applications

- `apps/admin_web` — responsive Supabase-aware administration portal
- `apps/mobile` — role-aware employee, supervisor and driver Flutter app
- `packages/factoryos_core` — shared roles, module model, workspace access policy and design primitives
- `supabase` — PostgreSQL migrations, RLS policies, Edge Functions, fictional seed data and automated access/workflow tests
- `docs` — architecture, workflows, product decisions, QA and release documentation

## Backend

Primary backend: Supabase/PostgreSQL with mandatory tenant isolation and RLS. FCM HTTP v1 is supported for mobile push delivery through a deployment-secret-backed Edge Function.

## Engineering Rules

- Repository and connected database are the source of truth.
- No permanent hardcoded dashboard statistics.
- Inventory changes must be ledger-backed.
- Production material consumption, finished-goods receipt, Quality quarantine/release, Purchase goods receipt/release and Maintenance spare usage must use that same Inventory ledger.
- Sales allocation reserves ledger-derived stock without issuing stock before dispatch.
- Critical multi-step business operations must be atomic.
- Every client organization is isolated using organization context plus RLS.
- Major UI screens are designed before implementation and compared with the approved visual specification.
- Privileged SECURITY DEFINER functions must have explicit caller authorization, narrowed execute permissions and pinned search paths.
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
- Phase 11: Maintenance — assets/equipment, requests, preventive plans, work orders, technician execution, QR scanning, private work media, downtime, ledger-backed spares, Admin and mobile workspaces complete and CI validated.
- Phase 12: Reports & Dashboards — unified tenant-safe reporting, executive dashboard, date/factory filtering, trends, operational exceptions, audited activity, saved report views, Admin report workspace and management mobile reporting complete and CI validated.
- Phase 13: Notifications — tenant-safe in-app inbox, scoped notification rules/templates, preferences, unread/read state, Admin broadcasts and delivery health, automatic operational events, device registry, FCM-ready push outbox/worker, Admin Notification Center and mobile Alerts inbox complete and CI validated.
- Phase 14: Audit & Security Hardening — assignment-correct factory scope, member/profile/audit RLS hardening, tamper-evident audit hash chain, immutable app-level audit history, privileged-function hardening, Security Admin workspace, Access Review and Audit Explorer complete and CI validated.
- Phase 15: Full QA & Performance — shared cross-app access-policy regression tests, reporting hot-path indexes, sargable report date filters, report RPC hardening, reproducible Supabase CLI pinning and Admin release bundle budgets complete and CI validated at the substantive source head; final documentation head validation pending before merge.
- Phase 16: Production Release — next development phase after Phase 15 merge.

Latest validated checks through the Phase 15 substantive source head:

- invitation Edge Function type-check — pass;
- notification FCM HTTP v1 Edge Function type-check — pass;
- clean local Supabase start/reset, migrations `0001`–`0039`, base seed + Phase 5 + Phase 6 + Phase 7 + Phase 8 + Phase 9 + Phase 10 + Phase 11 seeds — pass;
- Foundation, Access, HR, Inventory, Production, Quality, Purchase/Sales, Warehouse, Fleet, Dispatch, Maintenance, Reports/Dashboards, Notifications, Audit/Security and Phase 15 performance/security SQL smoke/integrity tests — pass;
- real signup -> password login -> JWT -> PostgREST factory/HR RLS — pass;
- factory metadata visibility is restricted to assigned factories for factory-scoped roles while organization admins retain organization-wide visibility — pass;
- employee self-profile, check-in and leave-request flows — pass;
- Inventory scan, receive/transfer/issue, negative-stock denial, cross-factory denial and employee-write denial — pass;
- Production manager order creation and employee order-creation denial — pass;
- Production employee batch start, BOM consumption, finished-goods receipt and completion — pass;
- Production negative-stock, output-over-plan and cross-factory denial — pass;
- Quality inspection start, checklist capture, pass/fail/hold completion and numeric tolerance auto-fail — pass;
- employee Quality certificate issue denial and manager certificate issue — pass;
- employee NCR creation, Quality quarantine ledger transfer, manager NCR closure/release and Inventory balance verification — pass;
- Purchase requisition create/approve, Purchase Order manager enforcement, ledger-backed Goods Receipt, incoming Quality sync, supplier invoice/payment and cross-factory denial — pass;
- quotation -> Sales Order conversion, stock allocation, dispatch readiness, customer invoice/payment and cross-factory commercial denial — pass;
- Warehouse zone/bin/staging hierarchy, put-away, pick/stage/handoff, cycle count, stock adjustment, permissions and ledger/reservation-location synchronization — pass;
- Fleet manager vehicle/driver/trip planning, Driver-role execution, odometer integrity, assignment/licence protections, fuel scope, service reminders and cross-factory isolation — pass;
- Dispatch handoff/trip pairing, staging -> vehicle transfer, vehicle -> customer issue, returnables receipt, assigned-driver visibility, POD, exceptions, dashboard scope and closed-pickup protection — pass;
- private POD Storage bucket/path/RLS policy checks — pass;
- Maintenance asset/planning permissions, requests, technician execution, preventive scheduling, one-active-work-order integrity, downtime, shared-ledger spare usage, private media RLS and dashboard/audit authorization — pass;
- Reports factory/organization authorization, daily trends, operational exceptions, audited activity and saved report views — pass;
- Notifications preferences, device registration, inbox/read state, scoped broadcasts, delivery state, push-only isolation, muted-category suppression and factory-rule visibility — pass;
- Factory Manager `is_factory_member` is assignment-scoped rather than organization-wide — pass;
- Factory Manager cross-factory organization-member, profile and factory-assignment privacy — pass;
- Factory Manager organization-wide and blocked-factory Security RPC denial — pass;
- Employee Security RPC denial and Organization Admin organization-wide Security access — pass;
- Factory-scoped Security Access Review and audit-feed isolation — pass;
- direct `audit_logs` RLS blocked-factory isolation — pass;
- authenticated audit INSERT/UPDATE/DELETE privileges revoked and mutation guard enforced — pass;
- per-organization audit SHA-256 hash generation, recomputation and chain-link verification — pass;
- privileged Security and optimized reporting RPCs unavailable to `anon` while intended guarded RPCs remain available to `authenticated` — pass;
- privileged Phase 14 and optimized Phase 15 report SECURITY DEFINER functions use pinned search paths and explicit scope checks — pass;
- Phase 15 report performance indexes installed and hot timestamp predicates kept index-friendly — pass;
- shared Flutter core analysis and 11 permission/workspace policy tests — pass;
- admin web analysis and release web build including Inventory + Production + Quality + Purchase/Sales + Warehouse + Fleet + Dispatch + Maintenance + Reports/Dashboards + Notifications + Audit & Security — pass;
- admin release bundle budgets (`main.dart.js` <= 5 MiB; complete web payload <= 50 MiB) — pass;
- mobile Flutter analysis and tests including HR, Inventory scan, Production, Quality, commercial, Warehouse, Fleet, Delivery/POD, Maintenance QR/photo/work-order operations, management Reports and Notifications inbox/preferences — pass.

Production deployment still needs project-specific SMTP/invite redirect configuration, generated Android/iOS platform/release configuration, FCM deployment secrets/platform setup for external push delivery, the actual FactoryOS Supabase project connection, production Admin hosting/environment variables and release signing/store credentials. These are Phase 16 environment/release tasks rather than missing Phase 1–15 application business logic.

See `docs/PHASE_1_FOUNDATION.md`, `docs/PHASE_2_AUTH_SHELLS.md`, `docs/PHASE_3_HR.md`, `docs/PHASE_4_INVENTORY.md`, `docs/PHASE_5_PRODUCTION.md`, `docs/PHASE_6_QUALITY.md`, `docs/PHASE_7_PURCHASE_SALES.md`, `docs/PHASE_8_WAREHOUSE.md`, `docs/PHASE_9_FLEET.md`, `docs/PHASE_10_DISPATCH_DELIVERY.md`, `docs/PHASE_11_MAINTENANCE.md`, `docs/PHASE_12_REPORTS_DASHBOARDS.md`, `docs/PHASE_13_NOTIFICATIONS.md`, `docs/PHASE_14_AUDIT_SECURITY.md` and `docs/PHASE_15_QA_PERFORMANCE.md`.

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
bash supabase/tests/maintenance_auth_e2e.sh
bash supabase/tests/reports_auth_e2e.sh
bash supabase/tests/notifications_auth_e2e.sh
bash supabase/tests/notifications_scope_e2e.sh
bash supabase/tests/security_auth_e2e.sh
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
