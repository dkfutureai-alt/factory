# FactoryOS RBAC & Database Security checkpoint (2026-10-14)

Repository-side RBAC / tenant-scope hardening is implemented and verified through the dedicated PostgreSQL CI gate. This milestone does not create or modify a Supabase project and does not touch `janseva-production`.

## Hardened scope model

`supabase/schemas/01a_rbac_scope_hardening.sql` adds explicit any-scope, organization, factory, warehouse, and department permission helpers plus structural visibility helpers. The compatibility `private.has_permission(org,key,NULL)` now means organization-wide authority only; narrower factory/warehouse/department assignments cannot escalate upward.

`user_roles_validate_scope` rejects role/organization mismatch, missing membership, cross-tenant scope references, warehouse/department parent-factory mismatch, and combined warehouse + department scopes.

`supabase/schemas/10a_module_scope_hardening.sql` makes child-table RLS resolve authoritative parent scope across Inventory, Production/Quality, Purchase, HR, Sales, Fleet, Delivery, and Notifications instead of using null factory scope as a shortcut.

## Executable database security gate

`.github/workflows/factoryos_db_ci.yml` provisions PostgreSQL 16, bootstraps a CI-only `auth.uid()` compatibility layer, applies the complete FactoryOS schema/review/command chain, applies all fictional demo seeds, and executes `supabase/tests/01_rbac_scope_security.sql` as the `authenticated` role.

Assertions cover organization/factory/warehouse/department semantics, no upward escalation, cross-scope and cross-tenant denial, suspended memberships, malformed role assignments, self-only membership/role enumeration for non-admins, denial of organization settings mutation from a factory-scoped manager, and legitimate factory-scoped child-row visibility.

## Defects found and fixed by real SQL execution

1. Fleet generic trigger referenced `NEW.trip_id` on the `trips` row type; fixed by `07c_fleet_trigger_hardening.sql`.
2. Fleet driver-code review seed used invalid UPDATE target alias visibility; fixed in `06a_demo_fleet_review_fixes.sql`.
3. Delivery generic child trigger referenced `NEW.delivery_line_id` on POD rows; fixed by `08b_delivery_trigger_hardening.sql`.

## Verification

The security milestone passes both repository verification lanes:

- Database CI applies every current schema/review/command file and every fictional seed, then passes all RBAC/RLS assertions.
- Flutter CI remains green with analyzer and the complete existing **53-test** suite.
- Security documentation files are included in the Database CI path trigger, so documentation-only milestone updates are rechecked through the same PostgreSQL gate.

## Still not production-complete

No dedicated FactoryOS Supabase project exists yet. Real Supabase Auth/JWT/Data API/RLS behavior, deployed RPC privileges, storage policies, Supabase security/performance advisors, live repositories, real FCM delivery, and full production E2E QA remain pending.

## Next dependency order

1. Create/connect a dedicated FactoryOS Supabase project only after organization/cost confirmation; never reuse `janseva-production`.
2. Apply the verified schema chain and run deployed RLS/RPC/cross-tenant/security/performance tests.
3. Replace preview Auth/repositories with live Supabase-backed implementations.
4. Add trusted notification dispatch and real FCM lifecycle.
5. Connect authorized live Reporting aggregates/exports.
6. Complete Warehouse/Dispatch transactional backend.
7. Add scanner/POD platform integrations and production E2E QA.

**Verified repository/PostgreSQL security milestone; not a deployed-Supabase or production-completion claim.**
