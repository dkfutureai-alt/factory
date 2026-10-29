# FactoryOS — agent / developer handoff (`agent.md`)

> Read this file before continuing FactoryOS. Keep it aligned with the **verified**
> repository, connected project and GitHub CI; do not treat an old status line
> as current truth. For tool-based agents, `AGENTS.md` is the canonical entry point.
> **Do not declare deployment or a real customer pilot complete from source CI.**

## Project identity and intended product

- GitHub: https://github.com/dkfutureai-alt/factory
- Product: FactoryOS — multi-tenant, white-label factory management and operations.
- Apps: `apps/admin_web` (Flutter Admin), `apps/mobile` (Flutter staff, supervisor and driver),
  `packages/factoryos_core` (shared roles, policy and design components).
- Backend: Supabase/Postgres SQL migrations, Row Level Security (RLS), Auth,
  Storage and Edge Functions; Firebase/FCM for mobile push.
- Flow: Purchase → Goods Receipt → Inventory ledger → Production → Quality →
  Warehouse → Sales allocation → Dispatch → Vehicle/driver → Customer POD →
  Empty-cylinder return → vehicle stock → condition-based warehouse intake;
  plus HR/attendance, leave, fuel, fleet, maintenance, notifications,
  audit/security, reports and customer pilot feedback.
- Never replace actual ledger transactions with UI-only counters; client
  organizations, factories, roles and records must be properly isolated.
  Cylinder/Dura serial attestation is **not** a complete custody or safety
  certification. Never infer a live customer or proof of delivery from test seeds.

## Repository map

| Directory / file | Purpose |
|---|---|
| `apps/admin_web` | Admin Flutter UI; org/factory management and operating modules |
| `apps/mobile` | Staff/supervisor/driver Flutter mobile UI |
| `packages/factoryos_core` | Shared domain/UI and RBAC helpers |
| `supabase/migrations/0001_*.sql` – `0049_*.sql` | Database, permissions, ledger and production workflows |
| `supabase/functions/invite-user` | Auth invitations and onboarding |
| `supabase/functions/send-notifications` | FCM push dispatch |
| `supabase/tests` | Isolated SQL and real Auth/JWT end-to-end regression suite |
| `scripts/tests` | Offline safety/release/pilot unit tests |
| `.github/workflows` | Automated CI and explicitly gated manual production workflows |
| `docs/PRODUCTION_GO_LIVE_CHECKLIST.md` | Complete human release acceptance checklist |
| `docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md` | Exact protected migration plan/deploy sequence |
| `docs/PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md` | 2-org, 14-scenario read-only real pilot evidence |
| `docs/PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md` | Free-plan secure backup, restore rehearsal, limitations |

## Last independently verified snapshot — 29 October 2026, 06:50 IST

**Refresh all of these before making claims**:

