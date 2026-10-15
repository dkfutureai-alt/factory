# FactoryOS Supabase Integration Readiness checkpoint (2026-10-15)

## Scope

This checkpoint prepares the FactoryOS Flutter application for a dedicated Supabase backend without creating, connecting to, or modifying any Supabase project.

`janseva-production` remains untouched.

The milestone adds a replaceable live backend path for Authentication, Warehouse and Dispatch while preserving the existing preview mode for deterministic development and CI.

## Design-first surface

Added:

- `designs/50_supabase_ready_login.svg`

FactoryOS now has **50 design-first SVG specifications**.

The login design distinguishes a connected backend from preview mode and explicitly avoids service-role credentials in client builds.

## Runtime configuration

FactoryOS now supports two explicit backend modes:

- `preview`
- `supabase`

Compile-time configuration uses:

- `FACTORYOS_BACKEND`
- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`

Example development command after a dedicated FactoryOS Supabase project exists:

```bash
flutter run \
  --dart-define=FACTORYOS_BACKEND=supabase \
  --dart-define=FACTORYOS_SUPABASE_URL=<factoryos-project-url> \
  --dart-define=FACTORYOS_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Rules:

- preview remains the default for repository demos and CI;
- requesting Supabase mode with missing/invalid configuration fails visibly instead of silently using demo data;
- non-local Supabase URLs must use HTTPS;
- the Flutter app never reads or stores a Supabase service-role key.

## Supabase client and service graph

The Flutter app now depends on `supabase_flutter: ^2.18.3` and has a backend service graph that selects preview or Supabase implementations.

Implemented live boundaries:

- `SupabaseAuthRepository`
- `SupabaseWarehouseRepository`
- `SupabaseDispatchRepository`

The backend configuration, bootstrap, Auth boundary and live Warehouse/Dispatch repository adapters are exported through the central FactoryOS export surface for reuse by later modules.

Existing routes remain preview-compatible for tests. Runtime route composition overrides Login, Warehouse and Dispatch only when the live service graph is selected, allowing later modules to migrate incrementally.

## Authentication readiness

The Login flow now uses an `AuthRepository` boundary.

Preview mode returns an explicitly marked preview session.

Supabase mode uses:

- `signInWithPassword`
- `currentSession`
- `signOut`

If a valid Supabase session already exists at startup, FactoryOS can start at the Admin route instead of presenting Login again.

This is client integration readiness only. Real FactoryOS users, organizations, memberships and role assignments have not been provisioned in a deployed Supabase project yet.

## Warehouse live adapter

`SupabaseWarehouseRepository` reads only RLS-visible Warehouse/Inventory records and resolves normalized item, batch, location, unit, employee and warehouse data.

Live transfer completion calls only:

- `complete_warehouse_transfer`

It does not update stock balances directly. The existing atomic `transfer_out` + `transfer_in` ledger command remains the only transfer completion path.

The Warehouse Transfer Detail screen now enables **Complete transfer** only when the active repository supports live mutations. Preview mode remains read-only.

## Dispatch live adapter

`SupabaseDispatchRepository` reads RLS-visible Dispatch, Sales, Customer, Trip, Vehicle, Driver, item, batch, unit and check data.

Live mutations call only the verified command RPCs:

- `post_dispatch_stock`
- `finalize_dispatch`

The Dispatch Load Detail screen now follows the explicit command sequence:

**Fully load → Post dispatch stock → Reconcile posted ledger → Complete checks/trip → Finalize dispatch → Delivery handoff**

Preview mode cannot execute either mutation.

## Dispatch integrity hardening found during integration

Live UI wiring exposed a backend lifecycle hazard: a dispatch could previously post stock when `loaded_quantity` was greater than zero but still below `planned_quantity`.

Because a ledger-linked dispatch line is immutable and finalization requires full quantity, a partial stock post could strand the dispatch permanently.

`11d_dispatch_full_load_guard.sql` now requires every line to satisfy:

- loaded quantity > 0;
- loaded quantity = planned quantity;
- source location exists;
- no stock ledger link exists yet.

A new PostgreSQL test creates a planned quantity of 10 with only 5 loaded and proves that:

- `post_dispatch_stock` is rejected;
- Dispatch stays ready;
- no stock transaction is created;
- no dispatch line is ledger-linked.

## CI isolation fix

The Notifications security test intentionally suspends the company-owner membership to prove suspended-member denial. The test previously left that membership suspended, contaminating later command tests.

The suite now restores the deterministic RBAC fixture after the suspension assertion. No RLS policy or production permission was weakened.

Dispatch command tests also resolve fixture UUIDs before switching to the authenticated role. The command still executes as the real authenticated identity; RLS is not widened just to locate CI fixtures.

## Verification

Accepted exact branch head before this documentation-only acceptance note:

`d9af6e39909492298682740031f2be61a92535f4`

Database CI run `38688424899` passed:

- Supabase auth compatibility bootstrap;
- complete schema/review/command chain through `11d_dispatch_full_load_guard.sql`;
- all fictional seeds;
- RBAC/RLS security assertions;
- Notifications security assertions with fixture restoration;
- Warehouse/Dispatch command assertions;
- Dispatch partial-load rejection assertions.

Flutter CI run `38688424928` passed:

- `flutter analyze --fatal-infos` with no issues;
- **66/66 tests**;
- backend configuration validation tests;
- preview Auth tests;
- live Warehouse command UI test using a deterministic fake live repository;
- live Dispatch sequence test from stock post through finalization using a deterministic fake live repository;
- all previously accepted FactoryOS regression coverage.

No live Supabase credentials or project were required for these tests.

## Still not production-complete

- No dedicated FactoryOS Supabase project has been created or connected.
- FactoryOS schemas have not been deployed to Supabase.
- Supabase Auth/JWT/Data API/RLS/RPC behavior has not been verified against a real FactoryOS project.
- Security/performance advisors have not been run against a FactoryOS deployment.
- Only Auth, Warehouse and Dispatch have Supabase Flutter adapters so far; other operational/reporting/notification repositories remain preview implementations.
- Real user provisioning/onboarding and organization-role assignment flows remain pending.
- POD object storage and mobile scanner/camera integration remain pending.
- Trusted FCM dispatch and live Reporting/export backends remain pending.

## Next dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization and estimated-cost confirmation**; never reuse `janseva-production`.
2. Apply the already PostgreSQL-verified schema chain in dependency order.
3. Provision controlled FactoryOS test users/memberships/roles and run real Auth/JWT/RLS/RPC/cross-tenant tests.
4. Run Supabase security and performance advisors and fix every material finding before live acceptance.
5. Exercise the new Auth/Warehouse/Dispatch adapters against the deployed environment.
6. Migrate the remaining operational repositories module-by-module to Supabase.
7. Verify Dispatch → Trip → Delivery → Return → Warehouse end to end.
8. Continue FCM, Reporting exports, POD/scanner integration and production E2E QA.

**This checkpoint means FactoryOS is Supabase-integration-ready at repository level. It is not a deployed-Supabase or production-complete claim.**
