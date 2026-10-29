# FactoryOS — Security, Data Protection and Tenant Isolation

**Non-negotiable:** FactoryOS-only resources; never query/mutate Salon, Janseva or other customer products. Read [../agent.md](../agent.md) and [RBAC_AND_TENANCY.md](RBAC_AND_TENANCY.md).

## Controls
1. PostgreSQL RLS plus narrow authorized RPC enforcement for each organization/factory. Never trust client-provided organization ID, editable user metadata or frontend visibility.
2. Use least-privilege privileges, pinned security-function `search_path`, validated JWT identity and narrowed EXECUTE grants. Test anonymous, wrong member, wrong factory, suspended user.
3. Ledger is immutable; finance, warehouse, quality and serial evidence link to authoritative transactions. Backward compatibility and idempotent retries are mandatory.
4. Auth session: cancel/discard stale async results, clear navigation on account switch and refresh workspace role on app resume. Current multi-org mobile remains **fail closed**.
5. No production keys/passwords, private backup dumps, API tokens, personal customer data or full authentication payloads committed to Git, Markdown, bug reports or CI logs.
6. Confidential documents, POD media and QR data use scoped storage and signed access; never place private files in public buckets by convenience.
7. FCM payload and tapped route must bind recipient + authoritative org; provider-accepted ≠ handset-delivered.
8. Real-user pilot is opt-in with withdrawal, data minimization and personally identifiable information removed from public evidence.

## Before touching database
Read [../supabase/PRODUCTION_MIGRATION_RUNBOOK.md](../supabase/PRODUCTION_MIGRATION_RUNBOOK.md), confirm target project ref, inspect migration history and owner-approved rollback/restore plan. Never use `supabase db reset` on a linked production database, nor ad hoc SQL bypassing protected gates.

## Security test categories
Matrix `RLS-01`, `TEN-01` and `GAS-01` in [QA_MATRIX.md](QA_MATRIX.md); cross-factory Data API denials; role revocation; multi-user shared handset; race/retry; SQL injection; malicious redirect; private storage leak; tamper-evident audit; backup export leak. A report is valid only with an exact head SHA and test environment.