- Last inspected `main` HEAD:
  `8a0ed21f4a657bd7ad5bcb5970fb77c210c99e70` (push dispatch failure hardening, PR #59).
- GitHub CI on that exact SHA: Supabase Foundation Checks, Release Workflow
  Lint and Release Candidate succeeded. Flutter/Mobile Quality succeeded
  on preceding PR #57 HEAD; recheck current SHA before relying on them.
- Dedicated **only** FactoryOS production Supabase project:
  `zevrmvhnibztbxizswgu`, region `ap-south-1`, API
  `https://zevrmvhnibztbxizswgu.supabase.co`.
- At last connected read-only check: project `ACTIVE_HEALTHY`,
  but **0 public application tables, 0 applied migrations / migration history,
  0 Auth users and 0 deployed Edge Functions**. It is NOT production-ready.
- Supabase organization is on **Free** plan: no automatic managed daily
  backups or PITR entitlement. Real customer onboarding requires a secure
  offsite logical backup and a witnessed isolated restore drill, or an
  explicitly approved upgraded recovery capability.
- Connected Windows Desktop Commander device `DESKTOP-BVHU6H8` was
  offline; do not claim Windows or physical mobile tests passed.
- Open release blocker: https://github.com/dkfutureai-alt/factory/issues/12.
- Historical foundation / mobile draft PRs #1 and #18 are open; examine
  branches, diffs and present CI **before** merging or replacing main.
- **Other apps are off-limits.** Salon, Janseva, their staging/production,
  Firebase and customer data must not be changed to finish FactoryOS.

## Mandatory engineering and release safety

1. Inspect live `main` SHA, open PRs, exact-head checks, relevant files, connected Supabase status and
   latest GitHub issue #12. Avoid overwriting another agent's concurrent
   change; branch from current main and rebase/recreate if the head moves.
2. Make a specific code change; write corresponding synthetic test or
   isolated database test; run **actual CI**; review exact final PR head
   before merging. Report individual failed, skipped, cancelled and pending
   checks truthfully. Postmerge CI is a separate verification step.
3. Never use remote `supabase db reset` or arbitrary production DDL. Do not
   apply the existing migrations through MCP `apply_migration`; it changes
   migration-history versions. Supabase migrations must be committed and
   applied in sequence via protected CLI workflows.
4. Keep service-role/`sb_secret_` keys and DB passwords out of
   Flutter/public clients, Git, logs, issues, tests and this file.
   Data API use publishable key + JWT + explicit grants + RLS.
   Privileged SQL functions require scoped auth and fixed search paths.
5. Manual release workflows are **main-only** and use GitHub environment
   `factoryos-production` with owner-appointed reviewers, real secret
   configuration and retyped exact project confirmation. Do not assume a
   workflow succeeded if its gated job was skipped.
6. The order is: protect secrets/backup policy → full exact-main database CI
   → run read-only **Supabase Production Plan** (`confirm=PLAN`) →
   owner inspect successful exact-SHA plan job, SQL and migration history →
   **Supabase Production Release** (`confirm=DEPLOY`,
   `release_scope=database-only`, fresh `approved_plan_run_id`
   within 24 hours) → confirm migrations, RLS, Data API and restore path →
   configure Auth/SMTP/FCM → protected function/Admin/Android release →
   production smoke → consenting real pilots on actual devices → owner sign-off.
7. Production smoke (`.github/workflows/production-smoke.yml`) needs
   two different, non-platform-owner scoped users in populated orgs and
   positive own-factory reads, reciprocal cross-tenant denial.
   Pilot acceptance (`.github/workflows/production-pilot-acceptance.yml`)
   needs explicit opt-in in two real organizations, most recent *passed*
   reports for 14 scenarios (within 14 days), and positive operational
   records and reciprocal tenant isolation. **Never seed fake customer
   data to satisfy production checks.**
8. No claims of production readiness without independently recorded recovery
   exercise, real staff roles, physical QR/cylinder custody checks, real FCM
   and SMTP delivery, signed Android artifacts/iOS ownership and witnessed
   client acceptance. Keep issue #12 open until evidence is complete.

## Fast validation commands (only in isolated/local environments)

```bash
# Offline Python release guards (no customer data/network)
python3 -m unittest discover -s scripts/tests -v

# Local Supabase Docker-backed reproducibility (destructive to LOCAL test DB)
python3 scripts/check_migration_versions.py
supabase start
supabase db reset
supabase db lint --level error -s public

# Local SQL tests. Never replace the local host here with a live FactoryOS DB!
for test_file in supabase/tests/*.sql; do
  psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
    -v ON_ERROR_STOP=1 -f "$test_file"
done
```

Use the existing CI workflow `.github/workflows/supabase-foundation.yml`
for the full real Auth/JWT/PostgREST transaction suite; it also runs Deno
Edge Function checks. UI/mobile CI workflows are
`flutter-quality.yml` and `mobile-release-quality.yml`.
No bare `supabase db reset` without confirming local context first;
never pass `--linked` to reset.

## Ongoing workflow / next owner actions

- First unblock **owner-approved FactoryOS production resources**, NOT
  repeat local CI indefinitely. Confirm the protected GitHub environment,
  exact project-specific secrets and human migration reviewer; do not ask
  users to share passwords or tokens in chat.
- Establish viable backup/restore plan per Phase 30, including Auth and
  Storage objects and independent offsite recovery. Record RPO/RTO,
  encryption/retention and a *real isolated restore proof*.
- Validate the complete migration plan and apply the database-only release
  through its two-step protected workflow. This is not authorized merely by
  a general instruction to "continue": privileged production operations
  still require the protected owner/reviewer gate and reviewed plan.
- Then run live JWT/RLS smoke; configure distinct Firebase, SMTP, and
  domain/hosting, signed mobile builds; onboard **only consenting**
  pilot testers; test negative paths/roles and the entire physical
  cylinder movement and returnable workflows; record proof.
- Document each verified milestone and blocker in issue #12 and update
  this handoff when *verified reality* materially changes.

## Agent response standard

State: **what was inspected, exactly what was changed/merged, CI evidence
against which SHA, what was NOT tested, and next external blocker**.
When the repository is unchanged, do not imply work shipped.
Never claim background work or make up mobile-device or customer results.
