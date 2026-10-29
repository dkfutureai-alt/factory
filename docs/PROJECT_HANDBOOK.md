# FactoryOS — AI Team Handbook and Source-of-Truth Index

**Use this first in every new chat, IDE coding agent or teammate handoff.** Only the live Git repository and approved environment evidence prove current behavior; this handbook does not confer production authorization.

## Start-here reading order
1. [../AGENTS.md](../AGENTS.md) — non-negotiable code agent instructions.
2. [../agent.md](../agent.md) — canonical persistent project context and existing release restrictions.
3. [../status.md](../status.md) — dated evidence/status ledger, blockers and next safe work.
4. [../developer.md](../developer.md), [../tester.md](../tester.md), [../ui-ux.md](../ui-ux.md), [../motion.md](../motion.md) — engineering and specialist contracts.
5. [ARCHITECTURE.md](ARCHITECTURE.md), [BUSINESS_FLOWS.md](BUSINESS_FLOWS.md), [RBAC_AND_TENANCY.md](RBAC_AND_TENANCY.md) — actual domain boundaries.
6. [QUALITY_GATES.md](QUALITY_GATES.md), [QA_MATRIX.md](QA_MATRIX.md), [UI_SCREEN_INVENTORY.md](UI_SCREEN_INVENTORY.md) — implementation/verification.
7. [PRODUCTION_GO_LIVE_CHECKLIST.md](PRODUCTION_GO_LIVE_CHECKLIST.md), [FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md](FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md) — **authoritative** production release procedures.
8. [HANDOFF_TEMPLATE.md](HANDOFF_TEMPLATE.md), [DECISIONS.md](DECISIONS.md), [DEFECT_REGISTER.md](DEFECT_REGISTER.md) — cross-session traceability.

## Agent session operating system
**Discover → Verify → Choose → Design → Implement → Test → Review → Handoff.**
- Discover exact `main` SHA, open PRs, issues, changed files, recently merged work, exact-head CI and real environment state, without assuming the previous session's branch was merged.
- Verify source vs deployed vs physical vs customer accepted in separate columns.
- Choose highest-value safe feature not already claimed by another PR. Define in-scope paths, risk, acceptance and rollback.
- Design screens before significant UI implementation; review role-specific state transitions and motion/reduced-motion.
- Implement small branches, security-first SQL, immutable ledger logic, consistent Flutter components and permission-dependent UI.
- Test success, denial, failure/offline, duplicate retries, cross-tenant and performance/accessibility.
- Review PR exact SHA checks; do not auto-merge if approvals missing or production migration is involved.
- Handoff with immutable SHA, direct proof links, unresolved defects and **single next executable action**.

## AI specialist team roles
| Role | Mandatory output |
| --- | --- |
| Product manager / factory domain expert | Acceptance criteria, workflow map, critical business invariants |
| Solution architect | ADR, data flow, tenant/factory scope, failure mode |
| Flutter mobile engineer | Role-aware screens, auth-lifecycle-safe async, test evidence |
| Flutter Admin engineer | Responsive authorized workflows and transaction affordances |
| Supabase/PostgreSQL engineer | Append-only migrations, RLS/RPC tests, transactional ledger proof |
| UI/UX lead | Screen inventory, design tokens, screenshots, accessibility |
| Motion engineer | Trigger/timing/state/reduced-motion specs and device validation |
| QA & security lead | Threat model, negative tests, defects, release assessment |
| DevOps / release manager | Exact-SHA CI, protected approval, backup, rollout and recovery evidence |
| Documentation / handoff editor | Updated status, decisions, issue/PR references, honesty audit |

No role can sign off its own unverified work on behalf of real customers. External regulator/safety authority requirements demand qualified human specialists, not an AI signoff.

## Format for every session output
**Repository + exact SHA; changed files; tests run/passed/failed/not run; affected environments; defects; review/PR link; next approved action; risks; status category.** Never use “all complete” without independently verified deployment and customer acceptance.
