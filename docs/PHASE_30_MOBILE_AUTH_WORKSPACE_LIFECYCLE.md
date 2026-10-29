# Phase 30 — FactoryOS mobile user-bound workspace lifecycle

## Threat and scope

The mobile Auth gate previously rebuilt `_MobileBootstrapPhase12(user: session.user)` without a user-specific widget key. Flutter can reuse the same `State` when the authenticated user changes but the widget type remains the same. The earlier bootstrap future may have completed for **user A**, while the new widget was receiving **user B**, leaving previously loaded organization, role, factories and module cards accessible on a shared phone. Checking only the organization ID is not enough: A and B might both belong to the *same* organization but have different roles/factory assignments.

This phase guards presentation and async bootstrap at the **authenticated user** boundary without exposing an unsafe multi-organization selector. Real server authorization still comes from PostgreSQL RLS/RPCs.

## Implemented changes

1. The active `_MobileAuthGatePhase12` keys the bootstrap widget by `session.user.id`. Switching users creates a fresh State and Future instead of reusing an old organization's data.
2. `MobileSessionIdentity` is a pure Dart guard that requires the exact nonblank signed-in user ID. A missing, signed-out or different user fails closed.
3. `MobileRepository.bootstrap` checks the current Auth user before querying and **after each asynchronous membership, invitation, factory and module read**. It rejects stale results even when both users share an organization.
4. The active bootstrap revalidates Auth after the Future resolves and before constructing a home screen, and can rebind safely if changed without being disposed.
5. The loaded home is keyed to the bootstrap Future, so refreshing membership data **remounts and clears cached module widget State** and reattaches the push handler with the current bootstrapped organization.
6. On `AppLifecycleState.resumed`, the app reloads server-verified organization/factory membership, module visibility and current role; pending older Futures are not used to render the new screen.
7. The active Auth gate also observes account transitions and pops all pushed module routes / dialogs back to the root after logout or a switch to another authenticated user. A same-user token refresh does not dismiss an active workflow.
8. The older `main_phase11.dart` alternate Auth gate also keys its bootstrap by user ID for consistency.

## Test evidence and limitations

`apps/mobile/test/mobile_session_identity_test.dart` covers signed-out, changed, same user and blank identity conditions; run Flutter Application Quality and Mobile Release Quality against the exact PR head. Also run the pre-existing workspace guard and Inventory scan epoch regressions; all modules must continue to reject ambiguous multi-organization accounts.

**Not yet complete:** The application does not offer multi-organization selection (#45/#47). Every mobile module does not yet accept an explicit selected factory and scoped RPC parameters. The active root Navigator is reset when the signed-in user changes, but dismissal timing and nested routes still require physical Android/iOS acceptance; this is not a substitute for RLS or explicit module/RPC scoping. Existing RLS is the final server-side denial for unauthorized work. A revoked membership can remain visible until app resume or rebootstrap, but it must no longer authorize server-side access.

Physical Android/iOS acceptance must exercise: sign in A → scan/load warehouse → sign out → sign in B (different and same org), sign-in change mid-network request, different factory role, revocation while suspended, failed refresh, offline/resume, notifications and app navigation. Observe that **no A data remains in B home UI** or any cached QR result, and all B reads/writes obey B's RLS.

No production schema migration, customer data, or real device test is performed by this source change. The dedicated FactoryOS production project remains behind the protected plan/release process. Keep issues #45/#47 and go-live #12 open.
