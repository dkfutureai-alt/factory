# FactoryOS two-tenant live Auth/RLS smoke (read-only)

**Status:** Tooling prepared, **not run against production**. The live FactoryOS project has no deployed application migrations or Auth users at the last verified checkpoint.

## Before execution (release owner only)

1. Deploy only approved FactoryOS schema migrations and verify Data API grants/RLS on the dedicated project `zevrmvhnibztbxizswgu`. Never use Janseva or Salon resources.
2. Configure protected GitHub environment `factoryos-production`, required reviewers and a main-branch restriction.
3. With explicit consent, create two distinct pilot organizations with at least one active real factory each. Provision distinct, least-privilege Auth test users with exactly one active organization membership each, and no membership in the other organization.
4. Add these protected environment secrets (never place passwords in chat, issues or Git): `FACTORYOS_SUPABASE_URL`, `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`, `FACTORYOS_TENANT_A_SMOKE_EMAIL`, `FACTORYOS_TENANT_A_SMOKE_PASSWORD`, `FACTORYOS_TENANT_B_SMOKE_EMAIL`, `FACTORYOS_TENANT_B_SMOKE_PASSWORD`. The URL must equal `https://zevrmvhnibztbxizswgu.supabase.co`; never use a service-role key.
5. Manually start GitHub Actions → **FactoryOS Cross-Tenant Production Smoke** on `main`, type `VERIFY_TENANTS` and independently type `zevrmvhnibztbxizswgu`. Obtain protected-environment approval.

## Coverage and limits

Each user signs in with its own Auth JWT, confirms its own identity and unique active membership, and reads at least one active factory within its organization. The test verifies **both directions** of denial for foreign `organizations`, `organization_members`, and `factories` over the authenticated Data API. Unexpected access, missing own factory, multiple memberships, missing secrets and errors fail closed. The separate standard production smoke now rejects an empty factory response or a different organization's factory.

The script has no customer mutations or seed data. It does not prove write authorization, all module-specific RLS rules, inventory custody, complete role/factory restrictions, email invitations, FCM, APNs, device camera, offline behavior, app store approvals, or real-user acceptance. Do not manufacture test identities or fake PASS reports.

## Evidence and sign-off

Record the Actions run URL, commit SHA, release owner, real consent, execution date and pass/failure outcome. Keep JWTs, emails and passwords out of shared evidence. Run additional consented user-role, physical device, cross-factory and forbidden-mutation acceptance workflows. Follow `docs/PRODUCTION_GO_LIVE_CHECKLIST.md` before any claim of production readiness.
