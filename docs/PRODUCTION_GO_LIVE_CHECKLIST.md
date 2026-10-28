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
- [ ] Confirm database backup/PITR capabilities for the chosen plan, record a recovery owner and trial a restore in a nonproduction environment where supported.
- [ ] Verify the final PR's Flutter, Mobile Release, Supabase Foundation and Release Workflow Lint checks are green.
- [ ] Confirm pending migration list and assess any destructive SQL before manually invoking **Supabase Production Release** with `confirm=DEPLOY` and a separately typed `confirm_project_ref`.
- [ ] Apply migrations through `0047` (including 0043 invitation reissue, 0044 real customer pilot, 0045 explicit Data API grants and 0046 returnable warehouse intake and 0047 serialized gas container identity) through the **protected** `Supabase Production Release` workflow, first with `release_scope=database-only`. Confirm recorded migration history matches the committed files; never run remote `db reset` or production fictional seeds.
- [ ] After an approved HTTPS Auth redirect, SMTP and Firebase secrets are configured, run the same workflow with `release_scope=full` to deploy the Edge Functions, then verify private POD/Maintenance storage policies and production RLS.
- [ ] Inspect Supabase security/performance advisors and fix actionable findings before onboarding customers.
- [ ] Execute the read-only `Production Smoke Verification` checks for `gas_container_assets` and `gas_container_asset_events`, requiring signed-in authorized reads and explicit anonymous denial. Do not register real containers as a substitute for pilot acceptance.
- [ ] Validate the Phase 21A serial/QR registration, inspection, quarantine and retirement with real factory staff, and separately verify actual per-cylinder custody, physical QR readability and safety review; identity-only recording is not stock or compliance release.

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
- [ ] Verify returned cylinders route from the vehicle to receiving/quarantine by condition; check original vehicle stock debit, no double-intake on retry, inspection gate and rejection of Sales allocation from receiving/quarantine.
- [ ] Include cross-tenant and cross-factory denial tests; confirm a low-privilege user cannot mutate manager-only records.
- [ ] Confirm no customer-facing dashboard displays fictional seed data.
- [ ] Record a release owner, test evidence, deployment time, app/web commit SHA and smoke results.
- [ ] Prepare web rollback to the prior artifact; database schema recovery requires a planned, forward-compatible migration or a verified backup/restore procedure — never assume reversing a Git commit reverses applied database migrations.

**Release decision:** only mark FactoryOS production complete when the actual project is deployed, smoke and pilot workflows pass, store/platform credentials are operational, and the release owner signs off. Repository-only CI is necessary but not sufficient.
