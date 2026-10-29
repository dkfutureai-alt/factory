# FactoryOS — Cross-Session AI / Human Handoff Template

Copy this block into the end of each development session (or into the related PR description). It must be **truthful and complete**.

## Session identity
- Date/time (Asia/Kolkata):
- Repository: `dkfutureai-alt/factory`
- Base `main` SHA:
- Working branch / PR / final HEAD SHA:
- Environment touched: repository only / isolated CI / isolated staging / approved FactoryOS production (**choose exactly what happened**)
- Production resources mutated? **Yes/No**. If yes, owner approval and workflow proof:

## Scope and outcome
- Requirement / issue:
- Files changed:
- Business, security, accessibility, localization or motion impact:
- Status: **planned | source implemented | CI verified | staging deployed | production deployed | device verified | customer accepted** (list only verified states)

## Evidence
| Check | PASS / FAIL / BLOCKED / NOT RUN | SHA, run URL, device or environment |
| --- | --- | --- |
| Flutter analyze/tests | | |
| SQL migrations / JWT RLS cross-tenant tests | | |
| Python guard tests | | |
| Flutter Android/iOS release CI | | |
| UI/accessibility/reduced-motion review | | |
| Real Android/iOS scanner/notification/POD | | |
| Production migration/hosting/API smoke | | |
| Consented real pilot | | |

## Handoff
- Known blockers and GitHub issue links:
- Bugs opened/closed and retest proof:
- Design refs / files affected:
- Safety/rollback note:
- Next highest-value **safe executable action**:
- Required approvals, human owner or missing resources:
- Update made to `status.md`, `agent.md` and `docs/WORK_LOG.md`?:

**Never claim a test, merge, production publish, physical scan or customer response happened without source evidence.**
