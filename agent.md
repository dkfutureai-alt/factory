# FactoryOS — persistent engineering and agent handoff context

**Repository:** `dkfutureai-alt/factory` · <https://github.com/dkfutureai-alt/factory>  
**Last fact-checked:** 2026-10-29 (Asia/Kolkata). **This is an orientation document, not a live status API.** Re-check GitHub `main`, checks, issues, and the dedicated Supabase project **at the beginning of every new session**. Never trust this file alone to claim deployment or acceptance.

## 1. Non-negotiable boundaries

- Work **only** on FactoryOS (industrial gas / oxygen / manufacturing operations). **Do not modify, deploy, query, or reuse** Salon, Janseva, DK Apps Studio Factory, or other application repositories, production projects, Firebase apps, credentials, customer data, or storage.
- The intended dedicated production Supabase project is **`zevrmvhnibztbxizswgu`** (`factoryos-production`, Mumbai / `ap-south-1`); base URL **`https://zevrmvhnibztbxizswgu.supabase.co`**. This identifier is a **destination allowlist**, never an authorization token.
- Do **not** commit secrets, service-role keys, production DB passwords, Firebase private keys, phone numbers, real customer identities, or test-account credentials. Never print raw Auth/FCM payloads into CI logs or issue comments.
- No live database migration, destructive SQL, production seed, customer invitation, FCM dispatch, device enrollment, Play/App Store upload or production publish without its **separately protected owner-reviewed release workflow** and prerequisite evidence. Do not bypass GitHub environment approvals.
- Never use `supabase db reset` against any linked production project; never apply the already committed `0001`–`0052` migration series using an ad hoc MCP migration call that would create incompatible history.
- **Green source CI != live deployment != a real customer workflow passed.** Only mark a milestone accepted when supported by exact-SHA CI **and** deployment/environment evidence and actual tests for that milestone.
- An empty Supabase advisor result on an empty project proves **nothing** about future RLS, security, or performance.

## 2. Product scope and data invariants

FactoryOS supports the full industrial-gas/factory chain:

`Purchase / GRN → raw material & cylinders → Inventory ledger → Production / filling → Quality → Finished Goods → Warehouse / staging → Sales / invoicing → Dispatch → Vehicle + Driver → POD / Customer → returnable empties → segregated warehouse intake`, with HR, attendance, holidays, leave, fleet/fuel, maintenance, approval/audit, reports, pilot feedback and notifications.

Important invariants:

1. **Multi-tenancy:** every organization/factory read and write must have server-enforced membership, role and factory scope via PostgreSQL RLS and explicitly authorized RPCs. Never accept user-editable metadata as authorization.
2. **Inventory:** stock, gas receipt/consumption, quality hold/release, picking/dispatch, returns and maintenance spares must remain ledger-backed and must not fabricate quantity. Transactional multi-step operations must be atomic.
3. **Gas containers:** `0047` provides serial/QR identity and inspection lifecycle; `0048` attaches serialized scan evidence to actual Inventory transaction records; `0049` reports coverage gaps; `0050` guards serialized customer issues; `0052` rejects privileged link claims that disagree with the original Inventory type, item, location or whole-unit count. **This is not complete mandatory serialized physical custody**. Serial-to-ledger counts, safety inspection, custody chain and actual scans still require acceptance testing/possible further enforcement.
4. **Returnables:** record vehicle/customer empty-cylinder pickup separately from actual warehouse receipt; inspected good/receiving must remain separate from damaged/quarantine. No phantom restocking.
5. **Mobile multi-org and auth lifecycle:** mobile still **fails closed** if a user has multiple active organization memberships (`apps/mobile/lib/workspace_guard.dart`); do not expose a selector until **every mobile repository and privileged RPC** is properly scoped and cross-tenant tested. On a shared handset, bind bootstrap results to the exact Auth user, reset pushed routes when the account changes, re-fetch workspace permissions on resume, and discard stale asynchronous results. See `docs/PHASE_30_MOBILE_AUTH_WORKSPACE_LIFECYCLE.md` and issues **#45, #47**.
6. **Notifications:** FCM push route data requires the notification's authoritative organization and recipient IDs, checked against the live signed-in mobile workspace. Scheduled dispatch accounting must differentiate provider-accepted, skipped, failed and absent configuration. **Provider acceptance is not evidence of handset delivery**.
7. **Privacy/consent:** real pilot customers must explicitly consent; never manufacture successful user tests, copied customer datasets, verified business contacts or device results. Pilot observations and tenant isolation require live signed-in checks.

