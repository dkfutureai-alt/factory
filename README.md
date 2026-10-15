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
- Production material consumption and finished-goods receipt must use that same Inventory ledger.
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
- Phase 6: Quality — next.

Latest validated checks:

- invitation Edge Function type-check — pass;
- clean local Supabase start/reset, migrations `0001`–`0012`, base seed and Phase 5 seed — pass;
- foundation, access, HR, inventory and production SQL smoke/integrity tests — pass;
- real signup -> password login -> JWT -> PostgREST factory/HR RLS — pass;
- employee self-profile, check-in and leave-request flows — pass;
- Inventory scan, receive/transfer/issue, negative-stock denial, cross-factory denial and employee-write denial — pass;
- Production manager order creation and employee order-creation denial — pass;
- Production employee batch start, BOM consumption, finished-goods receipt and completion — pass;
- Production negative-stock, output-over-plan and cross-factory denial — pass;
- production/inventory ledger balance verification — pass;
- shared Flutter core analysis and permission tests — pass;
- admin web analysis and release web build including Inventory + Production — pass;
- mobile Flutter analysis including HR, Inventory scan and Production execution — pass.

Production deployment still needs project-specific SMTP/invite redirect configuration and generated Android/iOS platform/release configuration; these are environment/release tasks rather than missing Phase 2–5 business logic.

See `docs/PHASE_1_FOUNDATION.md`, `docs/PHASE_2_AUTH_SHELLS.md`, `docs/PHASE_3_HR.md`, `docs/PHASE_4_INVENTORY.md` and `docs/PHASE_5_PRODUCTION.md`.

## Local Supabase

```bash
supabase start
supabase db reset
for test_file in supabase/tests/*.sql; do
  psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
    -v ON_ERROR_STOP=1 \
    -f "$test_file"
done
bash -c 'source supabase/tests/auth_login_e2e.sh && source supabase/tests/inventory_auth_e2e.sh'
bash supabase/tests/production_auth_e2e.sh
```

## Development Sequence

1. Repository audit
2. Foundation: architecture, tenancy, RBAC and database core
3. Authentication + organization/factory setup + app shells
4. HR
5. Inventory
6. Production
7. Quality
8. Purchase and sales
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
