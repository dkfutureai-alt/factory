# FactoryOS Work Log

Last updated: 2026-10-15

## Current verified state

- Design System: **50 design-first SVG specifications**.
- Authentication: preview/live service graph with Supabase Auth adapter; dedicated FactoryOS deployment pending.
- Inventory: Dashboard + Scanner + Item Detail implemented; selected-item navigation fixed; Supabase overview/item-detail read adapters implemented; immutable ledger remains the stock source of truth; real Stock Entry workflow still pending.
- Production/Quality: Dashboard + Order Detail implemented; selected-order navigation fixed; Supabase overview/order-detail adapters implemented; live completion calls only `complete_production_batch`; PostgreSQL authorization/QC/ledger/completion command assertions pass.
- Warehouse: live Supabase transfer adapter + atomic `transfer_out` / `transfer_in` command foundation verified locally.
- Dispatch: live Supabase adapter + full-load guard + stock-post/finalize/Delivery handoff verified locally.
- Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications: existing implemented preview/schema foundations retained; live Supabase migration/verification remains pending.
- RBAC/Multi-tenancy: explicit organization/factory/warehouse/department scopes and fail-fast PostgreSQL security CI remain green.
- Full production E2E QA: not started because a dedicated deployed FactoryOS backend does not yet exist.

## Accepted runtime/code milestone

Accepted Inventory/Production runtime/code head:

`b0753d85d98281e3ff81aba63bc8e4cc4486452c`

Verification:

- Database CI `38691655274`: **success**.
- Flutter CI `38691655283`: analyzer clean and **67/67 tests passed**.
- Production completion Database CI verifies unauthorized warehouse-scope denial, QC-hold blocking, required batch-tracked finished-goods ledger evidence and authorized parent-order reconciliation.
- Flutter regression verifies selected non-default Inventory SKU and Production order navigation plus durable Production completion state through the repository command boundary.
- Previously accepted Warehouse, Dispatch, Notifications, Reporting, Maintenance, Delivery, Fleet, Sales, HR and Purchase regression coverage remains green.

## Implemented in this milestone

- `SupabaseInventoryRepository`.
- `SupabaseInventoryItemDetailRepository`.
- `SupabaseProductionRepository`.
- `SupabaseProductionOrderDetailRepository`.
- Inventory and Production wired into the preview/live `FactoryOsServices` service graph.
- Selected-record navigation corrected in preview and live modes.
- Non-functional Inventory Stock Entry and Production create-order controls removed rather than left as fake actions.
- Production Order Detail exposes live-only **Complete batch** when QC is `Pass`; preview remains mutation-disabled.
- Added `supabase/tests/05_production_completion_commands.sql` and CI execution.
- CI fixture preserves batch-tracking by creating/linking a real finished-goods batch rather than weakening Inventory rules.

See:

- `SUPABASE_INTEGRATION_READINESS.md`
- `INVENTORY_PRODUCTION_LIVE_PROGRESS.md`
- `WAREHOUSE_DISPATCH_PROGRESS.md`
- `SECURITY_PROGRESS.md`
- `NOTIFICATIONS_PROGRESS.md`
- `REPORTING_PROGRESS.md`
- `MAINTENANCE_PROGRESS.md`

## Production blockers / remaining work

- No dedicated FactoryOS Supabase project has been created or connected.
- `janseva-production` must never be reused for FactoryOS.
- Real Supabase Auth/JWT/Data API/RLS/RPC and security/performance advisors remain pending.
- Inventory/Production/Warehouse/Dispatch live adapters have not yet been exercised against a deployed FactoryOS project.
- A real Inventory Stock Entry transaction workflow is missing.
- Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications still require live repository migration/verification.
- Trusted FCM dispatch, live Reporting exports, POD storage, scanner camera integration and full production E2E remain pending.

## Dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization + estimated-cost confirmation**.
2. Deploy the PostgreSQL-verified schema chain; provision controlled test users/memberships/roles.
3. Run real Auth/JWT/Data API/RLS/RPC/cross-tenant tests and Supabase security/performance advisors.
4. Exercise Auth, Inventory, Production, Warehouse and Dispatch live adapters against the deployed environment.
5. If deployment approval is still pending, develop the missing **Inventory Stock Entry** workflow using mandatory image-first design and a validated ledger/RPC posting path.
6. Migrate remaining repositories module-by-module.
7. Verify Dispatch → Trip → Delivery → Return → Warehouse E2E; then finish FCM, Reporting exports, POD/scanner runtime integration and production QA.

## Rule

Statuses describe verified repository/database reality. A design, schema file, passing Flutter screen or local PostgreSQL test alone is not a production-complete module. Final production acceptance requires a dedicated FactoryOS Supabase environment and real Auth/RLS/RPC/E2E verification.
