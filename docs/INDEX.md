# FactoryOS engineering knowledge base

This index is the durable starting point for future ChatGPT, coding agents, QA, UX and release owners. **Source code and verified runtime evidence outrank documentation snapshots.**

## Read first, in order

1. [AGENTS.md](../AGENTS.md) — hard safety boundaries; [agent.md](../agent.md) — architecture, last verified state, blockers and execution contract.
2. [status.md](../status.md) — status ladder and current known blockers.
3. [AI_HANDOFF.md](AI_HANDOFF.md) — exact resume protocol for agents and multi-session continuity.
4. [WORKFLOWS_AND_ROLES.md](WORKFLOWS_AND_ROLES.md) — core factory end-to-end scenarios and role coverage.
5. [ENGINEERING_STANDARDS.md](ENGINEERING_STANDARDS.md) and [developer.md](../developer.md) — implementation and code review.
6. [TEST_STRATEGY.md](TEST_STRATEGY.md) and [tester.md](../tester.md) — automated/manual/security tests.
7. [UI_UX_PLAYBOOK.md](UI_UX_PLAYBOOK.md), [ui-ux.md](../ui-ux.md) and [ACCESSIBILITY_LOCALIZATION.md](ACCESSIBILITY_LOCALIZATION.md) — design quality.
8. [MOTION_SYSTEM.md](MOTION_SYSTEM.md) and [motion.md](../motion.md) — interaction and animation contracts.
9. [PRODUCTION_GO_LIVE_CHECKLIST.md](PRODUCTION_GO_LIVE_CHECKLIST.md), [FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md](FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md), [UAT_PILOT.md](UAT_PILOT.md) — actual release and customer acceptance gates.
10. [STATUS_PROTOCOL.md](STATUS_PROTOCOL.md), [DECISION_LOG.md](DECISION_LOG.md) and [INCIDENT_RUNBOOK.md](INCIDENT_RUNBOOK.md) — durable evidence, decisions and production issues.

## Existing primary documents

- [ARCHITECTURE.md](ARCHITECTURE.md) and [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) are existing source-of-truth architecture and visual direction.
- [WORK_LOG.md](WORK_LOG.md) contains dated engineering history; update it after verified source changes.
- Individual `PHASE_*.md` files capture specific features, limitations and earlier acceptance evidence.
- GitHub issues [#12](https://github.com/dkfutureai-alt/factory/issues/12), [#27](https://github.com/dkfutureai-alt/factory/issues/27), [#45](https://github.com/dkfutureai-alt/factory/issues/45), [#47](https://github.com/dkfutureai-alt/factory/issues/47) are current high-level unresolved work as last checked on 2026-10-29.

## Truth hierarchy

**Live inspected environment + exact-commit CI/results > current code/schema > reviewed PR/issues > dated documentation > conversational memory.** Never fill a missing test run, customer result, or deployment approval from a prior chat statement.
