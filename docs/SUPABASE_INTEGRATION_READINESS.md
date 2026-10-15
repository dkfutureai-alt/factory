# FactoryOS Supabase Integration Readiness checkpoint (2026-10-15)

## Scope

This checkpoint prepares the FactoryOS Flutter application for a dedicated Supabase backend without creating, connecting to, or modifying any Supabase project. `janseva-production` remains untouched.

The milestone adds a replaceable live backend path for Authentication, Warehouse and Dispatch while preserving preview mode for deterministic development and CI.

## Design-first surface

Added `designs/50_supabase_ready_login.svg`. FactoryOS now has **50 design-first SVG specifications**.

## Runtime configuration

FactoryOS supports explicit `preview` and `supabase` backend modes through:

- `FACTORYOS_BACKEND`
- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`

Preview remains the default. Requested Supabase mode fails visibly when configuration is missing or invalid; non-local URLs require HTTPS. No service-role key is read or stored by the Flutter client.

## Live integration boundaries

The Flutter app uses `supabase_flutter: ^2.18.3` and now includes:

- `SupabaseAuthRepository`
- `SupabaseWarehouseRepository`
- `SupabaseDispatchRepository`
- backend configuration/bootstrap/service composition
- backend-aware route composition

Login supports password sign-in, current-session restore and sign-out through the Auth repository boundary.

Warehouse live completion calls only `complete_warehouse_transfer`; it never directly changes balances.

Dispatch live mutations call only `post_dispatch_stock` and `finalize_dispatch` in this order:

**Fully load → Post dispatch stock → Reconcile ledger → Complete checks/trip → Finalize → Delivery handoff**

Preview repositories remain mutation-disabled.

## Integrity hardening

`11d_dispatch_full_load_guard.sql` prevents outbound stock posting while any dispatch line is only partially loaded. The executable PostgreSQL regression test proves planned 10 / loaded 5 is rejected without creating a stock transaction or ledger link.

The Notifications suspension security test now restores its deterministic membership fixture after proving suspended-member denial. Dispatch fixtures are resolved without weakening authenticated RLS.

## Verification

Accepted runtime/code head: `d9af6e39909492298682740031f2be61a92535f4`.

- Database CI `38688424899`: success across schema, seeds, RBAC/RLS, Notifications security, Warehouse/Dispatch commands and partial-load guard.
- Flutter CI `38688424928`: analyzer clean and **66/66 tests passed**.

Later commits in this checkpoint contain documentation only and do not change the accepted runtime/code contents.

## Still pending

- dedicated FactoryOS Supabase project creation/connection
- schema deployment and real Auth/JWT/Data API/RLS/RPC testing
- Supabase security/performance advisors
- real FactoryOS user/membership/role provisioning
- live migration of remaining module repositories beyond Auth/Warehouse/Dispatch
- deployed Dispatch → Trip → Delivery → Return → Warehouse E2E
- trusted FCM dispatcher, live Reporting/export backends, POD storage and scanner/camera integration

## Next dependency

A dedicated FactoryOS Supabase project is now the next dependency and must be created only after organization and estimated-cost confirmation. Never reuse `janseva-production`.

**This is a repository-level Supabase integration-readiness milestone, not a deployed-Supabase or production-completion claim.**
