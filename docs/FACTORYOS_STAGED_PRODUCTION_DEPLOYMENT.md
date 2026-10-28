# FactoryOS staged production deployment

**Status on 28 Oct 2026:** The standalone FactoryOS Supabase project is created and healthy, but its public application tables, migration history and Edge Functions have not been deployed. Do not mark the app production-live. This playbook intentionally excludes Janseva and Salon resources.

## 1. Production database foundation (independent of Firebase/SMTP)

Target: **FactoryOS only**, project ref `zevrmvhnibztbxizswgu`, Mumbai `ap-south-1`, API URL `https://zevrmvhnibztbxizswgu.supabase.co`.

In GitHub repository Settings, configure **Environment** `factoryos-production` with required reviewers and branch restriction `main`. Add protected secrets: `SUPABASE_ACCESS_TOKEN`, `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_DB_PASSWORD`, `FACTORYOS_SUPABASE_URL`. Use the *exact* FactoryOS target; obtain the project DB password and API token in their respective authenticated dashboards. Never paste them in chat, publish them, or commit them.

After the release owner reviews all migration files and verifies zero customer tables/data, open GitHub Actions → **Supabase Production Release** on `main`. Supply `confirm=DEPLOY`, `confirm_project_ref=zevrmvhnibztbxizswgu`, `release_scope=database-only`. The workflow will check the protected environment and secrets, link the exact project, run `supabase db push --dry-run`, apply the committed migrations in version order with `supabase db push`, and display `supabase migration list`. **Never run `supabase db reset` against production.** Do not use MCP `apply_migration` for the existing 0001–0046 files: it generates a different timestamp/version and risks divergent migration history.

Verify the production schema and RLS via Supabase Advisors and an isolated test organization. Migrations `0045_explicit_data_api_grants.sql` and `0046_returnable_warehouse_intake.sql` explicitly exposes only the intended authenticated foundation operations, denies anonymous public-table access and grants trusted server-side service-role DML. Confirm a PostgREST authenticated core-table query succeeds and cross-tenant reads remain denied; Supabase 2026 new-project defaults do not expose tables automatically (https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically). No fictional production customer rows should be seeded.

## 2. Function and customer-access deployment

First configure Auth Site URL and strict HTTPS redirect allowlist, custom SMTP for real invitations, and unique FactoryOS Firebase/FCM credentials. Set the additional protected secrets: `FACTORYOS_INVITE_REDIRECT_URL`, `NOTIFICATION_DISPATCH_SECRET`, `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`.

Run the **same** protected workflow with `release_scope=full` and retyped exact ref. It applies any *remaining* migrations and only then sets Edge Function secrets/deploys the functions. Verify `invite-user` fails closed for missing redirect, and test SMTP invitation to a consenting real test address.

## 3. Admin hosting and release artifacts

Publish the Flutter Admin app using the separately gated **Admin Production Release** workflow and the FactoryOS publishable key. Add GitHub Pages origin to Supabase redirect allowlist before invitations. Use the approved `/factory/` base href and test desktop/mobile login.

For Android/iOS, use the existing unsigned release build checks; actual Android AAB signing and iOS App Store upload require dedicated signing credentials. FCM/APNs must be tested on real phones; a successful CI build is not proof of push delivery.

## 4. Consented real-user acceptance

Create two separate client organizations and factories *with explicit owner approval*. Invite **consenting** testers with their actual email, name, role and assigned factory. Test role isolation across HR, stock ledger, production, quality, purchasing/sales, warehouse, vehicles, dispatch/POD, customer empty-cylinder pickup, condition-segregated warehouse intake and maintenance. Verify Sales cannot allocate uninspected receiving/quarantine returns. Open mobile Profile → Customer pilot; tester agrees, runs relevant workflows, and submits pass/fail/blocked feedback. Organization admins review Pilot Testing. Never fabricate customers or test results.

Keep issue #12 open until actual pilot passes, SMTP and FCM deliver on real devices, storage/RLS is checked, hosting and backups are validated, and the release owner signs off.

## Current external blockers

- Protected GitHub environment and production credentials require the account owner.
- Firebase/FCM app and iOS APNs setup require the relevant account.
- Customer testing needs opted-in customer identities; no real users have been invited yet.
- Production domain, SMTP and mobile store signing are not yet confirmed.
