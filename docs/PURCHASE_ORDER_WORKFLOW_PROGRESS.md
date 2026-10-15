# FactoryOS Purchase Order Creation & Approval Progress

Status: **REPOSITORY / LOCAL-POSTGRESQL VERIFIED**

Accepted runtime/code head: `e003b170fc66109d2aa5ddf1713573f42e4f03d4`

This checkpoint completes the repo-side Purchase Order authoring and approval workflow. It is not a deployed-Supabase or production-completion claim.

## Design

- Design 53: `designs/53_purchase_order_editor.svg`
- Design 54: `designs/54_purchase_order_approval.svg`
- Business flow: create draft → edit commercial lines → submit → approval review → approve/reject → approved PO → GRN.
- Submission freezes the commercial document. Rejection returns the PO to draft with the reason preserved for correction.

## Authorization model

- `purchase.manage` is required at the exact factory scope to create, edit and submit a Purchase Order.
- `approval.act` is required at the exact factory scope to approve or reject.
- Knowing another factory or tenant UUID is never sufficient to authorize a command.
- Authenticated clients do not receive direct write access to PO headers, PO lines or workflow command receipts; mutations go through audited RPC commands.

## PostgreSQL workflow

Implemented through:

- `supabase/schemas/04c_purchase_order_workflow_commands.sql`
- `supabase/schemas/04d_purchase_order_audit_action_fix.sql`
- `supabase/schemas/04e_purchase_order_decision_audit_fix.sql`

Commands provide:

- atomic draft creation and line creation;
- atomic draft replacement with optimistic `revision` checking;
- stable idempotency receipts for create/update/submit/approve/reject network retries;
- idempotency-key conflict rejection when a key is reused with a different payload;
- draft-only line mutation enforcement;
- mandatory non-empty line set before submission;
- active same-tenant supplier/item validation;
- expected-delivery validation;
- explicit submit lifecycle audit action;
- approval/rejection audit actions with validated enum conversion;
- rejection reason enforcement;
- exact-factory authorization for authoring and decisions.

## Flutter integration

Added and connected:

- typed Purchase Order workflow models and validation;
- mutation-disabled preview repository;
- Supabase Purchase Order workflow repository using only the workflow RPC boundary for writes;
- responsive Purchase Order editor;
- approval review surface and pending approval queue;
- Purchase dashboard → Create PO navigation;
- pending PO → approval review navigation;
- selected approved PO → GRN navigation with the selected PO number preserved;
- stable client idempotency keys across retries and optimistic revision handling.

Long factory, supplier and item labels are constrained inside responsive dropdown fields so narrow/mobile layouts remain exception-free.

## Verified database coverage

Database CI run `38717704718`: **success** on accepted code head `e003b170fc66109d2aa5ddf1713573f42e4f03d4`.

The Purchase Order workflow regression verifies:

- authorized draft creation;
- atomic line replacement;
- optimistic revision conflict rejection;
- submission freeze;
- approval and rejection transitions;
- exact retry idempotency;
- idempotency payload conflict protection;
- direct authenticated DML denial;
- empty-draft submission denial;
- unauthorized warehouse-role authoring denial;
- cross-factory approval denial;
- complete create → update → submit → approve/reject audit evidence.

All earlier schema/seed/RBAC/RLS, Notifications, Warehouse/Dispatch, Production, Inventory Stock Entry and Purchase GRN database gates remain green in the same run.

## Verified Flutter coverage

Flutter CI run `38717704697`: **success** on the same accepted code head.

- `flutter analyze --fatal-infos`: **no issues**.
- **81/81 tests passed**.
- PO draft request totals/validation regression passed.
- Preview PO workflow is proven mutation-disabled.
- Purchase dashboard → Create Purchase Order regression passed.
- Pending approval queue → approval review regression passed.
- Live-capable editor save → submit repository-boundary regression passed.
- Live-capable approve decision repository-boundary regression passed.
- All previously accepted FactoryOS Flutter regressions remain green.

## Still pending before production acceptance

- No dedicated FactoryOS Supabase project has been created or connected.
- These migrations/RPCs have not yet been exercised through a real FactoryOS Supabase JWT/Data API session.
- Real Supabase RLS/RPC/cross-tenant verification and security/performance advisors remain pending.
- Controlled production-like FactoryOS test-user, membership and role provisioning remains pending.
- Supplier-management mutations and broader Purchase document/storage features remain pending.
- Full deployed Purchase → GRN → Inventory → Production E2E QA remains pending.
- `janseva-production` was not used or modified.
