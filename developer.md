# FactoryOS — senior engineer / technical lead charter

> Apply the existing constraints in [AGENTS.md](AGENTS.md), [agent.md](agent.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and [docs/ENGINEERING_STANDARDS.md](docs/ENGINEERING_STANDARDS.md). This charter is for future AI developers and humans; it does not grant production credentials.

## Engineering outcomes

- Design backwards from real factory transactions and failure conditions.
- Preserve server-enforced organization/factory authorization, PostgreSQL RLS, audited RPCs and immutable ledger-based quantities.
- Keep UI → repository/service → authorized RPC/storage boundaries clear; Flutter widgets do not own privileged business rules.
- Enforce idempotency, explicit transaction states, concurrency protection, rollback, validation and audit trail.
- Treat testing, accessibility and maintainability as part of a feature, not optional follow-up.
- Favor existing architecture/patterns over gratuitous package adoption or rewrite.
- Use technical decisions/ADRs for any new dependency, schema break, architecture change or data-migration risk.

## Implementation routine

1. Read current code, schema, tests, open issues, actual latest PRs and CI; record the base SHA.
2. Define job-to-be-done, actors, roles, invariants, failure modes and measurable acceptance criteria.
3. For visual features, write screen-state spec and obtain a design review before changing shared UI components.
4. Add a failing test, implement the smallest correct change, add security and boundary regressions.
5. Run format, analyze, unit, widget, integration/SQL/Auth and lint checks applicable to touched files.
6. Confirm tenant isolation, no sensitive logging, no unbounded data reads and no breaking migration history.
7. Open a reviewable PR with before/after evidence, limitations and precise rollout/rollback steps.
8. Only mark status advanced when same-SHA proof exists. No automatic production deploy without protected owner review.

## Definition of Done per feature

- [ ] Requirements / design accepted, accessibility and localization considered.
- [ ] Strong types, predictable state, typed failures, loading/empty/error/success and disconnected cases.
- [ ] Server authorization/transactional invariants enforced and adversarial tests pass.
- [ ] No fabricated KPIs or hardcoded customer data; secrets stay outside the repo.
- [ ] Tests include negative, boundary, race and retry cases.
- [ ] UX/motion reviewed on multiple screen sizes; performance budget observed.
- [ ] CI green for the **exact** PR commit, human review complete, status/work log updated.
- [ ] Device/staging/live/pilot categories accurately separated.

Read the complete rules and PR checklist in [docs/ENGINEERING_STANDARDS.md](docs/ENGINEERING_STANDARDS.md).
