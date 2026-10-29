# Phase 30 — Free-plan backup and isolated disaster-recovery rehearsal

**Status at 29 Oct 2026: procedure only, NOT a completed backup/restore test.**
The dedicated FactoryOS Supabase project `zevrmvhnibztbxizswgu` is
healthy but has not had the FactoryOS application schema deployed. A green CI
or the presence of this runbook is **not** evidence of recovery readiness.

## What Free supplies and what it does not

The FactoryOS Supabase organization was verified on the **Free** plan. Free
does **not** include automated managed daily database backups or point-in-time
recovery (PITR). Supabase recommends regular offsite CLI logical exports for
Free projects. A database dump is only **part** of a recoverable system:
Supabase database backups exclude the actual files stored via Storage API.
Default `supabase db dump` also excludes internal schemas such as
Auth and Storage; user identities, custom Auth changes, object storage,
external email/push credentials, release signing keys and any tenant-specific
secrets require their **own compatible documented recovery procedures**.
Never promise customer retention, availability or complete restore with only
the three example SQL dumps below.

Official references (review live at the time of the exercise):

- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/reference/cli/introduction

## Owner-controlled recovery decisions (write down before onboarding)

- App/data owner, recovery operator, offsite key custodians, emergency contact,
  customer privacy/export authorizations.
- RPO (maximum acceptable data loss) and RTO (maximum restore downtime).
  Choose a backup frequency that actually meets the approved RPO and test it.
- Encrypted offsite destination independent of the GitHub repository and
  Supabase project. Access is least-privilege, expiration/rotation are set;
  test that both the backup and encryption recovery keys remain available.
- Retention, deletion and export/legal policy for employee, customer,
  financial, Health-independent HR and business data; **no real exports
  in a PR, issue, Actions log/artifact, shared chat or public drive**.
- A distinct **FactoryOS-only** isolated restore target with owner approval.
  Never rehearse on Salon/Janseva staging/production, or on FactoryOS
  production itself. Budget/limits must be approved before provisioning
  any billable restoration environment.

## Optional local logical export (only when authorized)

Run on a trusted owner-controlled computer with the authenticated Supabase CLI,
correct organization/project permissions, a current validated CLI, no debug
credential logging and sufficient private disk space. The commands below are
**instructions for the operator**, not evidence that they were run. Confirm
the **exact linked** project via CLI and the console; refuse any mismatched
project. Never copy the database password, URL with credentials or keys into
a shell history, issue, repository or test fixtures.

```bash
# In the FactoryOS repository; interactively check the exact linked project.
supabase projects list
supabase migration list --linked

# The owner creates and restricts a private directory OUTSIDE the repository.
# Example on Unix (Windows users: use an equivalent private local directory):
BACKUP_DIR="$(mktemp -d "$HOME/factoryos-recovery-XXXXXXXX")"
chmod 700 "$BACKUP_DIR"

# Only after checking the linked destination is exactly FactoryOS.
# Each command reads remote database contents; None applies migrations.
supabase db dump --linked --role-only \
  -f "$BACKUP_DIR/roles.sql"
supabase db dump --linked \
  -f "$BACKUP_DIR/schema.sql"
supabase db dump --linked --data-only --use-copy \
  -x storage.buckets_vectors -x storage.vector_indexes \
  -f "$BACKUP_DIR/data.sql"

# Check that exports exist, are nonempty and have restricted local access.
test -s "$BACKUP_DIR/roles.sql"
test -s "$BACKUP_DIR/schema.sql"
test -s "$BACKUP_DIR/data.sql"
chmod 600 "$BACKUP_DIR/"*.sql
```

**Immediately** encrypt the exports using an owner-approved, audited
encryption tool and independently kept recovery keys; transfer encrypted
copies to approved offsite storage. Restrict local access, test transfer
integrity and securely remove plaintext copies according to the owner's
device/security policy. Do not reuse plaintext dumps as development seed
data. The CLI export format and excluded schemas must be audited for
version-specific changes before relying on them.

