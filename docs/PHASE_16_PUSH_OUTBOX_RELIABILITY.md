# Phase 16 — Push Outbox Delivery Reliability

## Context

The Phase 16 application has a five-minute GitHub Actions push scheduler and a deployed-runtime FCM worker contract. This change builds **on the latest Phase 16 main branch**; it does not replace the independently merged Phase 15 performance work or the Phase 16 shared-device/multi-tenant registration migration.

## Migration and safe rollout

- **`supabase/migrations/0041_notification_dispatch_claims.sql`** extends the existing `notification_deliveries` status to include `processing` and introduces a database claim timestamp plus unique fencing token. Existing rows remain in their current states.
- The worker uses a new service-role-only, SECURITY INVOKER `notification_claim_push_deliveries` RPC. The RPC caps claims at 20 and uses `FOR UPDATE SKIP LOCKED` to avoid two workers selecting the same queued delivery.
- Stale `processing` claims are eligible for recovery after 15 minutes, with a different fencing token. The old worker cannot record a status for the newer claim.
- A completed/failed/skipped delivery clears the claim fields. A 100-attempt cap prevents infinite redispatch.
- No UI or public API privileges are added. `anon` and `authenticated` cannot call the claim RPC; the service role does.

Deploy migration **before** replacing the Edge worker. The updated worker requires the new RPC and columns. All production release steps still require the explicit FactoryOS project safeguards documented in `docs/PHASE_16_PRODUCTION_RELEASE.md`; never link a different product's Supabase project.

## FCM safety

- PostgREST may embed an individual related notification as an object rather than a one-element array. The worker now handles either form.
- HTTP 400/404 alone **must not** disable a notification device. The worker deactivates only on an FCM response with a typed `google.firebase.fcm.v1.FcmError` detail containing `UNREGISTERED`. Invalid message data/configuration must preserve the user's registration.
- This is **at-least-once delivery**: if FCM accepts a push and the worker crashes before recording a successful result, a stale lease can cause another push. UI logic should de-duplicate by the stable `notification_id`. Exactly-once external delivery is not asserted.

## Regression gates

- `supabase/tests/0041_notification_dispatch_claims_smoke.sql`: initial claim, no active-lease double claim, 15-minute recovery, old-token fencing, new-token finalization, completed job exclusion, attempt exhaustion and RPC grants.
- `deno check supabase/functions/send-notifications/index.ts`.
- `deno test supabase/functions/send-notifications/worker_helpers_test.ts`: PostgREST relation shape and FCM error classification.
- Full existing local Supabase migrations, SQL tests and authenticated JWT/RLS/module workflow chain.
- Release workflow lint for updated CI YAML.

## Operational acceptance

Before enabling real FCM dispatch, verify a dedicated FactoryOS Supabase project, production secrets, a controlled test device, an isolated notification, device token rotation and sign-out, multi-organization access, manual and scheduled dispatch behavior and alerting for stuck claims. The repository tests are **not** a live FCM or production deployment sign-off.
