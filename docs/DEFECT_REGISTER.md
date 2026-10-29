# FactoryOS — QA Defect Register

**Purpose:** Consistent cross-session defect evidence. Empty register means **no defects recorded here**, not “no defects in product.” Source-of-truth bugs may also live in GitHub issues.

## Open defects recorded in this register
_No new runtime test was performed while authoring this handbook. Existing unresolved production blockers are tracked in [../status.md](../status.md) and GitHub issue #12, #27, #45 and #47._

## Defect template
| Field | Record |
| --- | --- |
| ID | QA-YYYYMMDD-NNN |
| Source | Issue/PR or tester |
| Severity | P0 safety/data/tenant; P1 critical workflow; P2 UX/accessibility; P3 polish |
| Exact SHA/build | Immutable commit, environment/version |
| Role/tenant/factory | Fictional IDs or redacted internal reference |
| Device/browser | Model, OS, viewport, accessibility setting |
| Preconditions | Safe test dataset and account setup without credentials |
| Steps | Minimal repeatable steps |
| Expected vs actual | What must happen / what happened |
| Evidence | Sanitized screenshot/video/CI/log URL |
| Status | Open / In progress / Fixed pending retest / Verified / Reopened |
| Owner and fix PR | Link to actual commit |
| Retest | Exact head SHA, date, outcome, independent tester |

## Bug workflow
Confirm → classify → reproduce → assign → fix with regression → independently retest → close. Never erase previous failed evidence; attach new result. A blocked/unreproducible case stays labeled accurately, not auto-passed.
