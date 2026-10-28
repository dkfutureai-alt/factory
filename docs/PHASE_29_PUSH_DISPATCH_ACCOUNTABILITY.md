# Phase 29 — FactoryOS scheduled FCM delivery accountability

## Why this change is required

Before this phase, the 5-minute scheduled **Notification Push Dispatch** workflow relied on HTTP 2xx alone. The Edge Function deliberately returns HTTP 200 with `failed > 0` when FCM rejects delivery rows. This made the GitHub job **green despite reported provider delivery failures**, and the green scheduled run could be mistaken for working customer notifications.

The new guard distinguishes an unconfigured push worker, an empty queue, a provider-accepted message, an intentionally skipped row (no active device), and a delivery failure. **FCM acceptance is not proof the handset displayed or received a notification.**

## Implemented behavior

1. `scripts/notification_dispatch_preflight.py` continues to require the exact dedicated FactoryOS project `zevrmvhnibztbxizswgu`. Unconfigured (all three secrets absent) produces an explicit **SKIPPED — no credentials configured** GitHub job summary and never sends the secret. Partial or cross-project configuration fails closed.
2. `.github/workflows/notification-dispatch.yml` dispatches only when the preflight produced `ready=true`. It never follows an HTTP redirect and captures the raw response in a temporary private file, not CI logs.
3. The Edge Function now returns `claimed`, `processed`, `sent`, `failed` and `skipped` count fields (0–20). It verifies that each claimed queue row was fetched under its original lease token before sending any FCM messages. Incomplete or superseded lease batches throw instead of silently reporting zero processed.
4. `scripts/validate_notification_dispatch_result.py` verifies an object with nonnegative, bounded integer counts, `claimed == processed`, and `processed == sent + failed + skipped`. It fails the GitHub job on any `failed > 0` or missing/inconsistent accounting fields (including an older deployed worker with an incompatible response).
5. The GitHub job summary includes only counts. No raw response bodies, customer notification contents, credentials, device tokens, provider errors or account IDs are printed. A clean zero-queue run is a valid no-op, **not a claim that notifications were delivered**.

## Verification

- `scripts/tests/test_validate_notification_dispatch_result.py`: synthetic empty/success/partial-failure, malformed, oversized and sensitive response checks.
- `scripts/tests/test_production_workflow_guards.py`: asserts that preflight gates sending and validates the accounting response.
- `supabase/functions/send-notifications/worker_helpers_test.ts`: verifies missing, duplicate and stale lease detection before sending.
- Run **Release Workflow Lint** and **Supabase Foundation Checks** on the exact PR head before merging.
- Re-run these checks on the merged `main` commit. The new Edge Function code is not live until the independently approved **full** FactoryOS Supabase release.

## Production acceptance

Before activating FCM dispatch for customers, the release owner must configure the protected FactoryOS production environment, migrate the isolated backend with reviewed backup/restore evidence, deploy the updated function, and use two consented isolated pilot organizations with actual test devices. Verify real FCM service account, Android/iOS APNs/FCM and device permissions. Trigger a test notification for a controlled device and verify (a) queue transition, (b) accepted provider response, (c) actual device receipt, (d) user- and tenant-scoped navigation, (e) one failed delivery produces a failed GitHub schedule, and (f) skipped no-device rows remain visible in summary. Store CI run IDs, factory environment and device QA evidence in the go-live tracker.

**Not a production deployment.** No customer data, production database, Salon or Janseva resource is modified by merging these source changes.
