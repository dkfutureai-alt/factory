# FactoryOS Production Go-Live Checklist

> Applies only to the FactoryOS project. Never reuse the Salon, Janseva or other application's Supabase/Firebase resources.

## Release ownership and environment

- [x] Create the dedicated FactoryOS Supabase project `zevrmvhnibztbxizswgu` in Mumbai (`ap-south-1`), under the approved organization; initial quoted cost $0/month (verified 26 Oct 2026).
- [ ] Verify current billing plan and backup capabilities before customer onboarding. API endpoint: `https://zevrmvhnibztbxizswgu.supabase.co`.
- [ ] Set a protected GitHub environment named `factoryos-production` with required reviewers; restrict it and production workflow dispatches to `main`.
- [ ] Set `SUPABASE_ACCESS_TOKEN`, `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_DB_PASSWORD`, `FACTORYOS_SUPABASE_URL`, `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`, and `FACTORYOS_INVITE_REDIRECT_URL` as repository/environment secrets. Never commit service-role or DB credentials.
- [ ] Verify `FACTORYOS_SUPABASE_URL` resolves to precisely the configured project ref, not just to any valid Supabase project.

## Authentication, database and storage

- [ ] Verify explicit 2026 Supabase Data API grants from migration `0045`, not legacy defaults: authenticated table reads obey tenant/factory RLS; anonymous users have no public-table privileges; trusted service role can perform its authorized server-only operations. Check an actual PostgREST authenticated read.

- [ ] Configure Auth Site URL, allowlisted invitation redirects, and a functional custom SMTP provider.
- [ ] Create a dedicated least-privilege production smoke identity and set `FACTORYOS_SMOKE_EMAIL` and `FACTORYOS_SMOKE_PASSWORD` secrets.
- [ ] Verify FactoryOS Free-tier recovery limits: no included managed automatic daily database backups or PITR. Approve owner, RPO/RTO, frequency, encrypted offsite retention and keys. Follow `docs/PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md`; do not reuse Salon/Janseva resources.
- [ ] Witness and document an **actual isolated restore** of role/schema/data plus separately protected Auth identity, actual Storage objects, migration history, private-file integrity, tenant RLS and operational reconciliation. If incomplete, do not onboard real customers.
- [ ] Confirm `scripts/check_no_private_backups.py` CI guard rejects accidentally tracked backup filenames; this is not a replacement for encrypted offsite backup or real restoration.
- [ ] Verify the final PR's Flutter, Mobile Release, Supabase Foundation and Release Workflow Lint checks are green.
- [ ] On the exact current green `main` SHA, manually run the protected read-only **Supabase Production Plan** (`confirm=PLAN`, exact typed FactoryOS ref), review the migration history and pending dry-run output, and record its successful run ID. Obtain owner approval. A successful workflow with a skipped planning job is not accepted.
- [ ] Within 24 hours on the same SHA, manually run **Supabase Production Release** with `confirm=DEPLOY`, the typed FactoryOS project ref and `approved_plan_run_id`. The release checks **both** exact-head Supabase Foundation CI and the real successful planning job via GitHub API before remote SQL writes; otherwise it blocks.
- [ ] Apply migrations through `0052` (including 0043 invitation reissue, 0044 customer pilot, 0045 explicit Data API grants, 0046 returnable warehouse intake, 0047 serialized cylinder/Dura identity, 0048 serial-to-Inventory transaction attestations, 0049 serial evidence coverage, **0050 inspected/non-expired customer-issue serial attestation guard** and **0051 server-stamped customer pilot feedback chronology** and **0052 source-of-truth cylinder link integrity**) through the **protected** `Supabase Production Release` workflow, first with `release_scope=database-only`. Confirm recorded migration history matches the committed files; never run remote `db reset` or production fictional seeds.
- [ ] Verify migration `0052` rejects a forged transfer label for a real issue, cross-item/location claims, fractional quantities and over-capacity serial evidence, while retaining valid attestation; see `docs/PHASE_33_GAS_SERIAL_SOURCE_INTEGRITY.md`. Privileged consistency is not a substitute for mandatory physical scans or real custody.
- [ ] With a consenting pilot manager, verify migration 0050 denies *serialized customer-issue attestations* for uninspected, quarantined or overdue assets while allowing controlled quarantine transfers. This gate is **not** a substitute for mandatory pre-dispatch scanning, pressure-test certification, real custody records or physical-device acceptance; keep issue #27 open until those are separately proven.
- [ ] After an approved HTTPS Auth redirect, SMTP and Firebase secrets are configured, run the same workflow with `release_scope=full` to deploy the Edge Functions, then verify private POD/Maintenance storage policies and production RLS.
- [ ] Inspect Supabase security/performance advisors and fix actionable findings before onboarding customers.
- [ ] Execute the read-only `Production Smoke Verification` checks for `gas_container_assets`, `gas_container_asset_events`, `gas_container_transaction_links` and the scoped `gas_serial_attestation_coverage` RPC, requiring signed-in authorized reads and explicit anonymous denial. Do not register real containers as a substitute for pilot acceptance.
- [ ] Validate Phase 21A serial/QR registration, inspection, quarantine and retirement, plus Phase 21B verified scan-to-Inventory transaction attestations with actual factory staff. Compare each ledger quantity with assigned serial count and investigate missing scans; quantity-based operational posting remains possible without a serial link. Separately verify physical custody and QR readability; identity or attestation alone is neither stock transfer nor pressure-test/compliance release.

## Push delivery

