# Migration version collision prevention

FactoryOS maintains a strict one-to-one mapping between committed SQL filenames and version identifiers. The repository previously had two overlapping draft PRs independently creating migration `0049`. PR #38 merged the first canonical `0049`. Any competing PR must now change its version and reconcile API semantics before merge; never silently rename migrations already deployed.

**Fast CI gate:** `Supabase Foundation Checks` runs `python3 scripts/check_migration_versions.py` immediately after checkout, before downloading CLI tools, starting local services or replaying migrations. It reuses `local_versions` from the existing production release verifier, rejecting duplicate version prefixes and invalid migration filenames. The release-candidate offline tests also assert the gate exists and executes before DB initialization.

This prevents merged code from silently carrying duplicate migration version filenames, but it does not prove two different unique migration versions are semantically compatible, nor does it deploy anything. Review SQL diffs, function contracts, RLS and live backup/restore evidence separately. Production migrations still require protected approvals and version-aligned `supabase db push`.
