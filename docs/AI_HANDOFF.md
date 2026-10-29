# AI agent cross-session handoff protocol

## Objective
Any future AI assistant or developer must be able to resume FactoryOS from repository truth, choose the next safe task, execute it, prove the result, and leave a precise trail. **Chat memory is supplementary, never a deployment credential or test report.**

## Mandatory cold-start sequence

1. Confirm target repository is **`dkfutureai-alt/factory`** and inspect default branch, branch head SHA, open PRs, issues and latest changes. Refuse accidental cross-application edits.
2. Read [../AGENTS.md](../AGENTS.md), [../agent.md](../agent.md), [../status.md](../status.md), [INDEX.md](INDEX.md), [ARCHITECTURE.md](ARCHITECTURE.md), [PRODUCTION_GO_LIVE_CHECKLIST.md](PRODUCTION_GO_LIVE_CHECKLIST.md).
3. Confirm current code paths, schemas/migrations, tests and CI. For production-related questions, independently inspect dedicated FactoryOS Supabase; never infer status from the dated `agent.md` snapshot.
4. Reconcile evidence conflicts: current source/CI/runtime win over historic Markdown. Write discrepancies explicitly.
5. Identify highest-risk unfinished, dependency-safe task and relevant issue, then define measurable acceptance criteria.
6. Implement a small change with a regression test. Do not resume by duplicating a recently merged patch.
7. Validate exact branch SHA, open PR with test evidence, and distinguish pending vs approved. Never merge or deploy if checks/permissions are missing.
8. Update work log, [../status.md](../status.md) and context files **only after verified changes**. Leave a precise next action.

## AI team roles and responsibilities

| Role | Responsibilities | Required deliverables |
| --- | --- | --- |
| Architect | Tenant/data boundaries, integration, performance, versioned decisions | ADR, scoped design, risk list |
| Senior Flutter developer | Admin and mobile workflows, state and repositories, maintainability | Code, widget/unit tests, screenshots |
| Backend/PostgreSQL engineer | SQL, RLS, RPC authorization, ledger consistency, migrations | SQL tests, rollback/roll-forward plan |
| Security reviewer | Threat model, secrets, cross-tenant adversarial cases | Negative-test evidence, severity |
| QA lead | Scenario matrix, device and staging acceptance | Reproduction and pass/fail records |
| International UI/UX lead | Journeys, state specs, responsive design, localization | Screen specs and design review |
| Motion designer | Interaction timing, feedback, reduced-motion support | Token decisions, reduced-motion checks |
| DevOps/release manager | Reproducible CI, secrets, backup and protected deployment | Approved run IDs, restore and smoke proof |
| Product owner / pilot lead | Scope and customer consent, acceptance | Prioritized issues, consenting pilot evidence |

An AI assistant may simulate role-based review but **must never imply a named real employee or external team actually reviewed or tested** without proof.

## Knowledge persistence format

Every completed task should have:
- `Date/time IST`, original and final exact SHA, branch/PR, issue, feature and affected paths.
- `Implemented`: concrete behavior and diff.
- `Verified`: exact command/job URL, test counts, outcome, environment and real device identification if any.
- `Not verified`: explicit gaps, unavailable hardware, skipped tests, unknown environment state.
- `Risks/decisions`: ADR references, user-visible behavior and compatibility.
- `Next task`: precise, small, dependency-ordered next step with files and acceptance checks.

Use [STATUS_PROTOCOL.md](STATUS_PROTOCOL.md) rather than optimistic percentage estimates. Keep product/customer secrets out of logs and descriptions.

## "Continue until complete" operational interpretation

Make substantial forward progress **within this execution**. On blockers, do not loop blindly or promise unscheduled background execution. Finish non-destructive source/test/doc tasks, identify the exact external approval needed, and stop safely. A scheduled status check does not imply implementation or successful deployment.

## Conflict and ownership policy

- Code and actual runtime beat docs; if a source decision conflicts with the design request, document and fix deliberately.
- Respect existing PR branches. Recheck head SHAs before mutations and avoid duplicate concurrent fixes.
- No production database, auth, Edge Functions, customer contacts, Firebase or release configuration changes without approved FactoryOS-only workflows.
- Do not modify the other products, even if similarly named files/credentials are discoverable.
- For multi-org mobile, stay fail-closed until server, client, notification and deep-link isolation are all proven.
- Source-level success, on-device success and pilot acceptance must remain separate gates.

## Ready-to-use continuation prompt

> Resume FactoryOS only in `dkfutureai-alt/factory`. Read AGENTS.md, agent.md, status.md and docs/INDEX.md. Verify latest main SHA, open PRs/issues, named exact-SHA CI and current FactoryOS-only environment. Select the highest-impact safe unresolved issue; implement and test an atomic change; open a reviewable PR; report evidence by status tier. Preserve RLS, immutable ledger, serial custody integrity and release approvals. Update docs/WORK_LOG.md and status.md with truth only. Do not touch other apps or claim live/device/pilot acceptance without real proof.
