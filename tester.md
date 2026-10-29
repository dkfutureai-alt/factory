# FactoryOS — Professional QA / Tester Playbook

**Mission:** Prove business correctness, role isolation, inventory integrity and usable real-world experiences. This is an execution specification, **not** evidence that tests have run.

## QA ownership and levels
- QA lead: acceptance matrix, environment isolation, reproducible defects, release recommendation.
- Automation engineer: unit/widget/integration, SQL migration/RLS/Auth, cross-tenant negative assertions, CI traceability.
- Mobile device engineer: physical Android/iOS, 320px layouts, 200% text, camera/QR, weak network, app resume, push receipt, backgrounding, battery/accessibility and reduced motion.
- Factory domain tester: safe simulated production, serial cylinder/Dura tracking, driver/customer POD, damaged/quarantined returns; obtain qualified safety expert sign-off for actual gas equipment.
- Security reviewer: tenant-role boundary, reauthentication, revoked access, denial tests and credential hygiene.

## Before each test
Record immutable **build commit**, test run ID, platform/browser, OS/model, app package/flavor, backend **FactoryOS-only** project and migration version, role, organization/factory, data isolation, clock/timezone, network state and tester consent. Use fictional safe staging data. Never test live production operations without authorization.

## Required suite
| Layer | Command / entry point | Must prove |
| --- | --- | --- |
| Dart core | `cd packages/factoryos_core && flutter pub get && flutter analyze && flutter test` | Role, workspace policy, design token changes |
| Admin | `cd apps/admin_web && flutter pub get && flutter analyze && flutter test` | Admin operations, rendering and no fake committed mutations |
| Mobile | `cd apps/mobile && flutter pub get && flutter analyze && flutter test` | Auth lifecycle, session switching, stale result guards, navigation |
| Python | `python3 -m unittest discover -s scripts/tests -v` | Release safety, exact SHA migration/notification validation |
| Database | `Supabase Foundation Checks` GitHub workflow in isolated CI | Ordered migrations, SQL transaction invariants, real local JWT/RLS E2E |
| Native | `Mobile Release Quality` GitHub workflow | Android release compilation + iOS unsigned compile (**not** store readiness) |
| Visual/manual | `docs/QA_MATRIX.md` and `docs/UI_SCREEN_INVENTORY.md` | Screens, semantic states, keyboard, contrast, device ergonomics |
| Real pilot | `docs/REAL_CUSTOMER_PILOT_TESTING.md` | Explicit opt-in and genuine human-reported acceptance |

Do **not** execute production DB reset, live destructive SQL or unreviewed deployments. Check current scripts and runners instead of assuming commands are sufficient.

## Critical negative and resilience tests
1. Cross-org/cross-factory unauthorized reads and writes **deny** (API and UI); unauthorized buttons must not grant backend rights.
2. Two users sign in consecutively on one handset; cached data, QR scan callbacks, pending routes and FCM deep links must not leak across accounts.
3. Multi-active-membership user must fail closed on current mobile until fully scoped selection ships.
4. Concurrent inventory movement, insufficient stock, duplicate retry, fractional serial units, forged gas serial source and quarantine must not produce phantom units.
5. Driver cannot access others' trips; POD media is private; vehicle pickup does not instantly restock warehouse.
6. Offline attempts and timeouts show accurate pending/failed states; no optimistic “success” where server did not commit.
7. Expired session, denied permission, no camera, denied notifications, app resume and double-tap submit behave safely.
8. 320/360/390/412 logical-pixel mobile widths, desktop 1024/1440, 200% typography, keyboard insets, RTL, screen reader and reduced motion must be checked.

## Defect protocol
Write to [docs/DEFECT_REGISTER.md](docs/DEFECT_REGISTER.md) or a linked issue:
`ID | SHA | Environment | Severity P0–P3 | Preconditions | Repro steps | Expected | Actual | Evidence link | Owner | Status | Retest SHA`.
**P0:** tenant leak, loss/corruption, unsafe physical workflow or unauthorized financial action. **P1:** unusable core transaction, billing/retry bugs. **P2:** significant UI/accessibility issue. **P3:** cosmetic. Never hide failures or backdate acceptance.

## Exit criteria
All release-blocking tests pass on exact approved head, every P0/P1 closed with regression evidence, no cross-tenant leakage, restored backup rehearsal verified, physical Android/iOS checks recorded, consented customer pilot completed, owner authorized release. Automation is necessary but insufficient. See [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md) and [status.md](status.md).
