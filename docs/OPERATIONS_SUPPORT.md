# FactoryOS — Operations, Monitoring and Customer Support Readiness

## Operational expectations
- On-call escalation for Auth/invite, warehouse stock mismatch, financial duplicate, physical cylinder-safety exception, driver/POD issues and FCM failures.
- Each alert must identify tenant/factory only in authorized views. Public issue text and telemetry must not contain secrets/customer PII.
- Track API/RPC error rates, inventory reconciliation exceptions, outbox accepted/skipped/failed, stale warehouse intake, backup age and authentication/role denial trends, without inferring customer success from provider logs.
- Support customer data export/deletion requests through authorized workflows, never manual public backups.

## Incident response
Classify severity and impact → preserve scrubbed evidence → block unsafe transactions if needed → notify authorized owner → mitigate using verified rollback/forward fix → retest tenant isolation and ledger → write postmortem with exact SHA, timestamps, scope and remediation. A Git rollback does not reverse applied SQL migrations.

## Release operational checklist
Confirm backup+restore rehearsal, authentication SMTP, site HTTPS, push delivery on hardware, device installability, read-only smoke, defect escalation owner, privacy/support documentation and customer acceptance. Always defer to [PRODUCTION_GO_LIVE_CHECKLIST.md](PRODUCTION_GO_LIVE_CHECKLIST.md).
