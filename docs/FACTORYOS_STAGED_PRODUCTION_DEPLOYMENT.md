# FactoryOS staged production deployment

**Status on 28 Oct 2026:** The standalone FactoryOS Supabase project is created and healthy, but its public application tables, migration history and Edge Functions have not been deployed. Do not mark the app production-live. This playbook intentionally excludes Janseva and Salon resources.

## 1. Production database foundation (independent of Firebase/SMTP)

Target: **FactoryOS only**, project ref `zevrmvhnibztbxizswgu`, Mumbai `ap-south-1`, API URL `https://zevrmvhnibztbxizswgu.supabase.co`.

In GitHub repository Settings, configure **Environment** `factoryos-production` with required reviewers and branch restriction `main`. Add protected secrets: `SUPABASE_ACCESS_TOKEN`, `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_DB_PASSWORD`, `FACTORYOS_SUPABASE_URL`. Use the *exact* FactoryOS target; obtain the project DB password and API token in their respective authenticated dashboards. Never paste them in chat, publish them, or commit them.

**Required two-step production release (from the same immutable main commit):**

1. Owner reviews the 0001–0053 migration SQL, the backup/recovery options, current DB state and protected environment. Open GitHub Actions → **Supabase Production Plan** on `main`. Type `confirm=PLAN` and independently type `confirm_project_ref=zevrmvhnibztbxizswgu`. The plan job requires environment approval; it links the exact FactoryOS project, validates committed migration versions/history, and runs **only** `supabase db push --dry-run`. The plan does **not** apply migrations, seed customer data or deploy functions.
2. **Read the successful plan run's logs**, including the migration history and SQL pending list, and record the run ID and SHA. After explicit owner approval, within **24 hours**, open GitHub Actions → **Supabase Production Release** on the exact same `main` commit. Supply `confirm=DEPLOY`, `confirm_project_ref=zevrmvhnibztbxizswgu`, `approved_plan_run_id=<reviewed plan run ID>`, and first choose `release_scope=database-only`. A read-only GitHub API check verifies that the run **and its actual named planning job** both finished successfully (a skipped job is not accepted), belong to the same repository/workflow, target `main`, use the exact current commit, and are fresh. Missing, stale, failed, wrong-commit or wrong-repository plans block deployment before linking or writing the database.
3. The separately protected production release repeats migration version/history checks and `db push --dry-run`, applies pending committed migrations with `supabase db push`, then **verifies postdeployment migration history before any Edge Function deployment**. Re-run and review the plan for any new commit or expired plan; do not reuse old run IDs.

**Never run `supabase db reset` against production.** Do not use MCP `apply_migration` for the existing 0001–0053 files: it generates a different timestamp/version and risks divergent migration history. A successful dry-run is necessary but cannot prove absence of unrelated schema drift or substitute for a backup/recovery plan. Do not share GitHub tokens or Supabase credentials in issues or chat.

Verify the production schema and RLS via Supabase Advisors and an isolated test organization. Migration `0045_explicit_data_api_grants.sql` supplies explicit foundation Data API grants and denies anonymous access; migration `0046` adds segregated returnable warehouse intake, `0047` provides serial/QR cylinder identity with inspection evidence, `0048` adds auditable serial-to-Inventory transaction attestations and `0049` exposes read-only coverage gaps, and `0050` rejects unsafe customer-issue **serialized attestations** when the individual cylinder/Dura is held, quarantined, uninspected or overdue. Migration `0051` stamps pilot feedback report dates on the database server to prevent client-forged recency. Migration `0052` prevents privileged serialized link rows from misrepresenting an original Inventory movement's type, item, location or whole-unit capacity. **Proposed `0053`** adds public release-policy reads and platform-owner-only writes: inspect anonymous grants, real-JWT write denial, HTTPS links and fail-open client behavior before owner approval; its presence in source does not authorize a live deployment. Check all nine migrations and their read grants/RLS with authorized accounts; `0050` does **not** stop quantity-only Dispatch without a scan. Never equate serial attestations with complete customer custody. Confirm a PostgREST authenticated core-table query succeeds and cross-tenant reads remain denied; Supabase 2026 new-project defaults do not expose tables automatically (https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically). No fictional production customer rows should be seeded.

## 2. Function and customer-access deployment

First configure Auth Site URL and strict HTTPS redirect allowlist, custom SMTP for real invitations, and unique FactoryOS Firebase/FCM credentials. Set the additional protected secrets: `FACTORYOS_INVITE_REDIRECT_URL`, `NOTIFICATION_DISPATCH_SECRET`, `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`.

Run the **same** protected workflow with `release_scope=full` and retyped exact ref. It applies any *remaining* migrations and only then sets Edge Function secrets/deploys the functions. Verify `invite-user` fails closed for missing redirect, and test SMTP invitation to a consenting real test address.

## 3. Admin hosting and release artifacts

Publish the Flutter Admin app using the separately gated **Admin Production Release** workflow and the FactoryOS publishable key. Add GitHub Pages origin to Supabase redirect allowlist before invitations. Use the approved `/factory/` base href and test desktop/mobile login.

For Android/iOS, use the existing unsigned release build checks; actual Android AAB signing and iOS App Store upload require dedicated signing credentials. FCM/APNs must be tested on real phones; a successful CI build is not proof of push delivery.

## 4. Consented real-user acceptance

Create two separate client organizations and factories *with explicit owner approval*. Invite **consenting** testers with their actual email, name, role and assigned factory. Test role isolation across HR, stock ledger, production, quality, purchasing/sales, warehouse, vehicles, dispatch/POD, customer empty-cylinder pickup, condition-segregated warehouse intake and maintenance. Verify Sales cannot allocate uninspected receiving/quarantine returns. Test individual cylinder/Dura registration, scan, visual inspection, retirement and the Phase 21B serial-to-ledger transaction links against actual prior receipts and vehicle movements; verify 1-unit capacity, wrong QR, unauthorized staff, and missing POD rejection. Require physical scan/transaction reconciliation before marking serialized custody complete. Open mobile Profile → Customer pilot; tester agrees, runs relevant workflows, and submits pass/fail/blocked feedback. Organization admins review Pilot Testing. Never fabricate customers or test results.

Keep issue #12 open until actual pilot passes, SMTP and FCM deliver on real devices, storage/RLS is checked, hosting and backups are validated, and the release owner signs off.

## Current external blockers

- Protected GitHub environment and production credentials require the account owner.
- Firebase/FCM app and iOS APNs setup require the relevant account.
- Customer testing needs opted-in customer identities; no real users have been invited yet.
- Production domain, SMTP and mobile store signing are not yet confirmed.

## Phase 27B required two-organization RLS proof

The protected `Production Smoke Verification` now additionally requires two approved, non-platform-owner Supabase Auth test users (`FACTORYOS_SMOKE_EMAIL`/`FACTORYOS_SMOKE_PASSWORD` and `FACTORYOS_SMOKE_SECOND_EMAIL`/`FACTORYOS_SMOKE_SECOND_PASSWORD`) in different populated test organizations. Each account must see its own active factory and be denied the other's organization, membership and factory records. These **read-only** checks use the exact FactoryOS project only, require separate owner provisioning, and do not prove module-wide or real customer/device E2E. See `docs/PHASE_27B_PRODUCTION_TWO_TENANT_SMOKE.md`.
