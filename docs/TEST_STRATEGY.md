# FactoryOS master QA strategy

## Scope and operating model

Test **Super Admin, Organization Admin, Factory Manager, Supervisor, Employee, Driver, Quality, Warehouse, HR, Maintenance** only where corresponding roles/capabilities exist in the current code. Use actual effective permissions, never invent roles or assume every user can access a module. Test cross-role denial as carefully as authorized success.

## Test levels

| Level | Required proof | Typical environment |
| --- | --- | --- |
| Static | format/analyze, secrets/lint, migration names | CI |
| Unit | type/model, policies, validation, idempotency client helpers | local/CI |
| Widget | responsive/empty/error/loading, navigation, reduced motion | Flutter CI |
| SQL/RLS | migration, table grants, row and RPC authorization, integrity | isolated local Supabase |
| Auth E2E | real local JWT -> PostgREST/RPC with distinct user/tenant | isolated local Supabase |
| API/service | invite, Edge Function, Storage, FCM provider outcomes | isolated controlled |
| Staging E2E | signed-in end-to-end workflows and two tenants | approved dedicated staging |
| Physical device | real camera, notifications, lifecycle, network transitions | identified Android/iOS hardware |
| Pilot | consenting business owners/workers execute actual workflow | owner-approved factory |
| Production smoke | scoped read-only service health, role and alert checks | protected production process |

## Priority matrix

| Priority | Scenario | Acceptance invariant |
| --- | --- | --- |
| P0 | Tenant A reads/writes Tenant B by API, RPC, Storage, admin/mobile, export, push | Must deny without data leakage |
| P0 | Duplicate concurrent GRN / inventory issue / dispatch / return | No duplicate ledger posting, no negative stock |
| P0 | Serialized gas customer issue / hold / inspection / QR evidence | Attestation integrity and actual custody; document current bypasses |
| P0 | Auth user A → B with in-flight async and pending push | B never sees A data; stale operations rejected |
| P0 | Backup and restore with correct roles, Auth, Storage and migration history | Recovery demonstrated before live onboarding |
| P1 | Purchase→GRN→Production→QC→Warehouse→Sales→Dispatch→POD→Returns | Balances and audit reconcile |
| P1 | Overnight attendance and leave overlaps | Correct timezone, status and permissions |
| P1 | Fuel odometer and trip/driver assignment | No impossible odometer or unauthorized edits |
| P1 | Maintenance spares and quarantine | Ledger and condition state consistent |
| P1 | FCM accepted vs delivered, retries, missing credentials | State truthful; no cross-tenant notifications |
| P2 | Empty/loading/offline/retry/permission UI, 320dp and 200% text | Usable with no clipping or accidental command |
| P2 | English/Marathi/Hindi long text, RTL-ready layout | Labels fit, numbers/units clear, focus order logical |

## Dataset: isolated and fictional only

Use at least **two organizations**, **two factories per organization where relevant**, multiple roles, inactive users, revoked memberships, duplicate document requests, zero/low/overfull quantities, expired cylinder inspections, quarantined assets, time boundary cases and slow/failed requests. Store test fixtures, not actual customer details. Assert **both positive and negative results**.

## Bug report standard

```text
ID / severity / owner:
Date, branch, exact SHA, environment, build:
Role, org/factory fixture, locale, device/OS:
Precondition and steps to reproduce:
Expected:
Actual:
Screenshot/video/redacted logs:
Security / stock / user consequence:
Regression test:
Fix SHA, retest outcome:
```

Severity: **P0 blocker** cross-tenant leak, stock corruption, unsafe gas dispatch or credential exposure; **P1 high** broken core workflow/security flaw; **P2 medium** recoverable functional/accessibility defect; **P3 low** cosmetic issue. Never demote a blocker solely to meet a release date.

## Test execution and reporting

Check CI definitions and run `python3 -m unittest discover -s scripts/tests -v`; run package-level `flutter analyze` and `flutter test`; run SQL and real local Auth E2E per `supabase/tests/`. **`supabase db reset` is local-only.** Mark tests NOT_RUN if hardware, env or tools unavailable.

For each release candidate, record exact SHA, CI job links, failed/skipped jobs, scenario matrix, device/OS, security exceptions and owner sign-off. An artifact build, empty advisor or successful workflow skip is never sufficient proof of release.
