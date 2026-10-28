# Phase 21A — Serialized Cylinder and Dura Registry (Candidate)

**Scope:** identity, visibility, inspection evidence and retirement of individual physical cylinders/Dura containers. This is a **source-code feature** until CI and approved FactoryOS deployment pass. It is not a release of the physical custody workflow.

## Supported operator flow

1. In Admin → **Cylinders**, select a factory and register a physical cylinder/Dura with an existing active cylinder or returnable Inventory item, manufacturer serial and ownership.
2. FactoryOS normalizes the manufacturer serial to uppercase and enforces **unique serial per organization**. It generates a unique, persistent `FA-...` QR token for labelling. Registration begins in **Hold / Unverified**.
3. An authorized factory manager can append a visual condition inspection. Good observations become **Inspection Recorded**; damaged/rejected observations become **Quarantined**. Neither is a certification, refilling release, or available inventory status.
4. A manager can permanently retire a container with a required reason. The entire registration/inspection/retirement event history is append-only.
5. The mobile Inventory scanner first looks for a matching asset QR/serial and displays the authorized asset's identity, condition, test-due date and a safety notice. It falls back to the existing Inventory item scan when no registered container matches.

## Security and integrity

- `supabase/migrations/0047_gas_container_serial_registry.sql`: `gas_container_assets` and immutable `gas_container_asset_events` tables; organization/factory and Inventory-item composite keys; tenant/factory RLS; read-only authenticated table grants; explicit `service_role` grants; no anonymous access.
- `gas_register_container`, `gas_record_container_inspection`, `gas_retire_container` require an authenticated manager authorized for the exact factory. Users cannot directly edit status or forge events. Retired assets cannot be re-inspected.
- Every asset registration/update is added to the preexisting tamper-evident business audit log.
- The serial registry is separate from aggregate stock-quantity ledger; it never changes `inventory_transactions` or `stock_ledger_entries`.
- The test-due field is informational; entering an upcoming date is not proof of pressure testing or regulatory compliance. Inspection Recorded cannot be interpreted as a filled/saleable container.

## Automated verification

- `supabase/tests/0047_gas_container_serial_registry_smoke.sql` uses fictitious identities in a rollback transaction to test unique serials, normalized QR, unverified hold, good/damaged condition transitions, retirement, event immutability, audit integrity, unauthorized reads and denied RPCs.
- `supabase/tests/gas_asset_auth_e2e.sh` runs actual local Auth/JWT/PostgREST requests against the registry with a manager and factory employee: authorized Dura registration, employee/other-factory denial, normalized QR lookup, duplicate serial rejection, manager-only quarantine, history, direct PATCH denial and irreversible retirement.
- Full `Supabase Foundation Checks` must replay migrations `0001–0047`, run SQL structural/auth tests and application workflows. Flutter Application Quality must pass the Admin and Mobile scanner changes.
- FactoryOS production is **not migrated**; production approval and real-device QR acceptance are distinct gates.

## Not yet implemented — do not claim end-to-end serialized custody

The existing warehouse, dispatch, vehicle, POD, customer return and Phase 20 intake workflows still record quantities. Phase 21A asset registrations are **not yet bound** to those immutable Inventory transactions or individual custody events. Do not infer a cylinder's current location, owner in possession, full/empty state, or customer liability from this registry.

Phase 21B must add **transaction-bound** serial assignments for verified stock intake → production/fill → quality release → vehicle → customer → vehicle return → quarantine/receiving, with one-to-one quantity reconciliation, duplicate-scan rejection, real-device offline/idempotent capture, manufacturer documentation, competent inspection and compliance sign-off. Avoid any UI that falsely asserts physical custody before these links exist.

No demo customer assets should be seeded into production, and customer pilots require informed consent.
