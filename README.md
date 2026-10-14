# FactoryOS

FactoryOS is a multi-tenant, modular, white-label factory operations and management platform intended for real factory clients.

## Product Goal

Connect the end-to-end operating chain:

Purchase → Raw Material → Inventory → Production → Quality → Finished Goods → Warehouse → Sales → Dispatch → Vehicle/Driver → Delivery → Customer → Payment/Return

and support HR, attendance, leave, maintenance, assets, fuel, documents, approvals, audit history, notifications, reporting, and client configuration.

## Target Applications

- `apps/admin_web` — responsive administration portal
- `apps/mobile` — role-aware employee, supervisor, and driver application
- `packages/factoryos_core` — shared domain models, permissions, utilities, and design tokens
- `supabase` — PostgreSQL migrations, RLS policies, functions, and demo seed data
- `docs` — architecture, workflows, product decisions, QA and release documentation

## Backend

Primary backend: Supabase/PostgreSQL with mandatory tenant isolation and RLS. FCM may be used for mobile push notifications.

## Engineering Rules

- Repository and connected database are the source of truth.
- No permanent hardcoded dashboard statistics.
- Inventory changes must be ledger-backed.
- Critical multi-step business operations must be atomic.
- Every client organization is isolated using organization context plus RLS.
- Major UI screens are designed before implementation and then compared against the approved visual specification.
- No module is complete until database, CRUD, permissions, validation, loading/error states, realistic seed data and workflow tests are verified.

## Current Status

The repository was initialized from an empty state on 2026-10-14. Phase 0 audit found no prior code, branches, commits, database schema, screens or test suite.

Current phase: **Foundation / Architecture**.

See:

- `docs/ARCHITECTURE.md`
- `docs/RBAC_AND_TENANCY.md`
- `docs/BUSINESS_FLOWS.md`
- `docs/WORK_LOG.md`
- `supabase/migrations/0001_core_foundation.sql`

## Development Sequence

1. Repository audit
2. Architecture and design system
3. Database, tenancy and authentication
4. Roles and permissions
5. Organization/factory setup
6. HR
7. Inventory
8. Production
9. Quality
10. Sales and purchase
11. Warehouse
12. Vehicles and drivers
13. Trips and fuel
14. Dispatch and delivery
15. Maintenance
16. Reports and dashboards
17. Notifications
18. Audit and security hardening
19. Full QA/performance
20. Production release

## Demo Tenant

The demo environment will use a clearly fictional manufacturing company and interconnected records so dashboards and reports are generated from real database data rather than UI constants.
