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
- Phase 2: authentication, invitation, onboarding, role assignment and factory assignment — complete at the core application/database level and CI validated.
- Phase 3: HR, attendance, leave and holidays — next.

Latest validated checks:

- invitation Edge Function type-check — pass;
- clean local Supabase start/reset, migrations and fictional seed — pass;
- foundation and access/RLS SQL smoke checks — pass;
- invitation acceptance, role update, factory reassignment and escalation-denial tests — pass;
- real local Supabase signup -> password login -> JWT -> PostgREST -> factory RLS test — pass;
- shared Flutter core analysis and 5 permission tests — pass;
- admin web analysis and release web build — pass;
- mobile Flutter analysis — pass.

Production deployment still needs project-specific SMTP/invite redirect configuration and mobile platform/release configuration; these are environment/release tasks rather than missing Phase 2 access logic.

See `docs/PHASE_1_FOUNDATION.md` and `docs/PHASE_2_AUTH_SHELLS.md`.

## Local Supabase

```bash
supabase start
supabase db reset
for test_file in supabase/tests/*.sql; do
  psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
    -v ON_ERROR_STOP=1 \
    -f "$test_file"
done
bash supabase/tests/auth_login_e2e.sh
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