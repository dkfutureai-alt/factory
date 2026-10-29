# FactoryOS — Professional Team Collaboration and Review Process

## Development lanes
1. **Product/domain:** define roles, critical industrial-gas flow, observable customer result and safety assumptions.
2. **Architecture/backend:** document data model, exact tenant/factory security, transaction atomicity, idempotency and migrations.
3. **Flutter/Admin:** build actual states using shared theme/components; never fake committed operations.
4. **UI/UX:** design screens, compare screenshots, responsive/accessibility/localization review.
5. **Motion:** spec trigger/timing/interruption and reduced-motion fallback; confirm 60fps-target device behavior without sacrificing battery.
6. **QA/security:** independently test negative cases, stock reconciliation, session/tenant isolation and release hazards.
7. **Release/documentation:** review PR exact-head CI, issue state and owner approvals; update handoff/evidence.

## PR review rubric (score each Pass / Fail / Not run)
**Functionality, authorization, data integrity, resilience/retries, test coverage, visual hierarchy, accessibility, reduced motion, localization, performance, secrets, migration safety, documentation and rollback.** Required specialist approval cannot be substituted by an AI self-review.

## Conflicts and parallel agents
Read current head and open PRs first. Reserve specific files/issue, avoid same-branch conflicting writes, reconcile changed head before updating. UI direction is shared, but do not refactor all modules while delivering a narrow security fix. When exact-head CI goes red, fix it before promoting; do not mark other red checks green by association.
