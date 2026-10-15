# FactoryOS Architecture

## Product Shape

FactoryOS is a multi-tenant factory operations platform with three primary surfaces:

- Admin Web — organization/factory administration and operational control.
- Mobile — employee, supervisor and driver workflows.
- Platform Super Admin — DK Apps Studio client/tenant administration.

## Backend

Supabase/PostgreSQL is the primary system of record. Authentication uses Supabase Auth. Push notifications may use FCM. Object storage uses Supabase Storage unless a client deployment requires another provider.

## Tenancy Boundary

`organizations` is the top-level tenant boundary. A client can own one or more `factories`. Every tenant-owned transactional record must contain `organization_id`. Factory-scoped records also contain `factory_id`.

Never trust organization or role identifiers sent by a client application. Authorization must be re-evaluated in PostgreSQL RLS policies and security-definer helper functions.

## Module Boundaries

Foundation -> Auth/Tenancy -> HR -> Inventory -> Production -> Quality -> Purchase -> Sales -> Warehouse -> Vehicles/Drivers -> Trips/Fuel -> Dispatch/Delivery -> Maintenance -> Reports -> Notifications.

Cross-module writes must be transactional. Examples:

- production completion posts finished-goods inventory ledger entries;
- dispatch posts stock movement and delivery state changes atomically;
- delivery completion can create returnable-container obligations;
- fuel entry must reference a valid vehicle/trip and actor.

## Data Rules

- UUID primary keys.
- UTC timestamps (`timestamptz`).
- Soft-disable with `is_active` where historical records must remain queryable.
- Financial/quantity values use `numeric`, never floating point.
- Inventory truth is derived from immutable ledger movements, not editable counters.
- Human-readable document numbers are separate from database IDs.
- Critical state transitions write audit events.

## UI Architecture

The UI is role-aware but permission checks are never UI-only. Screens consume repositories/services rather than querying tables directly from widgets. Each major module must expose loading, empty, error and success states.

## Quality Gates

Every module requires: schema, RLS, validation, repository/API layer, UI, permissions, realistic seed data, automated tests and workflow verification before it is marked complete.
