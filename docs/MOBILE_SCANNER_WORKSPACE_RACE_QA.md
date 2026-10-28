# FactoryOS mobile QR scanner — workspace switching QA

The Inventory scanner is scoped to the **currently selected organization**, not the first organization membership. As of this change, request responses have a monotonically increasing request token. Switching organizations invalidates pending QR/serial/Inventory lookups, clears any prior asset, result, error and manual code, and allows new organization queries immediately. A late response from the old organization is ignored in the success, error **and** completion handlers.

Automated checks: `apps/mobile/test/inventory_scan_epoch_test.dart` tests same-workspace acceptance, organization-switch invalidation, switching back, superseded scans, invalid foreign-workspace requests and explicit disposal invalidation. Run `Flutter Application Quality` on the exact PR head.

**Still required before go-live:** physical Android/iOS QR-camera permission acceptance, repeated-scan behavior, offline operation, lost connectivity, reduced motion and multi-organization switching with authorized consenting users. This is not evidence that a customer tested a device, nor a substitute for RLS. Supabase remains the final authorization boundary for each request. Do not use fake FactoryOS customer data in production.
