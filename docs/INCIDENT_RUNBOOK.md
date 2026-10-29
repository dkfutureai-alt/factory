# FactoryOS incident, rollback and operational safety runbook

> This is a **plan**, not a claim that monitoring, backups, rollback or support are deployed. Do not use unverified emergency SQL, destructive commands or external credentials. Owner-approved FactoryOS-only access is required.

## Severity and ownership

| Severity | Examples | Immediate policy |
| --- | --- | --- |
| SEV0 | Cross-tenant data exposure, unsafe cylinder dispatch, stock corruption, leaked production credentials | Pause affected writes/release, escalate to security + factory owner immediately |
| SEV1 | Unavailable core dispatch/inventory/auth, widespread incorrect accounting | Stop affected business operation, activate reviewed recovery plan |
| SEV2 | Recoverable module outage, major UX regression, missing alerts | Triage, safe fallback and tracked fix |
| SEV3 | Minor visual issue, noncritical report inconsistency | Ticket and regular release |

Use an approved incident communication channel; do not post actual customer data in public issues.

## First-response checklist

1. Record actual UTC/IST start, affected organization/factory **aliases**, build/commit/release and impacted module.
2. Confirm facts with scoped, sanitized logs and transaction IDs; verify actual live status, not just Slack/chat/README.
3. Contain impact using **preapproved** controls (e.g. disable release, pause dispatch write pathway); coordinate with factory ops before modifying stock state.
4. Preserve audit and evidence immutably; do not overwrite ledgers, purge customer records or alter migration history to hide defects.
5. Check whether the issue is cross-tenant, quantity reconciliation, custody safety, Auth session, FCM routing or backup/restore.
6. Create an incident owner, communication schedule, affected data/time window and recovery criteria.
7. Correct only through reviewed, reversible, logged actions and protected release mechanisms.
8. Verify tenant-specific recovery and exact ledger/customer reconciliation before reopening workflows.
9. Produce blameless postmortem with root cause, containment, rollback, tests and follow-up owner.

## Recovery and rollback constraints

- Avoid `supabase db reset` against any linked remote/production system.
- Database downgrade is often unsafe; use documented forward-fix/recovery strategy and isolated restore exercise before any planned release.
- Backup needs schema/roles/migration history, Auth/Storage as applicable, encrypted offsite retention and evidenced recovery point/objectives. Follow [PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md](PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md).
- App rollback must be assessed with schema compatibility; signed mobile clients may remain installed during server rollback.
- On suspected compromised credentials, restrict access and rotate secrets through approved owners; do not paste new keys in chat.
- Push provider acceptance is not actual mobile receipt; confirm physical device events separately.
- For cylinder safety or stock discrepancies, isolate physical assets and require qualified human checks, not just corrective code.

## Required post-incident proof

`Incident ID, dates, owner, root cause, affected scope, sanitized source evidence, containment, exact release SHA, fixes/tests, recovery and customer acknowledgement where applicable, follow-up issues`.

No real incident or operational readiness claim is created by this file.