## Recovery completeness: explicit separate scope

1. **PostgreSQL application schema and data:** checked dumps above, plus
   separately preserved migration history as described in Supabase's restore
   guide; verify public permissions and tenant RLS on target.
2. **Supabase Auth and identities:** independently document and test the
   compatible supported Auth recovery/export path, session and user-ID
   continuity, SMTP/auth configuration and cryptographic key handling.
   Do not assume the default SQL dumps recreate Auth accounts. Handle
   JWT/session invalidation and identity mapping explicitly.
3. **Storage files:** independently export, encrypt, retain and restore
   actual private POD, equipment and other uploaded objects; verify bucket
   metadata, object bytes, ACL/RLS and signed URL access on the restored
   project. DB-only dumps do **not** restore files.
4. **Secrets and integrations:** keep configuration/secret backups separate
   in a vault (Supabase Edge Functions, Firebase/FCM, SMTP, APNs, signing
   assets, Auth redirects, domain/hosting, scheduled jobs). Rotate/rebind
   secrets in the new environment, never publish raw values.
5. **Financial, warehouse and cylinder custody proof:** reconcile purchase
   payments, immutable Inventory transactions, dispatch/POD, vehicle return,
   quarantine/receiving, serial tags, status and audit chains with the source
   evidence. A successful SQL import alone proves none of these.
6. **Store/mobile builds:** keep release-artifact source SHA, signing
   ownership, Android/iOS store metadata and rollback approvals.

## Nonproduction drill and release gate

1. With explicit owner approval, allocate a **new, isolated** FactoryOS
   nonproduction target; confirm its ref differs from FactoryOS production
   and all Salon/Janseva resources. Do not incur unapproved cost.
2. Follow the **current** Supabase supported restore guide, including
   role/schema/data order, migration-history restoration when applicable,
   Auth/Storage-specific caveats and the target's default privileges.
   Use fail-on-error and transaction boundaries as described in current
   docs. Do not replay production database credentials into test logs.
3. Compare source and recovered migration histories, number of expected
   tables and important scoped row counts without revealing customer data.
   Verify all public-table RLS and absence of `anon` access.
4. Using approved nonproduction **consenting** or appropriately anonymized
   identities, check sign-in, correct tenant/factory access, denial of
   other organizations, and key financial/stock/dispatch operations.
   Verify private files match securely kept integrity digests.
5. Record a **redacted** drill report: date, release SHA, source and isolated
   target refs, backup age, restore elapsed time, coverage of
   Auth/Storage/FCM/SMTP, checksum proof, verified RPO/RTO and unresolved
   gaps. Real identifiers/secrets/private transaction details stay in a
   protected owner vault, not issue comments.
6. If any step fails or the verified RPO/RTO is unacceptable, mark
   **BACKUP/RESTORE BLOCKED**. Keep GitHub go-live issue #12 open and
   do not enroll production customers. For higher recovery requirements,
   obtain explicit approval for an eligible paid plan and verify its
   actual managed backup/PITR entitlements before relying on them.

## Zero-cost constraints

A self-managed encrypted backup can use existing owner-controlled equipment
and an already approved private offsite destination; it is not guaranteed
zero-cost (storage, network, device, labor and recovery environment are
real costs). Do not silently provision paid cloud resources. If no safe
backup/recovery arrangement is available, limit FactoryOS to an isolated
nonproduction demonstration with disposable fictional data, not actual
factory/employee/customer records.

**Exit condition:** a release owner has personally reviewed a secure,
documented, *successful* isolated restore with the complete data/Auth/Storage
scope, observed the declared RPO/RTO and signed the disaster-recovery
section of `docs/PRODUCTION_GO_LIVE_CHECKLIST.md`. Nothing in this
document constitutes that proof.
