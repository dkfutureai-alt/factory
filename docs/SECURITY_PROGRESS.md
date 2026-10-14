# FactoryOS RBAC & Database Security checkpoint (2026-10-14)

## Scope

Repository-side RBAC / tenant-scope hardening plus an executable PostgreSQL integration/security gate. This milestone does not create or modify a Supabase project and does not touch `janseva-production`.

## Permission-scope hardening

`supabase/schemas/01a_rbac_scope_hardening.sql` replaces ambiguous scope semantics with explicit helpers:

- `private.has_any_permission` for intentionally shared organization master data;
- `private.has_org_permission` for true organization-wide authority;
- `private.has_factory_permission` for organization-wide or exact-factory authority;
- `private.has_warehouse_permission` for organization/factory/exact-warehouse authority;
- `private.has_department_permission` for organization/factory/exact-department authority;
- `private.can_access_factory`, `private.can_access_warehouse`, `private.can_access_department` for scope-aware structural visibility.

The legacy-compatible `private.has_permission(org,key,NULL)` now means organization-wide only. A factory-, warehouse- or department-scoped assignment can no longer satisfy an organization-level check merely because the target factory was null.

## Role-assignment integrity

The `user_roles_validate_scope` trigger rejects role/organization mismatch, assignment without organization membership, cross-tenant factory/warehouse/department references, warehouse/department parent-factory mismatch, and combined warehouse + department scopes.

Core RLS now makes factory, warehouse and department metadata scope-aware. Non-admin users can read only their own membership/role rows, while organization-wide settings administrators retain administrative visibility.

## Module RLS hardening

`supabase/schemas/10a_module_scope_hardening.sql` updates child-table policies so a missing child `factory_id` does not become an organization-wide authorization shortcut. Child rows resolve their authoritative parent scope across Inventory, Production/Quality, Purchase, HR, Sales, Fleet, Delivery and Notifications.

Shared organization masters such as item, supplier and customer catalogs use explicit any-scope reads only where cross-factory catalog visibility is intentional; organization-level configuration writes remain organization-wide.

## Database execution gate

`.github/workflows/factoryos_db_ci.yml` provisions PostgreSQL 16 and executes the FactoryOS SQL stack on every relevant database/security/documentation change.

The gate bootstraps a CI-only `auth.uid()` compatibility layer, applies all schema/review/command files, applies all fictional demo seeds, then executes RBAC/RLS assertions as the `authenticated` database role.

`supabase/tests/01_rbac_scope_security.sql` verifies organization/factory/warehouse/department semantics, no upward escalation, cross-factory/warehouse/department/tenant denial, suspended-membership denial, malformed assignment rejection, self-only membership/role enumeration for non-admins, denial of organization-module mutation from a factory-scoped manager, and legitimate factory-scoped child-row visibility across Inventory, Production, Purchase, Sales and Delivery.

## Defects found by real SQL execution

The new gate exposed and fixed three pre-existing database defects that Flutter/static review did not reveal:

1. Fleet generic reference trigger referenced `NEW.trip_id` while executing for `trips`; fixed by `07c_fleet_trigger_hardening.sql`.
2. Fleet driver-code review seed used invalid UPDATE target alias visibility inside a JOIN; fixed in `06a_demo_fleet_review_fixes.sql`.
3. Delivery generic child trigger referenced `NEW.delivery_line_id` while executing for POD rows; fixed by `08b_delivery_trigger_hardening.sql`.

## Verified repository result

The security milestone passes both repository verification lanes:

- FactoryOS Database CI applies the complete current schema/review/command chain;
- every current fictional demo seed applies successfully;
- all RBAC/RLS scope assertions pass;
- parallel Flutter CI passes analyzer and the complete existing **53-test** suite.

Security documentation files are included in the Database CI path trigger, so documentation-only changes are rechecked by the same PostgreSQL schema/seed/RBAC-RLS gate.

## Still not production-complete

This milestone intentionally does **not** claim deployed Supabase security. Remaining gates include:

- no dedicated FactoryOS Supabase project has been created or connected;
- no schema has been applied to a live FactoryOS Supabase environment;
- real Supabase Auth/JWT/Data API/RLS behavior has not yet been exercised;
- Supabase security/performance advisors have not been run;
- storage/object policies for POD/media are not deployed/tested;
- RPC privilege review must be repeated in the deployed environment;
- real authentication and operational repositories remain preview adapters;
- Warehouse / Dispatch transactional backends are still incomplete;
- real FCM dispatch and platform integrations remain pending;
- full production E2E QA remains pending.

## Next dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization/cost confirmation**; never reuse `janseva-production`.
2. Apply the verified schema chain and run deployed RLS/RPC/cross-tenant/security/performance tests.
3. Replace preview Auth and repositories with live Supabase-backed implementations.
4. Add trusted notification dispatch plus real FCM Android/iOS/web lifecycle.
5. Connect authorized live Reporting aggregates and audited exports.
6. Complete Warehouse / Dispatch transactional backend and full workflow.
7. Add scanner/POD platform integrations and run production E2E QA.

**This is a verified repository/PostgreSQL security milestone, not a deployed-Supabase or production-completion claim.**
