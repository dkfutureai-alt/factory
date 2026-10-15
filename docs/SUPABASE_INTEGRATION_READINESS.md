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

Existing routes remain preview-compatible for tests. Runtime route composition overrides Login, Warehouse and Dispatch only when the live service graph is selected, allowing later modules to migrate incrementally.

## Authentication readiness

The Login flow now uses an `AuthRepository` boundary. Preview mode returns an explicitly marked preview session. Supabase mode uses password sign-in, current-session restore and sign-out. A valid Supabase session can start FactoryOS at the Admin route.

This is client integration readiness only. Real FactoryOS users, organizations, memberships and role assignments have not been provisioned in a deployed Supabase project yet.

## Warehouse live adapter

`SupabaseWarehouseRepository` reads RLS-visible Warehouse/Inventory data and calls only `complete_warehouse_transfer` for live completion. It never updates stock balances directly. Preview mode remains mutation-disabled.

## Dispatch live adapter

`SupabaseDispatchRepository` reads RLS-visible Dispatch/Sales/Trip data and calls only `post_dispatch_stock` and `finalize_dispatch` for mutations.

The live sequence is:

**Fully load → Post dispatch stock → Reconcile posted ledger → Complete checks/trip → Finalize dispatch → Delivery handoff**

Preview mode cannot execute these mutations.

## Dispatch integrity hardening

`11d_dispatch_full_load_guard.sql` prevents stock posting while any dispatch line remains partially loaded. The PostgreSQL regression test proves planned 10 / loaded 5 is rejected with no stock transaction or ledger link created.

## CI isolation fix

The Notifications suspension security test now restores its deterministic membership fixture after proving suspended-member denial. Dispatch fixture UUIDs are resolved before switching to authenticated RLS, while the RPC itself still executes as the authenticated identity. No production RLS policy was widened.

## Verification

Accepted runtime/code head:

`d9af6e39909492298682740031f2be61a92535f4`

Database CI run `38688424899` passed the full schema/seed/RBAC-RLS/Notifications/Warehouse-Dispatch/partial-load suite.

Flutter CI run `38688424928` passed `flutter analyze --fatal-infos` with no issues and **66/66 tests**.

Subsequent commits in this checkpoint are documentation-only and do not alter the accepted runtime/code contents.

## Still not production-complete

- No dedicated FactoryOS Supabase project has been created or connected.
- FactoryOS schemas have not been deployed to Supabase.
- Real Supabase Auth/JWT/Data API/RLS/RPC behavior and security/performance advisors remain pending.
- Only Auth, Warehouse and Dispatch have Supabase Flutter adapters so far.
- User provisioning/onboarding, POD storage, scanner/camera, trusted FCM dispatch and live Reporting/export backends remain pending.

## Next dependency order

1. Create/connect a dedicated FactoryOS Supabase project only after organization and estimated-cost confirmation; never reuse `janseva-production`.
2. Deploy the PostgreSQL-verified schema chain.
3. Provision controlled FactoryOS test users/memberships/roles and run real Auth/JWT/RLS/RPC/cross-tenant tests.
4. Run Supabase security/performance advisors.
5. Exercise Auth/Warehouse/Dispatch live adapters against the deployed environment.
6. Migrate remaining repositories module-by-module.
7. Verify Dispatch → Trip → Delivery → Return → Warehouse end to end.
8. Continue FCM, Reporting exports, POD/scanner integration and production E2E QA.

**This checkpoint means FactoryOS is Supabase-integration-ready at repository level. It is not a deployed-Supabase or production-complete claim.**
