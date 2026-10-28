# Phase 28 — exact-head database integration release gate

FactoryOS production database deployment now **fails closed** until the checked-out manual release commit has a completed, successful **Supabase Foundation Checks** workflow run for the *same SHA on the main push event*. Historical passes from an old commit, PR-only checks, another branch or another workflow do not authorize a new production release.

## Source implementation

- `.github/workflows/supabase-foundation.yml` runs the full local Supabase migration/schema/RLS/Auth/JWT/business E2E suite after **every push to main**, not only when a database migration changes. PR changes to schema, scripts and both production/foundation workflow files also trigger coverage.
- `.github/workflows/supabase-production-release.yml` grants its short-lived GitHub token read-only Actions access and executes `scripts/require_exact_head_database_ci.py` immediately after checkout and **before** project linking, migration-history checks, `supabase db push`, function-secret operations or function deployment.
- The script verifies `GITHUB_REPOSITORY=dkfutureai-alt/factory`, the `refs/heads/main` dispatch ref, a well-formed SHA, and the GitHub API's **current main HEAD**. It then queries the GitHub REST workflow-runs endpoint with `head_sha` and `branch=main` and insists on the latest matching `push` run being `completed/success`.
- Any missing/failed/in-progress/cancelled CI, changed main branch head, API outage or malformed response **blocks** production deployment. GitHub API redirects are rejected, and no token or response body is printed.
- `scripts/tests/test_require_exact_head_database_ci.py` exercises synthetic success, failure, old SHA, wrong repository, wrong branch, PR-only CI, stale-success/latest-failure, malformed run identity and missing evidence; release-workflow regression tests verify the gate precedes any database writes.

## Operational procedure

1. Review/merge the proposed source changes only with green exact PR-head lint and offline tests.
2. After merge, check that **Supabase Foundation Checks** has completed successfully on the **resulting main SHA**, including the local migration replay and SQL/JWT integration suite. A successful release-tool lint alone is insufficient.
3. Set GitHub environment `factoryos-production` with required reviewers and `main` branch protection, dedicated credentials and an independently confirmed project ref `zevrmvhnibztbxizswgu`. The human release owner must validate the separate backup, isolation, migration-review and recovery requirements.
4. Manually run **Supabase Production Release** with `confirm=DEPLOY`, `release_scope=database-only`, and the independently retyped exact FactoryOS project reference. The workflow verifies current main and full database CI first; then its existing migration-version/history preflight and dry-run execute before any write.
5. Run approved authenticated/post-deployment RLS smoke, two-organization test identities, security advisors, SMTP/FCM and customer/device acceptance before claiming go-live.

No production project is configured or deployed by merging this source change. In particular, a *local Supabase test replay* is not remote migration approval or production acceptance. Never substitute Salon or Janseva credentials and never run `supabase db reset` against production.
