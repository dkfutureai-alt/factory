# FactoryOS Phase 16 — Production workflow safeguards

Manual production workflows are restricted to `main` and require human confirmation. Supabase release, Android release and Admin publishing require an independently entered exact Supabase project ref. Production smoke and Admin build jobs require the `factoryos-production` environment.

**Owner setup required:** GitHub Settings > Environments > `factoryos-production`: require reviewers and restrict deployment branches to `main`. The name alone does not enforce approvals. Configure `github-pages` separately. Never use another application's Supabase/Firebase credentials.

## Verification

Run `python3 -m unittest discover -s scripts/tests -v` and `actionlint .github/workflows/*.yml`, then verify CI on the final PR SHA. Migration `0043` must be applied before the updated invitation function. These source checks do not replace real email, FCM, device, customer or release tests.

## Dedicated project pin (28 October 2026)

Every manual production path (database migration, authenticated smoke, Admin publishing, signed Android bundle) now rejects even a self-consistent, correctly typed reference unless it is the dedicated FactoryOS project `zevrmvhnibztbxizswgu`. The scheduled push worker enforces the same fixed target *before* sending its dispatch secret, and production release-candidate builds refuse unrelated Supabase API origins. Staging candidates remain separately configurable.

The project reference is public configuration, **not** a secret. Changing the FactoryOS production project intentionally requires a reviewed code change to the pinned reference, fresh validation and production environment approval. The safety gate does not configure missing GitHub environment approvals/secrets, run production migrations, or prove live authentication and device workflows.
