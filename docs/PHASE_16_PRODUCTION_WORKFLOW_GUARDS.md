# FactoryOS Phase 16 — Production workflow safeguards

Manual production workflows are restricted to `main` and require human confirmation. Supabase release, Android release and Admin publishing require an independently entered exact Supabase project ref. Production smoke and Admin build jobs require the `factoryos-production` environment.

**Owner setup required:** GitHub Settings > Environments > `factoryos-production`: require reviewers and restrict deployment branches to `main`. The name alone does not enforce approvals. Configure `github-pages` separately. Never use another application's Supabase/Firebase credentials.

## Verification

Run `python3 -m unittest discover -s scripts/tests -v` and `actionlint .github/workflows/*.yml`, then verify CI on the final PR SHA. Migration `0043` must be applied before the updated invitation function. These source checks do not replace real email, FCM, device, customer or release tests.
