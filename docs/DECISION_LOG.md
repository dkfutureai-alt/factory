# FactoryOS architecture & product decision log

This is an append-only index for significant design and engineering decisions. **A proposal is not an accepted architecture change.** Cite PR and evidence; never retroactively attribute review to a human who did not approve.

## ADR template

```markdown
### ADR-YYYYMMDD-NNN — Short title
- Status: PROPOSED / ACCEPTED / REJECTED / SUPERSEDED
- Date and owners:
- Context/problem:
- Options considered:
- Decision and why:
- Security, tenant, data and UX consequences:
- Migration, compatibility and rollback:
- Verification and acceptance:
- Linked issue / PR / code SHA:
- Review evidence:
```

## Baseline decisions (existing architecture, review exact source before edits)

| Subject | Current project direction | Primary reference |
| --- | --- | --- |
| Tenant boundary | Organization + factory scoped server authorization | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Persistence | Supabase/PostgreSQL, versioned migrations, RLS | [../agent.md](../agent.md) |
| Inventory | Immutable ledger and transactional transitions | [WORKFLOWS_AND_ROLES.md](WORKFLOWS_AND_ROLES.md) |
| Apps | Flutter Admin Web, Mobile, shared core | [../README.md](../README.md) |
| Cylinder/Dura | Serial identity and transaction attestations; physical custody unfinished | [PHASE_33_GAS_SERIAL_SOURCE_INTEGRITY.md](PHASE_33_GAS_SERIAL_SOURCE_INTEGRITY.md) |
| Multi-org mobile | Fail closed until end-to-end explicit scoped routing and RPC validation | [PHASE_30_MOBILE_AUTH_WORKSPACE_LIFECYCLE.md](PHASE_30_MOBILE_AUTH_WORKSPACE_LIFECYCLE.md) |
| Deployment | Protected plan → approved release → device/pilot acceptance | [FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md](FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md) |

Any future change to auth, RLS, tenant selection, schema migration, motion foundations, localization, external service or payment model needs a reviewable ADR.
