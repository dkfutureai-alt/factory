# FactoryOS Supabase Integration Readiness checkpoint (2026-10-15)

FactoryOS is **Supabase-integration-ready at repository level** for Authentication, Inventory, Production, Warehouse and Dispatch. No Supabase project was created or modified, and `janseva-production` remains untouched.

## Delivered

- 50 design-first SVG specifications, including connected Supabase-ready Login.
- `supabase_flutter: ^2.18.3`.
- Explicit preview/live backend configuration and service composition.
- Supabase Auth repository with password sign-in, session restore and sign-out.
- Supabase Inventory overview/item-detail adapters using RLS-visible normalized data and ledger-derived balances.
- Supabase Production overview/order-detail adapters plus a completion boundary that calls only `complete_production_batch`.
- Supabase Warehouse adapter using the verified atomic transfer RPC.
- Supabase Dispatch adapter using the verified stock-post/finalize RPCs.
- Selected Inventory SKU and Production order navigation now resolves the chosen record in preview and live modes.
- Preview mutation paths remain disabled.
- No service-role key in the client.
- Invalid requested live configuration fails visibly instead of falling back to demo data.
- Dispatch partial-load stock posting is blocked before immutable ledger linkage.
- Production completion is PostgreSQL-tested for permission denial, QC-hold denial, batch-tracked finished-goods ledger evidence and successful parent-order reconciliation.
- Notification security tests restore deterministic membership state.
- The old non-functional Inventory Stock Entry and Production create-order actions were removed instead of being left as fake controls.

## Verified runtime/code head

`b0753d85d98281e3ff81aba63bc8e4cc4486452c`

- Database CI `38691655274`: success, including Production completion command assertions.
- Flutter CI `38691655283`: analyzer clean and **67/67 tests passed**.

See `INVENTORY_PRODUCTION_LIVE_PROGRESS.md` for the detailed Inventory/Production checkpoint.

Later checkpoint commits are documentation-only unless separately verified.

## Still pending

- Inventory Stock Entry is a genuine missing P1 workflow and must be designed image-first before implementation.
- Purchase, HR, Sales, Fleet, Delivery, Maintenance, Notifications and Reporting still require live Supabase repository migration/verification.
- Real Auth/JWT/Data API/RLS/RPC, advisors and full E2E tests require a dedicated FactoryOS Supabase deployment.

## Next dependency

A dedicated FactoryOS Supabase project can be created only after **organization + estimated-cost confirmation**. Never reuse `janseva-production`.

After deployment: apply schemas, provision controlled test users/roles, run real Auth/JWT/RLS/RPC + advisors, exercise live adapters, migrate remaining repositories, and verify full Dispatch → Trip → Delivery → Return → Warehouse E2E.

If deployment approval remains pending, the next repo-only P1 target is the real **Inventory Stock Entry** workflow using the mandatory image-first process and validated Inventory-ledger posting.

This is not a deployed-Supabase or production-completion claim.
