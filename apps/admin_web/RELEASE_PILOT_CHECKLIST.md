# FactoryOS Admin Portal — Live Pilot Checklist

Use only real authorized pilot users on a dedicated FactoryOS environment. For mobile/driver/device workflows see [`../mobile/RELEASE_PILOT_CHECKLIST.md`](../mobile/RELEASE_PILOT_CHECKLIST.md).

- Verify exact web origin/base href and production publishable key; no service-role key or provider secrets appear in web assets.
- Platform Owner creates or selects organization and factories; Organization Admin sends invite; invitee finishes onboarding.
- Validate role/factory reassignment, deactivation, and email-expiry reissue; prove cross-tenant and cross-factory denials.
- Exercise HR/shift/leave, Inventory ledger, Production/BOM, Quality/NCR, Purchase/Sales, Warehouse, Fleet/Fuel, Dispatch/POD/Returnables, Maintenance, Reports and Audit.
- On a real phone test camera barcode scanning, driver route authorization, POD media, push deep-link policy and signed-out token cleanup.
- Capture a screenshot/test trace per role and workflow, plus failure cases; do not claim production complete from dummy data.
- Confirm production-smoke and security review on exact final commit, signed Android and iOS builds if publishing, and owner rollback/sign-off.

**Stop condition:** anything failing access isolation, stock ledger integrity, financial correctness, notification account scoping or private storage blocks go-live.
