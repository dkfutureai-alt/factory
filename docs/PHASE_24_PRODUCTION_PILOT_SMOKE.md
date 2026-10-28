# Production customer-pilot API smoke coverage (Phase 24)

The guarded `Production Smoke Verification` workflow now executes a **read-only** test of `pilot_participants` and `pilot_feedback` in the *approved FactoryOS target only*, after the human typed-project confirmation and real smoke-account sign-in.

For both tables it performs an authenticated REST `GET`, requiring a successful JSON array (including an empty array), then makes an unauthenticated publishable-key `GET` and requires a 4xx denial. It **never signs up or enrolls a tester**, never submits feedback, and never modifies real factory data.

This catches missing Data API table grants, missing Phase 17 migrations, incorrect public-table privileges and broken API exposure in the actual deployed project. It does **not** prove cross-tenant RLS for two populated organizations, actual email invitation delivery, FCM notifications or real device behavior. Those still require authorized consenting customer pilots.

This check cannot run successfully until the protected GitHub production secrets, Supabase migrations and dedicated smoke identity exist. It will not run on mere source merge. Because the job uses `factoryos-production` protected environment, `main` restriction and typed project ref, it cannot silently target Salon or Janseva.

## Phase 27B coverage extension

The protected production smoke now additionally runs `scripts/production_tenant_isolation_smoke.py` with two distinct approved test identities and populated independent organizations. It positively verifies each account can read its own organization and an active factory, while refusing cross-organization reads of core organizations, memberships, factories and factory-membership records. This remains source-only until actual protected smoke execution; it does not replace full customer/pilot verification. See `docs/PHASE_27B_PRODUCTION_TWO_TENANT_SMOKE.md`.
