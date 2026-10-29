# FactoryOS — Professional Engineering Standards

**Applies to:** architects, Flutter engineers, backend/PostgreSQL engineers, security, DevOps and AI coding agents. **First read [AGENTS.md](AGENTS.md), [agent.md](agent.md), [status.md](status.md).**

## Working contract
1. Read live `main` HEAD, open PRs/issues, relevant screens/schema, exact CI and release context; do not assume prior chat completion.
2. State one scoped, reversible feature objective and risk. Explore existing architecture before writing duplicate screens/components/RPCs.
3. Implement on isolated branch, with tests and brief design/change notes; do not overwrite other agents' unmerged work.
4. Maintain smallest readable modules; typed domain boundaries; immutable data where practical; predictable state/error handling.
5. Run applicable tests; review CI on **exact PR commit**. Any red check is failure; any unrun check is unknown.
6. PR review → authorized merge → verify **merged main SHA**, then update `status.md`, `agent.md`, associated issue and `docs/WORK_LOG.md` with truthful evidence.
7. Never use production secrets, live migrations, production seeds or client outreach except through approved release processes.

## Architecture guardrails
- `apps/admin_web`: admin-only features; server authorization and factory-scoped queries; owner/manager roles only as policy permits.
- `apps/mobile`: employee/driver/technician workflows; trusted user ID at all async boundaries, workspace-aware push routing; fail-closed multi-org.
- `packages/factoryos_core`: canonical roles, module visibility and visual tokens; avoid per-screen divergent theme definitions.
- `supabase/migrations`: append strictly ordered SQL versions, review backward compatibility and guarded transactional semantics; never edit previously applied migrations to mimic history.
- `supabase/functions`: explicit JWT/role authorization and account/device validation, constrained secrets, safe logs, idempotent retries.
- Stock always derives from immutable Inventory ledger; production, quality, sales, fleet/returnable intake and maintenance updates must reconcile.
- For gas QR/cylinder events, distinguish **identity, attestation, actual ledger movement and physically verified custody**. Do not conflate them.

## Code review checklist
- Authorization in database/RPC, not just UI? Factory/tenant IDs enforced server-side?
- Input constraints, validation, user-error messages, idempotency, optimistic concurrency and audit trail?
- Loading, empty, offline, stale, partial, error, revoked permission and retry paths?
- Nullability, async cancellation/epoch protections, cleanup, mounted checks and background handling?
- Localization-ready text, touch targets, accessibility, RTL/200% text and reduced motion?
- No sensitive PII/secrets in Git, logs, screenshots or test evidence?
- Test at least success + denial + retry/duplicate + cross-tenant boundary, as applicable?
- Reuse [ui-ux.md](ui-ux.md) and [motion.md](motion.md) standards; accept measured performance not animation alone.

## Development definition of done
**A feature is done at source/CI level only** when: traceable requirement, functional admin/mobile flow, migrations/RLS, tests, mock/real differentiation, accessibility/visual acceptance, updated documentation and exact-head CI are all recorded. **Deployed/accepted** requires independent environment and real-user proof. See [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md).
