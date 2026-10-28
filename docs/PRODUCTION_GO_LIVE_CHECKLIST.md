# FactoryOS Production Go-Live Checklist

> Applies only to the FactoryOS project. Never reuse the Salon, Janseva or other application's Supabase/Firebase resources.

## Release ownership and environment

- [ ] Select the dedicated FactoryOS Supabase organization, region and cost plan; get approval before creating a billable project.
- [ ] Create/connect the dedicated FactoryOS project and record its 20-character project ref and exact `https://<ref>.supabase.co` URL.
- [ ] Set a protected GitHub environment named `factoryos-production` with required reviewers; restrict it and production workflow dispatches to `main`.
- [ ] Set `SUPABASE_ACCESS_TOKEN`, `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_DB_PASSWORD`, `FACTORYOS_SUPABASE_URL`, `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`, and `FACTORYOS_INVITE_REDIRECT_URL` as repository/environment secrets. Never commit service-role or DB credentials.
- [ ] Verify `FACTORYOS_SUPABASE_URL` resolves to precisely the configured project ref, not just to any valid Supabase project.

## Authentication, database and storage

- [ ] On the new FactoryOS-only Supabase project, verify public-table Data API exposure uses explicit grants, not project-specific legacy defaults. The October 2026 Supabase privilege change means a successful migration alone is not a working Admin/Mobile API. See `supabase/migrations/0045_explicit_data_api_grants.sql` and `supabase/tests/0045_explicit_data_api_grants_smoke.sql`.

- [ ] Configure Auth Site URL, allowlisted invitation redirects, and a functional custom SMTP provider.
- [ ] Create a dedicated least-privilege production smoke identity and set `FACTORYOS_SMOKE_EMAIL` and `FACTORYOS_SMOKE_PASSWORD` secrets.
- [ ] Confirm database backup/PITR capabilities for the chosen plan, record a recovery owner and trial a restore in a nonproduction environment where supported.
- [ ] Verify the final PR's Flutter, Mobile Release, Supabase Foundation and Release Workflow Lint checks are green.
- [ ] Confirm pending migration list and assess any destructive SQL before manually invoking **Supabase Production Release** with `confirm=DEPLOY` and a separately typed `confirm_project_ref`.
- [ ] Confirm migrations through `0045` (including 0041 push outbox, 0042 structural QA, 0043 invitation reissue, 0044 opt-in customer pilot and 0045 explicit Data API grants), Edge Functions and private POD/Maintenance storage policies exist. Verify `authenticated` and `service_role` permissions plus RLS, deny `anon` access and check actual PostgREST reads; never run remote `db reset` or production fictional seeds.
- [ ] Inspect Supabase security/performance advisors and fix actionable findings before onboarding customers.

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
- [ ] Test with real authorized pilot accounts: invitations, factory assignment, attendance, purchasing/receipts, Inventory ledger, Production/Quality, sales allocation, Warehouse, dispatch/POD/returnables, Fleet/fuel, Maintenance, reporting, notifications and audit access.
- [ ] Include cross-tenant and cross-factory denial tests; confirm a low-privilege user cannot mutate manager-only records.
- [ ] Confirm no customer-facing dashboard displays fictional seed data.
- [ ] Record a release owner, test evidence, deployment time, app/web commit SHA and smoke results.
- [ ] Prepare web rollback to the prior artifact; database schema recovery requires a planned, forward-compatible migration or a verified backup/restore procedure — never assume reversing a Git commit reverses applied database migrations.

**Release decision:** only mark FactoryOS production complete when the actual project is deployed, smoke and pilot workflows pass, store/platform credentials are operational, and the release owner signs off. Repository-only CI is necessary but not sufficient.