## 3. Repository map

| Path | Responsibility |
| --- | --- |
| `apps/admin_web/` | Flutter admin portal, workflows and super/organization administration |
| `apps/mobile/` | Flutter employee/driver/technician app, QR scanner, mobile workflows, notifications |
| `packages/factoryos_core/` | Shared design system, roles, module and workspace access rules |
| `supabase/migrations/` | Ordered SQL migrations `0001`–`0052` on the last checked commit |
| `supabase/functions/invite-user/` | Invitation Edge Function (Auth, redirect validation) |
| `supabase/functions/send-notifications/` | Tenant-recipient-scoped FCM HTTP v1 worker and delivery accounting |
| `supabase/tests/` | SQL integration checks and actual local Auth/JWT/RLS end-to-end shell flows |
| `scripts/`, `scripts/tests/` | Read-only release proofs, production-smoke checks, deployment guards, Python regression suite |
| `.github/workflows/` | Flutter, database, Android/iOS CI, protected releases, smoke and pilot acceptance |
| `docs/` | Architecture, staged deployment, QA, module decisions and release acceptance |

Read `README.md`, `docs/ARCHITECTURE.md`, `docs/PRODUCTION_GO_LIVE_CHECKLIST.md`, `docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md` before large changes.

## 4. Current verified environment — timestamped, not guaranteed current

As checked **2026-10-29**:

