# FactoryOS engineering standards and review checklist

## Engineering architecture

- Stack present in repository: Flutter Admin Web + Flutter Mobile + shared `packages/factoryos_core`, Supabase/PostgreSQL/RLS, Supabase Auth/Storage/Edge Functions, Firebase Cloud Messaging integration.
- Keep data/service/repository layers separate from widget rendering. Avoid RPC calls directly inside reusable UI components.
- Use robust typed models, explicit nullability, deterministic state transitions and dependency injection appropriate to existing code.
- Follow repository conventions first; do not add an architectural framework or package solely because it is fashionable.

## Database and domain correctness

- Every tenant-owned row has authoritative organization scope; factory-scoped rows have verified factory scope. Derive actor from Auth, not client-supplied role.
- Privileged SECURITY DEFINER functions require pinned `search_path`, explicit caller scope, minimized grants and adversarial tests.
- Inventory truth comes from immutable ledger operations; never patch aggregate balances directly. Verify stock and serial/container custody separately.
- Model business flows as state machines with guarded transitions and idempotency keys for retryable commands.
- Atomicity: purchase GRN + ledger, production consumption/output, Quality hold/release, dispatch issue, returns intake, maintenance spares.
- Migration files are append-only after merged/released; no rewrites, renames or manual migration-history fabrication.
- Money, quantities, units and rounding must be explicitly typed/validated; no binary floats for financial/stock truth.
- Protect offline retries from duplicate receiving, billing, delivery or fuel postings.
- Secure private storage URLs and user-bound notification routes; no client-side sole authorization.

## Flutter correctness

- Plan desktop, tablet, compact mobile and high-density industrial use.
- Surface error/empty/loading/offline/permission states and actionable recovery. Avoid hidden disabled actions.
- Centralize design tokens, semantic colors, typography and UI components. Keep accessibility labels and consistent focus behavior.
- Always dispose animation controllers, stream subscriptions, listeners and scanner/camera resources.
- Ignore late async responses after sign-out, user switch, workspace reassignment and route disposal.
- Never launch unsafe multi-org selection before **every** mobile repository/RPC/FCM route has an explicit trusted scope and cross-tenant proof.

## Reliability / security / operations

- No secrets, personal pilot data, customer numbers, access tokens or raw FCM payloads in source, telemetry, logs or PR.
- Normalize UTC storage and timezone-aware UI, especially overnight shifts and dispatch cutoff.
- Avoid unbounded polling, N+1 database requests and large reactive rebuilds; paginate/export safely.
- Log business audit events with traceable transaction IDs but sanitized sensitive content.
- Ensure error surfaces do not disclose unauthorized tenant existence.
- Maintain a tested backup/restore and compatibility story before any approved live schema migration.
- Do not weaken RLS to resolve an application permission bug.

## Required tests by change type

| Change | Minimum automated evidence |
| --- | --- |
| UI/component | Flutter analyze + widget tests + 320dp/large text/accessibility checks |
| Repository/state | unit/widget + async cancellation/user-switch/error/timeout cases |
| Database migration/RPC | isolated clean migration + SQL/RLS + real local Auth/JWT E2E + rollback reasoning |
| Notification/deep link | send-worker checks + signed-in authorization + no-cross-user route |
| Release workflow | actionlint + workflow unit tests + exact-SHA protected prerequisites |
| Full cross-module command | scenario integration + stock/financial/audit reconciliation |

Actual QA may require additional named CI workflow jobs. Review both `.github/workflows/` and the files touched before deciding.

## Pull request contract

```markdown
### Problem / issue / acceptance criteria
### Behavior / architecture / changed paths
### UI states or screenshots (if visible)
### Authorization, privacy and ledger risks
### Tests: exact commands, results and same-head CI URLs
### Environment: isolated only / deployed staging / physical device / production
### Migration + rollback + feature flags, if needed
### Known exclusions and next blockers
```

Reviewers must ask: Can a bad actor cross tenants/factories? Can a user submit the same action twice? Can stock/serial quantities diverge? Does logout preserve sensitive UI? Does the UI misreport a pending write as completed? Is the test claim demonstrably true?