- [ ] Register `com.dkappsstudio.factoryos` separately for Android and iOS in the intended Firebase project.
- [ ] Set Android/iOS Firebase app-specific defines and configure `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` and `NOTIFICATION_DISPATCH_SECRET`.
- [ ] Configure iOS APNs key and entitlement with the same app team/Bundle ID.
- [ ] Check sign-in → token registration → received notification → correct authorized deep link → sign-out disables token, including a shared device changing users.
- [ ] Set `FACTORYOS_SUPABASE_PROJECT_REF`, its exact matching `FACTORYOS_SUPABASE_URL` and `NOTIFICATION_DISPATCH_SECRET` for scheduled dispatch. Confirm all-missing configuration safely skips, partial/mismatched configuration fails without outbound calls, and the configured job reaches only the approved FactoryOS project.
- [ ] After merge and release configuration, verify scheduled `Notification Push Dispatch` succeeds; scheduling is best effort and may be delayed by the GitHub Actions service.

## Admin and mobile

- [ ] Configure Pages or approved static web hosting and confirm Supabase Auth redirect allowlist includes its URL.
- [ ] Run **Admin Production Release** from `main` with `confirm=PUBLISH`, independently typed `confirm_project_ref`, correct `base_href` (repository default: `/factory/`), and an approved FactoryOS target. Verify Admin sign-in and workspace access.
- [ ] Supply production Android keystore, key alias and signing credentials from the release owner; require release signing. Run **Android Production Bundle** with `confirm=BUILD` and the exact typed FactoryOS project ref.
- [ ] Confirm package ID, release version, signing identity, and generated AAB checksum before any Google Play upload.
- [ ] Configure Apple Developer Team ID, production signing, App Store Connect and final iOS capability/provisioning. The CI `--no-codesign` build is **not** an App Store deliverable.
- [ ] Prepare privacy policy, store listing, data-safety/privacy declarations and a support contact before submitting.

## Acceptance and rollback

- [ ] Run **Production Smoke Verification** with `confirm=VERIFY` and exact typed FactoryOS project ref; require authenticated smoke membership and successful scoped factory read.
- [ ] Test with real authorized pilot accounts: invitations, factory assignment, attendance, purchasing/receipts, Inventory ledger, Production/Quality, sales allocation, Warehouse, dispatch/POD/customer returnables **and completed vehicle-to-warehouse intake**, Fleet/fuel, Maintenance, reporting, notifications and audit access.
- [ ] Confirm migration `0051` overrides forged client-provided `pilot_feedback.created_at` dates, then verify the 14-day latest-report acceptance window with real consenting pilot users. User self-reports alone do not establish operational success; see `docs/PHASE_32_PILOT_FEEDBACK_TIMESTAMP.md`.
- [ ] After two distinct consenting organizations complete genuine workflows, execute the protected **FactoryOS Real Customer Pilot Acceptance** (`confirm=VERIFY_PILOT`, separately typed FactoryOS ref). Require latest passed reports for all 14 scenarios per pilot admin, actual visible operational records, and reciprocal Data API tenant denial. See `docs/PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md`. This read-only gate is **not** a replacement for device/role/manual outcome validation.
- [ ] Verify returned cylinders route from the vehicle to receiving/quarantine by condition; check original vehicle stock debit, no double-intake on retry, inspection gate and rejection of Sales allocation from receiving/quarantine.
- [ ] Include cross-tenant and cross-factory denial tests; confirm a low-privilege user cannot mutate manager-only records.
- [ ] Confirm no customer-facing dashboard displays fictional seed data.
- [ ] Record a release owner, test evidence, deployment time, app/web commit SHA and smoke results.
- [ ] Prepare web rollback to the prior artifact; database schema recovery requires a planned, forward-compatible migration or a verified backup/restore procedure — never assume reversing a Git commit reverses applied database migrations.

**Release decision:** only mark FactoryOS production complete when the actual project is deployed, smoke and pilot workflows pass, store/platform credentials are operational, and the release owner signs off. Repository-only CI is necessary but not sufficient.

- [ ] Configure `FACTORYOS_SMOKE_SECOND_EMAIL` and `FACTORYOS_SMOKE_SECOND_PASSWORD` for a second scoped test account in a different owner-approved test organization (both accounts must see their own active factory). Run the protected two-organization read-only RLS smoke and retain evidence before releasing to real customers. See `docs/PHASE_27B_PRODUCTION_TWO_TENANT_SMOKE.md`.

- [ ] Before any protected production database release, confirm the **current main SHA** has a completed successful `Supabase Foundation Checks` **push** run. The exact-head workflow gate fails closed for stale/failed/in-progress/PR-only database CI; see `docs/PHASE_28_EXACT_HEAD_DATABASE_RELEASE_GATE.md`.

- [ ] Verify Phase 27C scoped FCM payload and navigation behavior: matching signed-in user + organization may open an authorized route; mismatched, legacy-unscoped or stale cold-start pushes must not navigate. Verify shared-device sign-out and refresh-token races with real Android/iOS hardware after the updated Edge Function is deployed. See `docs/PHASE_27C_SCOPED_PUSH_NAVIGATION.md`.

- [ ] Deploy the Phase 29 `send-notifications` worker before enabling scheduled push dispatch. Validate `claimed/processed/sent/failed/skipped` accounting, ensure a failed row fails GitHub dispatch, verify real handset receipt independently, and retain evidence; a green skip/empty queue does not certify notifications. See `docs/PHASE_29_PUSH_DISPATCH_ACCOUNTABILITY.md`.

- [ ] Verify Phase 30 shared-device Auth/bootstrap isolation on actual Android and iOS devices: user A sign-in/load → account change/sign-out during pending requests → user B in same or different organization; stale workspace/module/QR data and pushed Navigator routes must clear. Test resumed app after membership/factory-role revocation, signed-out access denial and same-user token refresh without disrupting active work. See `docs/PHASE_30_MOBILE_AUTH_WORKSPACE_LIFECYCLE.md`.
