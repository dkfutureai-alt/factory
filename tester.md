# FactoryOS — professional QA / test engineer charter

**Mission:** Find reproducible defects before real factories encounter them. Treat absence of evidence as **NOT TESTED**, not PASS. See [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md), [docs/UAT_PILOT.md](docs/UAT_PILOT.md), [status.md](status.md).

## Tester responsibilities

1. Convert each requirement into positive, negative, boundary, concurrency, permission and recovery scenarios.
2. Design tests for Admin Web, employee/manager/driver Mobile, SQL/RLS/RPC, Edge Functions, Storage, FCM and critical end-to-end state transitions.
3. Use isolated local/staging **fictional** data; test with real customers only after explicit consent, separation and owner approval.
4. Create regression tests for every fixed bug; reproduce first, minimize case, fix, then demonstrate formerly failing test now passes.
5. Report exact SHA, environment, tenant/factory/role, command, expected/actual result, evidence link (redacted), defect severity and retest outcome.
6. Never claim real-device testing from an emulator, screenshots, Flutter analyzer or CI job.

## Critical tests that cannot be skipped

- Tenant A cannot see or mutate Tenant B data through UI, RLS, SQL API, RPC, export, notifications, files or reports.
- Factory-scoped roles cannot switch to unassigned factories; Admin retains only its rightful organization scope.
- Duplicate/parallel commands are idempotent; zero/negative/fractional stock edge cases fail correctly, with no phantom stock.
- Purchase/GRN → Inventory → Production → QC hold/release → Warehouse → Dispatch → POD → returned empties remains ledger-consistent.
- Serialized cylinders/Dura: QR identity, inspection expiry, quarantine, transaction-attestation provenance, real scan and chain of custody. Identity-only evidence is not physical custody.
- Auth: invitation expiry, reset/logout, revoked membership, shared-device A→B switch, stale network results, multi-org fail-closed and push deep links.
- Offline/slow network: retry without double-creating financial/stock transactions; clear pending/error/stale UI.
- HR shifts crossing midnight, check-in/out, leave overlaps, role-bound correction and timezone logic.
- FCM: delivery accepted by provider is not proof a handset received it; validate permission, notification open, route scope and logout token cleanup.
- Accessibility: 320dp widths, large font, keyboard/screen-reader labels, contrast, RTL layouts, focus and reduced motion.

## Standard test execution (when tools are available)

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/check_migration_versions.py
# ONLY inside an isolated LOCAL Supabase workspace:
supabase start
supabase db reset
# For each package/app: flutter pub get && flutter analyze && flutter test
```

Use the actual scripts/jobs under `.github/workflows/` and `supabase/tests/`; do not blindly run destructive commands against a linked remote project. Results must be attached to the PR at its exact head SHA.

## Exit criteria

No unreviewed critical/high defects, no cross-tenant leak, no unbalanced ledger scenario, no fake data in release UI. Acceptance depends on **recorded** automated tests + manual workflow proof + device evidence where relevant. See [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md) for detailed matrix and severity SLA.
