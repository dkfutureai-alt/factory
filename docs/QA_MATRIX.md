# FactoryOS — End-to-End Test Matrix

**Status of every row below: NOT YET VERIFIED by this document.** Attach actual environment+commit+test evidence to mark complete. Negative-path tests are mandatory.

| ID | Flow (end to end) | Expected positive | Required negative / fault test | Human/device evidence |
| --- | --- | --- | --- | --- |
| AUTH-01 | Invite → email → onboarding → login | Correct role/factory and safe redirect | Invalid/expired token, other user, revoked role | Real email & device |
| AUTH-02 | Logout A → login B, background resume | No A cache/routes | Stale async scan, notification deep link, changed memberships | Shared handset |
| TEN-01 | Two organizations and two factories | Correct scoped data | All cross-org and cross-factory reads/writes denied | JWT/RLS & UI |
| TEN-02 | Multiple active org memberships | Mobile safely blocks currently | No accidental tenant selector or stale push destination | Real handset |
| HR-01 | Shift → check in/out → report | Correct attendance and timezone | Duplicate attendance, unauthorized edit | Phone |
| HR-02 | Leave request → review → balance | Correct approval/audit | Self-approval, unassigned approver | Mobile + Admin |
| PUR-01 | Purchase order → approve → GRN | Valid receipt into ledger | Over-receipt, repeated request, reject return | Admin + DB |
| INV-01 | Receive → transfer → issue | Ledger quantities reconcile | Negative stock, duplicate, parallel conflicting writes | QR device + DB |
| PRO-01 | BOM → work order → consume → finish | Raw and finished ledger reconcile | Insufficient stock, invalid recipe, duplicate close | Admin + Mobile |
| QLT-01 | Inspect → NCR/hold → release | Held stock not saleable | Unqualified approve, quarantine bypass | Operator |
| SAL-01 | Quote/order → allocate → invoice | Reservation/financial totals correct | Unauthorized discounts, overallocation, replay | Admin |
| WH-01 | Put-away → pick → stage → dispatch | Accurate location and state | Other factory stock, double pick | Scan |
| FLT-01 | Vehicle → driver → trip → fuel | Scoped assignment and fuel log | Different driver, impossible amounts | Driver phone |
| DSP-01 | Dispatch → POD → customer receipt | Confirmed POD and audit | Duplicate POD, foreign customer, private media leak | Driver/customer pilot |
| RET-01 | Empty pickup → warehouse receiving | Two distinct custody phases | Phantom restock, damaged stock sale, replay | Physical simulation |
| GAS-01 | QR registration → scan → transaction link | Correct serial + immutable source | Serial spoof, item/quantity/type mismatch, cross-tenant | Label/device + safety |
| GAS-02 | Issue → return → inspect → reuse | Complete physical custody chain | Expired inspection, missing scan, quarantine bypass | Safety expert required |
| MNT-01 | Asset scan → work order → spare issue | Ledger-aware completion | Unauthorized technician, duplicate spare use | Technician |
| RPT-01 | Dashboards, reports, audit | Matches source ledger/events | Cross-factory filters, stale/fictional KPI | Admin |
| NOT-01 | Outbox → FCM → mobile tap | Scoped route and real receipt | Provider fail, user switch, unauthorized route | Real handset |
| PIL-01 | Opt-in feedback in two tenants | Consented genuine current reports | Client-forged timestamp, fake success, cross-tenant reports | Real pilot |
| UX-01 | Mobile / web UI | Loading/empty/error/offline and focus states | 320px, 200% scale, keyboard, reduced motion, RTL | Screenshot/video |
| RLS-01 | Database access with real JWT | Authorized RPC/data only | Anonymous, wrong role/factory/user denied | Test logs |

For each case save `ID | environment (isolated/test/production) | Git SHA | role | dataset | date/time | steps | expected | observed | PASS/FAIL/BLOCKED/NOT RUN | evidence URL | tester`. Never fake screenshots or counts.

**Regression focus:** financial/stock correctness, physical cylinder safety, mobile session switching, missing serial evidence, database migration history, tenant isolation and network replay. See [../tester.md](../tester.md) and [REAL_CUSTOMER_PILOT_TESTING.md](REAL_CUSTOMER_PILOT_TESTING.md).
