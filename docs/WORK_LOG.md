# FactoryOS Work Log

Last updated: 2026-10-15

## Current verified state

- Design System: **54 design-first SVG specifications**.
- Authentication: preview/live service graph with Supabase Auth adapter; dedicated FactoryOS deployment pending.
- Inventory: Dashboard + Scanner + Item Detail + Stock Entry implemented; Supabase reads and the manual Stock Entry command boundary are repository/local-PostgreSQL verified; immutable ledger remains the stock source of truth.
- Production/Quality: Dashboard + Order Detail implemented; Supabase read adapters and guarded batch completion command are repository/local-PostgreSQL verified.
- Warehouse: live Supabase transfer adapter + atomic `transfer_out` / `transfer_in` command foundation verified locally.
- Dispatch: live Supabase adapter + full-load guard + stock-post/finalize/Delivery handoff verified locally.
- Purchase: Dashboard + PO Detail + GRN + **PO Creation / Edit / Submit / Approval / Rejection** workflow implemented. Purchase GRN and PO workflow RPC/security regressions are repository/local-PostgreSQL verified; real deployed Supabase verification remains pending.
- HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications: implemented preview/schema foundations retained; live deployment/repository completion varies by module and remains subject to dedicated FactoryOS Supabase verification.
- RBAC/Multi-tenancy: explicit organization/factory/warehouse/department scopes and fail-fast PostgreSQL security CI remain green.
- Full production E2E QA: not started because a dedicated deployed FactoryOS backend does not yet exist.

## Accepted runtime/code milestone

Accepted Purchase Order Creation & Approval runtime/code head:

`e003b170fc66109d2aa5ddf1713573f42e4f03d4`

Verification:

- Database CI `38717704718`: **success**, including Purchase Order workflow assertions.
- Flutter CI `38717704697`: analyzer clean and **81/81 tests passed**.
- PO regressions verify draft creation, atomic line replacement, optimistic revision conflicts, submit freeze, approve/reject, retry idempotency, direct-DML denial, empty-submit denial, unauthorized authoring, cross-factory decision denial and audit evidence.
- Flutter regressions verify request validation/totals, no-fake preview mutation, dashboard → PO editor, pending queue → approval review, live save → submit and live approve repository boundaries.
- Previously accepted Purchase GRN, Inventory Stock Entry, Production, Warehouse, Dispatch, Notifications, Reporting, Maintenance, Delivery, Fleet, Sales, HR and security regressions remain green.

## Implemented in this milestone

- Design 53: `designs/53_purchase_order_editor.svg`.
- Design 54: `designs/54_purchase_order_approval.svg`.
- Server-side PO workflow commands for draft create/update, submit and approve/reject.
- `purchase.manage` authoring scope separated from exact-factory `approval.act` decisions.
- Submitted commercial lines are frozen; rejection returns the PO to editable draft with reason history.
- Stable idempotency receipts and optimistic `revision` checks protect retries/concurrent editing.
- Purchase workflow lifecycle is recorded in the shared audit stream, including explicit `submit` and typed approval/rejection actions.
- Preview workflow remains mutation-disabled rather than fabricating writes.
- Live Supabase workflow repository calls the RPC boundary instead of direct PO/line writes.
- Purchase Dashboard → Create PO → Submit → Pending Approval → Approve/Reject → approved PO → GRN navigation is connected.
- Selected PO number is preserved when opening the GRN workflow.
- Responsive factory/supplier/item dropdowns prevent narrow-layout RenderFlex failures.
- Database CI now applies `04e_purchase_order_decision_audit_fix.sql` in dependency order.

See:

- `PURCHASE_ORDER_WORKFLOW_PROGRESS.md`
- `PURCHASE_GRN_PROGRESS.md`
- `INVENTORY_STOCK_ENTRY_PROGRESS.md`
- `INVENTORY_PRODUCTION_LIVE_PROGRESS.md`
- `SUPABASE_INTEGRATION_READINESS.md`
- `WAREHOUSE_DISPATCH_PROGRESS.md`
- `SECURITY_PROGRESS.md`
- `NOTIFICATIONS_PROGRESS.md`
- `REPORTING_PROGRESS.md`
- `MAINTENANCE_PROGRESS.md`

## Production blockers / remaining work

- No dedicated FactoryOS Supabase project has been created or connected.
- `janseva-production` must never be reused for FactoryOS.
- Real Supabase Auth/JWT/Data API/RLS/RPC/cross-tenant verification and security/performance advisors remain pending.
- Repository-verified live adapters/commands have not yet been exercised against a deployed FactoryOS project.
- Purchase Supplier-management mutations and broader document/storage capabilities remain pending.
- HR, Sales, Fleet, Delivery, Maintenance, Reporting and Notifications still require remaining live repository/deployment verification as applicable.
- Trusted FCM dispatch, live Reporting exports, POD storage, scanner camera integration and full production E2E remain pending.

## Dependency order

1. Create/connect a dedicated FactoryOS Supabase project **only after organization + estimated-cost confirmation**.
2. Deploy the PostgreSQL-verified schema chain, including Purchase PO/GRN commands; provision controlled test users/memberships/roles.
3. Run real Auth/JWT/Data API/RLS/RPC/cross-tenant tests and Supabase security/performance advisors.
4. Exercise Auth, Inventory, Production, Warehouse, Dispatch and Purchase live adapters against the deployed environment.
5. If deployment approval remains pending, continue repo-only dependency-safe transactional work beginning with Purchase Supplier Management rather than adding fake deployment behavior.
6. Migrate/complete remaining repositories module-by-module.
7. Verify Purchase → GRN → Inventory → Production and Dispatch → Trip → Delivery → Return → Warehouse deployed E2E flows; then finish FCM, Reporting exports, POD/scanner runtime integration and production QA.

## Rule

Statuses describe verified repository/database reality. A design, schema file, passing Flutter screen or local PostgreSQL test alone is not a production-complete module. Final production acceptance requires a dedicated FactoryOS Supabase environment and real Auth/RLS/RPC/E2E verification.
