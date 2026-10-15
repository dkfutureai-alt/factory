# FactoryOS

FactoryOS is a multi-tenant, modular, white-label factory operations and management platform for real factory clients.

## Product Goal

Connect the end-to-end operating chain:

Purchase -> Raw Material -> Inventory -> Production -> Quality -> Finished Goods -> Warehouse -> Sales -> Dispatch -> Vehicle/Driver -> Delivery -> Customer -> Payment/Return

and support HR, attendance, leave, maintenance, assets, fuel, documents, approvals, audit history, notifications, reporting and client configuration.

## Applications

- `apps/admin_web` — responsive Supabase-aware administration portal
- `apps/mobile` — role-aware employee, supervisor and driver Flutter shell
- `packages/factoryos_core` — shared roles, module model and design primitives
- `supabase` — PostgreSQL migrations, RLS policies, functions, demo seed and smoke tests
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
- Phase 1: architecture, tenancy, RBAC and database core — implemented; CI/local database validation required.
- Phase 2: authentication + organization/factory app shells — in progress.

See `docs/PHASE_1_FOUNDATION.md` and `docs/PHASE_2_AUTH_SHELLS.md`.

## Local Supabase

```bash
supabase start
supabase db reset
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' -v ON_ERROR_STOP=1 -f supabase/tests/0001_foundation_smoke.sql
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
