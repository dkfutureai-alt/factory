# Mobile multi-organization safety gate

**Phase 27A — fail closed until every mobile module supports explicit workspace scope**

A user with active memberships in multiple organizations previously entered the first arbitrary membership from PostgREST, and six modules independently repeated that first-membership lookup. This could misattribute production actions and confuse real customer acceptance in multi-tenant pilots.

All seven first-membership entry points now request up to two active memberships and use a shared fail-closed guard. An unambiguous single membership behaves as before. When multiple are present, no organization is selected silently and the user receives an explicit explanation instead of loading factory modules in the wrong context. Pending invitations are still available for accounts with no memberships.

**Intentional limitation:** multi-organization switching is **not implemented** by this guard. The next step is to pass a verified, selected organization ID through every HR/Driver/Delivery/Quality/Notifications/Production/Warehouse/Reports repository and all server RPCs, re-run cross-tenant authorized user E2E, and only then expose a selector. It would be unsafe to add a superficial dropdown while modules still execute unscoped self-service RPCs. Do not claim multi-org acceptance with this change.

Local widget/unit tests cover single membership, absent membership, reversed membership order and mixed roles. CI must pass Flutter Application Quality and Mobile Release Quality. No production deployment or customer access is changed from GitHub alone.
