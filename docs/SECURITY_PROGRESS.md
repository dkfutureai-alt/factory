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

The new `user_roles_validate_scope` trigger rejects:

- role/organization mismatch;
- assignment without organization membership;
- cross-tenant factory/warehouse/department references;
- warehouse/department parent-factory mismatch;
- combined warehouse + department scopes.

Core RLS now makes factory, warehouse and department metadata scope-aware. Non-admin users can read only their own membership/role rows, while organization-wide settings administrators retain administrative visibility.

## Module RLS hardening

`supabase/schemas/10a_module_scope_hardening.sql` updates child-table policies so a missing child `factory_id` does not become an organization-wide authorization shortcut. Child rows resolve their authoritative parent scope across:

- Inventory stock transaction lines;
- Production material requirements, consumption, outputs and QC parameters;
- Purchase order and goods-receipt lines;
- HR private details, attendance corrections and leave balances;
- Sales order lines and linked payments;
- Fleet vehicle documents / driver profiles;
- Delivery lines, POD, exceptions and events;
- Notification templates / rules.

Shared organization masters such as the item, supplier and customer catalogs use explicit any-scope reads only where cross-factory catalog visibility is intentional; organization-level configuration writes remain organization-wide.

## Database execution gate

`.github/workflows/factoryos_db_ci.yml` now provisions PostgreSQL 16 and executes the FactoryOS SQL stack on every relevant change.

The gate:

1. bootstraps a CI-only `auth.uid()` compatibility layer;
2. applies all schema/review/command files in dependency order;
3. applies all fictional demo seeds in dependency order;
4. executes RBAC/RLS assertions as the `authenticated` database role.

`supabase/tests/01_rbac_scope_security.sql` verifies:

- organization vs factory vs warehouse vs department semantics;
- no upward scope escalation;
- cross-factory, cross-warehouse, cross-department and cross-tenant denial;
- suspended-membership denial;
- malformed role-assignment rejection;
- self-only membership / user-role enumeration for non-admins;
- denial of organization-module mutation from a factory-scoped manager;
- legitimate factory-scoped child-row visibility across Inventory, Production, Purchase, Sales and Delivery.

## Defects found by real SQL execution

The new gate exposed three pre-existing database defects that Flutter/static review did not reveal:

1. Fleet generic reference trigger referenced `NEW.trip_id` while executing for `trips`, which has no `trip_id` field.
   - Fixed by `supabase/schemas/07c_fleet_trigger_hardening.sql` using table-specific trigger branches.
2. Fleet driver-code review seed referenced the UPDATE target alias inside an invalid `FROM ... JOIN ... ON` clause.
   - Fixed by rewriting `supabase/seed/06a_demo_fleet_review_fixes.sql` to valid `UPDATE ... FROM ... WHERE` syntax.
3. Delivery generic child trigger referenced `NEW.delivery_line_id` while executing for POD rows, which have no such field.
   - Fixed by `supabase/schemas/08b_delivery_trigger_hardening.sql` using table-specific trigger branches.

## Verified repository result

On the accepted security code head, Database CI successfully completed:

- Supabase compatibility bootstrap;
- every FactoryOS schema/review/command migration;
- every current fictional demo seed;
- all RBAC/RLS scope assertions.

The existing Flutter analyzer also remained green while the full Flutter regression suite continued to run independently.

## Still not production-complete

This milestone intentionally does **not** claim deployed Supabase security. Remaining gates include:

- no dedicated FactoryOS Supabase project has been created or connected;
- no schema has been applied to a live FactoryOS Supabase environment;
- real Supabase Auth/JWT/RLS behavior has not yet been exercised;
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
3. Replace preview Auth/repositories with Supabase-backed implementations.
4. Connect trusted notification dispatch / FCM lifecycle.
5. Connect authorized live Reporting aggregates and audited exports.
6. Complete Warehouse / Dispatch transactional backend.
7. Add scanner/POD platform integrations and run production E2E QA.

**This is a verified repository/PostgreSQL security milestone, not a deployed-Supabase or production-completion claim.**
