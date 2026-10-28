# Phase 22 — conservative customer pilot coverage

This is a reporting improvement, **not an automated production approval**.

Admin → Pilot Testing now summarizes every one of the 14 workflows using the **latest report per consenting tester and workflow** within a tenant. A newer Failed or Blocked outcome supersedes an older pass for the same tester. Across multiple testers, Failed overrides Blocked; Blocked overrides Pass reported. Missing workflows are visibly Not reported instead of silently omitted. It is impossible for this summary to display a count of historical passes as if they were current status.

The Admin query is scoped by organization, uses stable `created_at, id` ordering, and loads the latest 250 records. If 250 are returned, a warning clearly states that older evidence may be missing. Tester counts also explicitly say recent reports. The original tenant RLS, consent, privacy and withdrawal policies are unchanged.

Flutter unit tests verify empty feedback, stale-pass replacement, multi-tester precedence, blocked outcomes, tied timestamps, invalid scenarios and truncated history.

**Production acceptance remains separate:** require real customer invitations, actual consent, signed-in role/factory testing on physical devices, verification of failures, and release-owner sign-off. This dashboard is deliberately not a go-live switch.
