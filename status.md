# FactoryOS — Project Status and Evidence Ledger

**Snapshot:** 2026-10-29 IST | **Repo:** [dkfutureai-alt/factory](https://github.com/dkfutureai-alt/factory) | **Audited main:** `d1f1c64fbd59b179dd3ddae2ed1f01313a5b8b52`
**Production decision:** **NOT READY / GO-LIVE BLOCKED.** This is a dated engineering snapshot, not an auto-updating dashboard.

## Evidence hierarchy (never collapse these states)
1. **Planned:** described only; no completed implementation evidence.
2. **Source implemented:** code/SQL exists at a named Git SHA.
3. **CI verified:** named tests and checks succeeded for that exact SHA.
4. **Staging deployed:** exact artifact/schema deployed to a distinct approved testing environment.
5. **Production deployed:** owner-approved release on dedicated FactoryOS resources with environment evidence.
6. **Real-device validated:** physical device/real hardware evidence and defects recorded.
7. **Customer accepted:** consented pilot outcomes, role/tenant security and release owner sign-off recorded.

Mark each independently; CI passing is not equivalent to deployed, real-device-tested or accepted. Blank and unknown mean **not verified**, never pass.

## Audited snapshot
| Area | Source/CI evidence | Deployment / acceptance | Next proof |
| --- | --- | --- | --- |
| Core app and business modules (Phases 1–15) | In `README.md` and phase docs, code implemented and local CI validated | No production acceptance evidenced by this review | Re-run exact-head checks and live role workflows |
| HR, Inventory, Production, Quality, Purchasing/Sales, Warehouse | Admin/mobile, SQL and test sources exist | Real deployed usage not evidenced | Authenticated role and ledger reconciliation tests |
| Fleet, dispatch, driver delivery/POD, returnables, maintenance | Source workflows and local regression coverage recorded | Physical delivery/return cycle not signed off | Actual driver handset, customer POD, cylinder pickup/warehouse receipt |
| Reports, notification inbox, FCM outbox, security | Source code, SQL, scripts and CI gates | FCM provider acceptance is not handset receipt | Real notification tap, permission and account-switch tests |
| Gas cylinder/Dura QR, serial registry, attestation (Phases 21–33) | Migrations 0047–0052, SQL tests and docs; `main` includes 0052 | Mandatory serialized custody and physical inspection **not** complete | Safety specialist review, real scan/label and per-cylinder handoff reconciliation |
| Android/iOS and Admin release | Release workflows and native projects exist; PR #18 carries additional unmerged mobile visual QA changes | Signing, real-device acceptance, App/Play store readiness unverified | Device matrix and approved signed artifact |
| FactoryOS production Supabase | Separate `factoryos-production` project ref recorded in `agent.md`; isolated source CI verified | Last documented state: zero applied migrations / zero application tables. **Not re-read from Supabase in this documentation task** | Owner-reviewed staging plan, approved release, exact environment query |
| Customer pilot | Opt-in source workflow, protected acceptance checks and timestamp safeguards exist | No verified genuine two-organization customer acceptance | Consented tester results and independent real workflow evidence |

### Exact recent GitHub evidence (verified 2026-10-29)
- Main commit: [d1f1c64](https://github.com/dkfutureai-alt/factory/commit/d1f1c64fbd59b179dd3ddae2ed1f01313a5b8b52), Phase 33 gas serial source integrity.
- Main-push **Supabase Foundation Checks**: [run 40808243750](https://github.com/dkfutureai-alt/factory/actions/runs/40808243750) — success for that head.
- Main-push **Release Workflow Lint**: [run 40808243779](https://github.com/dkfutureai-alt/factory/actions/runs/40808243779) — success for that head.
- Open source/release reviews: [PR #18](https://github.com/dkfutureai-alt/factory/pull/18) (mobile visual QA/preview, not assumed merged), [PR #1](https://github.com/dkfutureai-alt/factory/pull/1) (historical foundation, verify supersession).
- Go-live issue [#12](https://github.com/dkfutureai-alt/factory/issues/12), serialized custody [#27](https://github.com/dkfutureai-alt/factory/issues/27), multi-organization mobile [#45](https://github.com/dkfutureai-alt/factory/issues/45) and [#47](https://github.com/dkfutureai-alt/factory/issues/47) must be reviewed live.

## Priority backlog (no fabricated percent-complete)
| ID | Priority | Work | Done only when |
| --- | --- | --- | --- |
| P0-01 | BLOCKER | Protected FactoryOS database staging, backup/restore proof, approved 0001–0052 migration history | Exact owner plan/release evidence + live migration verification |
| P0-02 | BLOCKER | Live Auth/RLS/RPC and two-tenant isolation, including negative role tests | Real signed-in test identities, denied cross-tenant access and logs |
| P0-03 | BLOCKER | Admin HTTPS hosting, invites/SMTP, Firebase FCM/APNs and trusted notifications | Deployed URLs and physical device outcomes |
| P0-04 | BLOCKER | Real Android/iOS install, QR scanning, offline/retry, motion/accessibility, performance QA | Recorded device build, screenshots/video, pass/fail |
| P0-05 | BLOCKER | Genuine consent-based pilot and release owner sign-off | Two organizations, required scenarios, real results, issue #12 closed only after proof |
| P1-01 | HIGH | Fully mandatory gas serial custody, safety/inspection and ledger reconciliation | Every physical transaction enforces accepted handoff; safety review |
| P1-02 | HIGH | Multi-org mobile selection | All mobile RPCs, data repositories, caches and push routes proven scoped; until then **fail closed** |
| P1-03 | HIGH | International design and motion fidelity improvements | Approved screen specs, reduced motion, accessibility and actual device QA |
| P2-01 | MEDIUM | Localized strings, RTL, regional formatting, offline UX polish | Locale-specific screen/flow regression reports |

## Update contract
Every working session must update this file **only for new verified evidence**: audit date/time, commit SHA, exact tests/runs, environment, device, defect ID, issue/PR, change, blocker, next safe action. Preserve historical failures in `docs/WORK_LOG.md` and decisions in `docs/DECISIONS.md`. If only docs change, say **documentation only**. Never declare 100% complete without the go-live checklist.
Read [agent.md](agent.md), [docs/PROJECT_HANDBOOK.md](docs/PROJECT_HANDBOOK.md) and [docs/HANDOFF_TEMPLATE.md](docs/HANDOFF_TEMPLATE.md) before continuing.
