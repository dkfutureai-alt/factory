# Status tracking, acceptance and evidence protocol

## Why
Prevent misleading "fully completed" claims and help other agents resume without repeating audits. The repository has mature code, but a staged deployment, physical QA and consenting-pilot acceptance are separate facts.

## Status fields (mandatory)

| Field | Example format |
| --- | --- |
| Workstream | Inventory / Returns / Mobile Auth / UI |
| Scope | `apps/mobile/lib/... / supabase/migrations/...` |
| Owner | GitHub user or "unassigned" |
| Status tier | PLANNED, CODED, CI_VERIFIED, STAGING_VERIFIED, DEVICE_VERIFIED, PILOT_ACCEPTED, PRODUCTION_RELEASED, BLOCKED, UNKNOWN |
| Evidence | SHA + named green job, issue, redacted test artifact |
| Environment | local isolated / staging project / physical Android build / approved production |
| Last checked | ISO timestamp with timezone |
| Blocker | exact dependency and action |
| Next step | one testable task |

**NEVER** use "100%", "full working", "production complete", "zero bugs" or "real user approved" without evidence meeting the appropriate tier.

## Rules for state advancement

- CODED requires committed source, not a chat response.
- CI_VERIFIED requires named CI jobs completed successfully **for the exact head**, not a prior commit, skipped job or generic GitHub combined status.
- STAGING_VERIFIED requires deployed environment identity and real signed-in data/API checks. Mock or seed tests do not count as live customer workflows.
- DEVICE_VERIFIED requires an actual identified handset/OS/build, physical scan/notification and redacted evidence. A CI-built APK alone is not device acceptance.
- PILOT_ACCEPTED requires consent, two genuinely separate organizations for isolation cases, actual role-specific scenarios and owner acceptance.
- PRODUCTION_RELEASED requires protected approval, schema history, backup/restore, deployment, monitoring and rollback verification.

Record PASS, FAIL, SKIP, BLOCKED, NOT_RUN separately for individual tests. Explicitly distinguish flaky tests from product defects; never delete a failing test to make a report green.

## Documentation update procedure

1. Fetch latest [../status.md](../status.md) and [WORK_LOG.md](WORK_LOG.md); check concurrent changes.
2. Attach evidence links, exact SHA, test failures and exclusions.
3. Update only affected rows and tasks; leave unresolved issues and gates intact.
4. Update `agent.md` dated snapshot only when the source of proof has materially changed; add a fresh timestamp.
5. Add an issue comment with actual results when work changes a tracked blocker.
6. Verify Markdown links and terminology; documentation CI should not imply deployment.
7. Link PR to issue and keep changelog history append-only.

## Example handoff

```yaml
checked_at: 2026-10-29T09:02:00+05:30
branch: docs/example
base_sha: <exact sha>
issue: 27
module: gas_serial
source_status: CODED
verification:
  - name: isolated SQL regression
    result: NOT_RUN
    evidence: null
production: NOT_DEPLOYED
device: NOT_TESTED
pilot: NOT_ACCEPTED
blocker: owner-approved staging and real scan test
next: execute adversarial tests in an isolated project, then review physical custody flow
```

Do not commit sample credentials or real customer identity in status evidence.