- `main` was `8a0ed21f4a657bd7ad5bcb5970fb77c210c99e70`, containing the scheduled FCM provider-failure/lease-accounting repair (PR #59). At that SHA **Supabase Foundation Checks, Release Workflow Lint and FactoryOS Release Candidate** succeeded.
- The standalone `factoryos-production` project was `ACTIVE_HEALTHY`, but **0 applied migrations and 0 `public` application tables**. No live production FactoryOS schema, functional Admin/mobile deployment or real pilot acceptance had been verified.
- The linked Windows development machine was **offline**; do not claim on-device/local desktop QA from cloud CI.
- Existing source-controlled `0001`–`0052` migrations are tested against isolated local Supabase in CI. They have **not** been applied to live FactoryOS production.
- The original implementation and more recent release/security improvements coexist. Re-verify exact results and production environment state; a later agent might have advanced the project.

This section is a *dated snapshot*: correct it when verified facts change. Never silently mark the project "FINAL READY".

## 5. Outstanding work / issue tracking

- **#12 — production go-live blockers:** owner-approved protected GitHub environment, distinct credentials, billing/backup/restore review, read-only migration plan, approved database release, Auth SMTP/redirects, correct Data API privileges, two-tenant smoke, Edge Functions/FCM/APNs, admin hosting, signed mobile artifacts, physical device QA, customer privacy/store paperwork and consenting pilot acceptance.
- **#27 — cylinder/Dura serialized custody:** real per-cylinder custody/QR transfers and lifecycle safety acceptance, reconciliation with quantity ledger, scanning/inspection exceptions, missing attestation enforcement and physical testing.
  - **Phase 31 source safeguard:** migration `0050_gas_serial_customer_issue_readiness.sql` rejects customer-issue *serialized evidence* for hold/quarantined/damaged/uninspected/expired-test containers. See `docs/PHASE_31_GAS_SERIAL_ISSUE_READINESS.md`. It does **not** stop quantity-only dispatch or establish full scanned custody, so issue #27 remains open until physically enforced and accepted.
- **#45 / #47 — multi-org mobile:** explicit selected-tenant/factory state, all repository/RPC scopes, authentication/session/revocation, cache/scan race isolation, FCM routes and regression E2E. Until ready, **single-active-membership-only**.
- The protected **real customer pilot acceptance** workflow checks two consenting organizations with valid feedback/evidence across 14 scenarios; **its existence is not proof a live pilot took place**. See `docs/PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md`.
  - **Phase 32 chronology hardening:** migration `0051_pilot_feedback_server_timestamp.sql` forces database-owned `pilot_feedback.created_at`, so submitted backdated/future-dated results cannot falsify the 14-day acceptance recency window. See `docs/PHASE_32_PILOT_FEEDBACK_TIMESTAMP.md`. Reports remain self-reported; physical verification is still required.
  - **Phase 33 serial evidence provenance:** migration `0052_gas_serial_link_source_integrity.sql` ensures *all* new serial links, including privileged service inserts, must match the authoritative Inventory transaction's tenant, factory, item, movement type, locations and whole-unit capacity. This closes a forged `transfer` label bypass of the Phase 31 customer-issue attestation readiness guard. See `docs/PHASE_33_GAS_SERIAL_SOURCE_INTEGRITY.md`. Physical scan/POD/stock-write enforcement remains unfinished.
- Some original feature issues are already closed or superseded. Always review actual open issues, PRs, recent commits and fresh CI before choosing the next change.

## 6. Source development and verification

Prefer small, reviewable changes, tests, branch → PR → **exact PR-head green checks** → merge with head-SHA lease → **post-merge main green checks**. Do not modify a branch behind concurrent commits without re-reading source SHA.

Relevant existing CI:

- `Flutter Application Quality` (`.github/workflows/flutter-quality.yml`): Flutter core/admin/mobile analysis/tests and Admin release web bundle budget.
- `Mobile Release Quality` (`.github/workflows/mobile-release-quality.yml`): Android release AAB and **unsigned** iOS release compile, not signed store uploads.
- `Supabase Foundation Checks` (`.github/workflows/supabase-foundation.yml`): migration-name checks, Deno check/tests, local Supabase startup/reset/seeds, SQL/RLS tests and real Auth/JWT/business-flow E2E. Runs on every `main` push and relevant PR changes.
- `Release Workflow Lint` (`.github/workflows/release-workflow-lint.yml`): actionlint and `python3 -m unittest discover -s scripts/tests -v`.
- `FactoryOS Release Candidate`: source validation/QA artifacts; intentionally skipped build jobs can be normal.
- **Notification Push Dispatch**: scheduled 5-minute runs; a green skip with unconfigured credentials is **not** a delivered notification.

Local commands (only in authorized isolated dev environments; confirm available CLIs and paths):

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/check_migration_versions.py
# From repository root: only local Supabase, never production
supabase start
supabase db reset
# In each package/app directory, when Flutter is installed:
flutter pub get
flutter analyze
flutter test
```

For backend changes, also run the CI suite or equivalent SQL/real Auth E2E. For UI changes, check loading/error states, accessibility, visual consistency, overflow, slow networks and physical phones when available.

## 7. Owner-reviewed staged release (never shortcut)

1. Confirm exact current `main` SHA and successful **same-commit** full Supabase Foundation integration CI.
2. Protect GitHub environment **`factoryos-production`** with required human reviewers and `main` branch restriction; configure **FactoryOS-only** GitHub secrets. Keep sensitive values in GitHub/Supabase, never in code/chat.
3. Review production billing, backup/PITR ability and actual **isolated restore rehearsal**; record recovery owner.
4. Manually invoke **Supabase Production Plan** with `confirm=PLAN` and independently typed exact ref. Inspect **successful named job**, migration-history check and `supabase db push --dry-run`; save approved run ID and source SHA.
5. On the **same main SHA** within 24 hours of an approved successful plan run, independently authorize **Supabase Production Release**, `confirm=DEPLOY`, exact typed ref, `approved_plan_run_id`, **`release_scope=database-only`**. The workflow checks same-head green DB CI and reviewed plan before writes, applies pending SQL, then checks migration history.
6. Validate live authenticated PostgREST reads, real tenant/factory RLS, explicit anonymous denials, Storage policies and Advisors. Never create dummy customers just to make a checklist green.
7. Configure approved Auth Site URL, HTTPS invitation redirects, working SMTP, independent FactoryOS Firebase Android/iOS apps, FCM service credentials and APNs; repeat approved protected full release for Edge Functions.
8. Verify **Production Smoke Verification** and **FactoryOS Real Customer Pilot Acceptance** with two consenting separate organizations, their actual workers and devices; run the real business scenarios. Separately prove signed mobile routing, actual push/SMTP delivery, physical cylinder QR and warehouse custody, Admin hosting, Android release signing and Apple distribution.
9. Only after the owner signs actual records and deployment/restore/pilot evidence, mark go-live. Otherwise leave issue #12 open and report precise blockers.

Exact instructions: `docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md`, `docs/PRODUCTION_GO_LIVE_CHECKLIST.md`, `docs/PHASE_28_EXACT_HEAD_DATABASE_RELEASE_GATE.md`, `docs/PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md`, `docs/PHASE_29_PUSH_DISPATCH_ACCOUNTABILITY.md`, and **`docs/PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md`** for secure Free-tier backup plus actual isolated restore proof. `scripts/check_no_private_backups.py` prevents accidental Git tracking of common database dumps but is **not** a backup or restore test.

## 8. Agent execution / handoff contract

For a "continue until complete" request:

1. **Inspect, don't guess:** read latest branch SHA, open issues/PRs, CI jobs and `factoryos-production` migration/table status. Report any unverified state separately.
2. Pick the **highest-impact safe outstanding issue**. Prefer a concrete implementation with regression tests over repeating roadmap text; do not duplicate changes made in another session.
3. Make changes in a scoped feature branch and test. Check the exact PR head; address failures before merge. Avoid accidental push to main or bypassing approval guards.
4. After merge, verify **the actual merged main SHA**; update `docs/PRODUCTION_GO_LIVE_CHECKLIST.md` and the relevant issue(s). Keep README and this agent context consistent with verified current behavior.
5. Use clear result categories: **source implemented / CI verified / deployed / physically tested / customer accepted**. A fact in one category does not imply the others.
6. If production reviewer permissions, unavailable secrets, disconnected hardware or absent real users prevent the next stage, **do not fabricate completion**. Finish all safe work possible in the current session, record the exact blocker and next authorized action.
7. Never leak secrets or claim to execute background work just because a scheduled GitHub workflow exists.

This file is maintained for future coding agents and is **not** a replacement for source code, tests, live GitHub or live Supabase evidence.

## 9. Durable specialist team and cross-session documentation (added 2026-10-29)

Start from [docs/INDEX.md](docs/INDEX.md), which links all specialized playbooks; its contents supplement the non-negotiable controls in this file. [status.md](status.md) is the updateable evidence register and **must not** silently reinterpret source-implemented phases as production or customer acceptance. Root fast-access role cards: [developer.md](developer.md), [tester.md](tester.md), [ui-ux.md](ui-ux.md), [motion.md](motion.md).

- **AI resume:** [docs/AI_HANDOFF.md](docs/AI_HANDOFF.md) and [docs/STATUS_PROTOCOL.md](docs/STATUS_PROTOCOL.md) define exact-SHA reinspection, evidence tiers, tests and precise future handoff.
- **Software:** [docs/ENGINEERING_STANDARDS.md](docs/ENGINEERING_STANDARDS.md) and [docs/WORKFLOWS_AND_ROLES.md](docs/WORKFLOWS_AND_ROLES.md) define code review, authorization, idempotency, ledger integrity and end-to-end business scenarios.
- **QA and pilot:** [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md) and [docs/UAT_PILOT.md](docs/UAT_PILOT.md) require isolated tests first, then physically verified and consenting pilot acceptance; they are not actual test results.
- **Design:** [docs/UI_UX_PLAYBOOK.md](docs/UI_UX_PLAYBOOK.md), [docs/MOTION_SYSTEM.md](docs/MOTION_SYSTEM.md) and [docs/ACCESSIBILITY_LOCALIZATION.md](docs/ACCESSIBILITY_LOCALIZATION.md) document international-grade screen states, responsive layouts, localization, accessibility and deliberate motion.
- **Operations:** [docs/DECISION_LOG.md](docs/DECISION_LOG.md) and [docs/INCIDENT_RUNBOOK.md](docs/INCIDENT_RUNBOOK.md) provide the ADR and incident/recovery protocol.

**Important chronology:** The 2026-10-29 session that introduced these documents observed `main` at `d1f1c64fbd59b179dd3ddae2ed1f01313a5b8b52`, newer than the dated `8a0ed21` snapshot above. It did **not** independently verify named CI on that SHA or re-read live Supabase project state. Re-check before stating production/test status. These documentation additions introduce no business behavior or remote deployment.
