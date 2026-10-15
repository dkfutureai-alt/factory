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
- `supabase` — PostgreSQL migrations, RLS policies, Edge Functions, demo seed and automated access tests
- `docs` — architecture, workflows, product decisions, QA and release documentation

## Backend

Primary backend: Supabase/PostgreSQL with mandatory tenant isolation and RLS. FCM may be used for mobile push notifications.

## Engineering Rules

- Repository and connected database are the source of truth.
- No permanent hardcoded dashboard statistics.
- Inventory changes must be ledger-backed.
- Critical multi-step business operations must be atomic.
- Every client organization is isolated using organization context plus RLS.
- Major UI screens are designed before implementation and compared with the approved visual specification.
- No module is complete until database, CRUD, permissions, validation, loading/error states, realistic seed data and workflow tests are verified.

## Current Status

- Phase 0: repository audit — complete.
- Phase 1: architecture, tenancy, RBAC and database core — complete and CI validated.
- Phase 2: authentication, invitation, onboarding, role assignment and factory assignment — complete and CI validated.
- Phase 3: HR, employees, departments/designations, shifts, attendance, leave, holidays and HR reporting — complete at the core application/database level and CI validated.
- Phase 4: inventory item/category/unit masters, stock locations, atomic receive/issue/transfer, QR/barcode scan, stock ledger, reorder alerts and inventory reports — complete at the core application/database level and CI validated.
- Phase 5: Production — next.

Latest validated checks:

- invitation Edge Function type-check — pass;
- clean local Supabase start/reset, all migrations and fictional seed — pass;
- foundation, access, HR and inventory SQL smoke/integrity tests — pass;
- real local employee signup -> password login -> JWT -> PostgREST -> factory/HR/inventory RLS — pass;
- employee self-profile, check-in and leave-request RPC flows — pass;
- factory-manager attendance correction and cross-factory denial — pass;
- employee inventory scan restricted to assigned factory — pass;
- factory-manager inventory receive, transfer and issue RPC flows — pass;
- ledger-derived balance verification and insufficient-stock rejection — pass;
- cross-factory manager inventory denial and employee inventory-write denial — pass;
- shared Flutter core analysis and permission tests — pass;
- admin web analysis and release web build — pass;
- mobile Flutter analysis including HR self-service and barcode/QR inventory scanning — pass.

Production deployment still needs project-specific SMTP/invite redirect configuration and generated Android/iOS platform/release configuration; these are environment/release tasks rather than missing Phase 2–4 business logic.

See `docs/PHASE_1_FOUNDATION.md`, `docs/PHASE_2_AUTH_SHELLS.md`, `docs/PHASE_3_HR.md` and `docs/PHASE_4_INVENTORY.md`.

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

The demo seed uses a clearly fictional factory and interconnected records. Release dashboards must be generated from database data rather than UI constants.
