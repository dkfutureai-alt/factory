# FactoryOS Purchase GRN / Goods Receipt Progress

Status: **REPOSITORY / LOCAL-POSTGRESQL VERIFIED**

Accepted runtime/code head: `b20c8ab8f1e419db35f03fb431bc7f23c59166af`

## Design

- Design 52: `designs/52_purchase_grn_receipt.svg`
- Flow: approved PO → warehouse → supplier references → received / accepted / rejected quantities → location / batch / serial allocation → review → post.
- Rejected quantity never enters inventory.

## Database command

Implemented:

- `supabase/schemas/04a_purchase_receipt_commands.sql`
- `supabase/schemas/04b_purchase_receipt_idempotency_fix.sql`
- `public.post_purchase_goods_receipt(...)`

The command atomically:

1. authenticates and locks the selected PO,
2. derives organization / factory / supplier from the PO,
3. validates exact warehouse scope and `inventory.receive` + `inventory.post`,
4. validates received = accepted + rejected and prevents accepted over-receipt,
5. creates the GRN and Purchase Receipt ledger transaction,
6. validates / resolves inventory locations, batches and serials,
7. posts accepted quantity only through `public.post_stock_transaction`,
8. reconciles serial location/status only after successful ledger posting,
9. finalizes the GRN,
10. reconciles the PO to `part_received` or `received`,
11. writes a server-side audit event.

Network retry safety is handled before the open-PO status guard, so an exact retry after a fully received PO closes returns the already-posted GRN instead of duplicating inventory. A changed invoice/delivery reference with the same idempotency key is rejected as a conflict.

## Flutter integration

Added:

- Purchase GRN domain models and validation
- preview receipt repository that explicitly refuses mutation
- live `SupabasePurchaseReceiptRepository`
- live `SupabasePurchaseRepository` for Purchase dashboard/detail reads
- `PurchaseGoodsReceiptPage`
- PO detail → `Record receipt` navigation
- runtime service wiring and routes

Live mode reads only RLS-visible Purchase / Inventory data and posts only through `post_purchase_goods_receipt`; the client does not directly insert GRNs, stock transactions or stock ledger rows.

## Verified regression coverage

Database CI `38698026706`: **success**

Purchase GRN assertions verify:

- real PO lifecycle (draft → lines → approved → receipt)
- accepted-only inventory effect; rejected quantity has zero ledger impact
- new batch creation and supplier-batch linkage
- multi-serial receipt with +1 rows and serial warehouse/location reconciliation
- fully received PO closure
- exact idempotent replay after PO closure
- idempotency conflict rejection
- sibling-warehouse denial for a warehouse-scoped user
- over-receipt rollback with no stock side effect
- server-side audit creation

Flutter CI `38698026608`: **success**

- `flutter analyze --fatal-infos`: no issues
- **75/75 tests passed**
- GRN request/tracking/location validation
- preview no-fake-mutation behavior
- PO → GRN navigation
- live-capable repository-boundary post
- all previously accepted FactoryOS regressions remain green

## Explicitly pending

This milestone does **not** mean the Purchase module is production-deployed.

Pending:

- dedicated FactoryOS Supabase project creation / connection
- deployment of schemas and RPCs to that project
- real JWT / Data API / RLS / RPC verification in Supabase
- security and performance advisors
- controlled FactoryOS test-user / membership / role provisioning
- real supplier invoice/document storage if required
- scanner / camera assisted receiving
- broader Purchase create / approval / supplier-management mutation workflows
- full deployed Purchase → GRN → Inventory → Production E2E QA

`janseva-production` was not used or modified.
