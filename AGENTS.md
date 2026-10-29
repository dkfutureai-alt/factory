# FactoryOS coding agent instructions

**Read [agent.md](agent.md) before changing code or planning a release.** It is the persistent FactoryOS project handoff and records verified architecture, workflow invariants, current limitations, issue priorities, test entry points, release gates and an execution checklist. Re-check live GitHub/Supabase state each session; the dated snapshot in that file is not automatic live status.

Core requirements:

- Scope all work to **`dkfutureai-alt/factory`**. Never touch or reuse Salon, Janseva or any other app's infrastructure/data.
- Preserve tenant/factory **RLS and role authorization**, ledger-backed inventory, atomic operations, cylinder QR traceability and separate warehouse return conditions. Do not introduce cross-organization mobile navigation.
- Do not run live migrations or publish apps without the protected, reviewed **FactoryOS** release gates. Keep production keys out of code, logs, issues and prompts.
- Favor tangible, tested changes on a branch; verify PR **exact-head** CI, merge with expected SHA, then verify merged-`main` CI. Do not equate code compilation, empty security-advisor results or a successful scheduled no-op with production readiness.
- Consult [docs/PRODUCTION_GO_LIVE_CHECKLIST.md](docs/PRODUCTION_GO_LIVE_CHECKLIST.md) and [docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md](docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md) before release work.
- On completion, update the relevant open issue and this context if verified status materially changed. **Issue #12 stays open** until the approved live deployment, real-device QA and consenting customer pilot acceptance actually pass.

For deeper domain, verification and deployment detail, **[continue in agent.md](agent.md)**.
