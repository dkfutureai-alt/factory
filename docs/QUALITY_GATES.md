# FactoryOS — Definition of Done and Release Quality Gates

| Gate | Minimum evidence | Status if missing |
| --- | --- | --- |
| G0 Scope/design | Domain acceptance, user role, screen states, threat model and approved UX direction | Planned |
| G1 Source | Tested code at exact Git SHA, no fake production data, versioned schema | Implemented only |
| G2 Security | Authenticated RLS/RPC + cross-tenant/role denial + safe audit/ledger reconciliation | Blocked |
| G3 CI | Exact PR HEAD all relevant workflows successful; following merge, exact main HEAD CI | CI unverified |
| G4 Accessibility and UI | 320px/200% text, keyboard, contrast, screen reader, reduced motion, RTL as relevant | Design QA pending |
| G5 Staging | Isolated FactoryOS tenant, migration/rollback runbook, secrets, backups and smoke | Not deployed |
| G6 Production | Protected owner-reviewed release, exact SHA, live Auth/API/web/mobile configuration | Not deployed |
| G7 Physical devices | Real Android/iOS, native push, QR/camera, driver POD, offline retry | Device QA pending |
| G8 Genuine customer acceptance | Opt-in real pilots at two organizations, independent checked workflows, no critical defects | Not accepted |
| G9 Final sign-off | Release owner signs and closes issue #12 after evidence | NOT READY |

### Safety stops
- Any unauthorized tenant data exposure, inconsistent stock/serial custody, forged transaction, financial duplicate or unsafe cylinder handoff blocks promotion.
- A failed/skipped/unrun workflow is **not** success.
- A green Actions build cannot establish production migrations, real physical scan, iOS signature, FCM handset receipt, privacy review or store acceptance.
- Actual production operations require human owner/reviewer permission. Never apply ad hoc migrations to `zevrmvhnibztbxizswgu`.
- Deployment/recovery instructions in [PRODUCTION_GO_LIVE_CHECKLIST.md](PRODUCTION_GO_LIVE_CHECKLIST.md) and [FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md](FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md) supersede a simplified checklist here.

## PR completion checklist
**Scope, tests, exact-head CI, security impact, UX/accessibility, migrations and compatibility, docs/status, reviewer verdict, deployment side effects, rollback and next blocker** must be explicit. For source-only PRs label **NOT DEPLOYED** rather than “complete”.
