# FactoryOS Supabase Integration Readiness checkpoint (2026-10-15)

FactoryOS is now **Supabase-integration-ready at repository level** for Authentication, Warehouse and Dispatch. No Supabase project was created or modified, and `janseva-production` remains untouched.

## Implemented

- Design #50: Supabase-ready connected Login.
- `supabase_flutter: ^2.18.3`.
- Explicit `preview` / `supabase` backend modes.
- Environment inputs: `FACTORYOS_BACKEND`, `FACTORYOS_SUPABASE_URL`, `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`.
- Visible configuration failure instead of silent live→preview fallback.
- No service-role key in the Flutter client.
- Supabase Auth adapter with password sign-in, current-session restore and sign-out.
- Supabase Warehouse adapter; transfer completion calls only `complete_warehouse_transfer`.
- Supabase Dispatch adapter; mutations call only `post_dispatch_stock` and `finalize_dispatch`.
- Preview Warehouse/Dispatch adapters remain mutation-disabled.
- Dispatch lifecycle hardened so outbound stock cannot post until every planned unit is fully loaded.
- Notifications security fixture teardown restored so security tests remain isolated.

## Verified runtime/code milestone

Accepted runtime/code head: `d9af6e39909492298682740031f2be61a92535f4`.

- Database CI `38688424899`: **success**.
- Flutter CI `38688424928`: analyzer clean, **66/66 tests passed**.
- Dispatch partial-load regression: planned 10 / loaded 5 is rejected with no stock transaction or ledger link.
- Live-command widget tests verify Warehouse completion and Dispatch stock-post → finalize sequencing through repository boundaries.

Documentation commits after the accepted runtime head do not modify runtime code.

## Production gates still open

- Dedicated FactoryOS Supabase project is not yet created/connected.
- Schemas are not deployed to Supabase.
- Real Auth/JWT/Data API/RLS/RPC and Supabase advisor verification are pending.
- Only Auth, Warehouse and Dispatch have live Flutter adapters so far.
- Full deployed Dispatch → Trip → Delivery → Return → Warehouse E2E is pending.
- FCM dispatcher, live Reporting/exports, POD storage and scanner/camera integration are pending.

## Next dependency

Create/connect a dedicated FactoryOS Supabase project only after **organization + estimated-cost confirmation**. Never reuse `janseva-production`.

This checkpoint is a repository/local-PostgreSQL integration milestone, not a deployed-Supabase or production-completion claim.
