# FactoryOS — Professional Motion & Microinteraction Specification

**Goal:** International-level perceived quality **without** harming production safety, speed, battery or comprehension. Motion reinforces causality and state; it never substitutes for true backend progress.

## Motion tokens (proposed guideline, not an existing implementation guarantee)
| Interaction | Suggested duration | Behavior |
| --- | --- | --- |
| Tap / pressed / subtle focus feedback | 80–140 ms | Immediate, low-distance, preserves touch targeting |
| Card hover/focus/selection | 120–180 ms | Small elevation/outline and clear focus ring |
| Navigation transition | 180–260 ms | Consistent directional travel/fade, no disorienting full-screen zoom |
| Sheet/dialog entry | 180–240 ms | Opacity + small offset; focus captured/restored |
| Skeleton-to-content | 120–220 ms | Calm fade; avoid shimmer that implies a server completion |
| Error feedback | 120–220 ms | Accessible inline state; avoid shaking critical forms |
| Success confirmation | 160–260 ms | Only **after confirmed commit**; announce via semantics |
| Loading/indeterminate | Continuous only when necessary | Offer text/status and cancellation or timeout path |

Use Flutter's shared theme/animation primitives; prefer implicit animations, ease-out entry/ease-in exit and coherent spacing. No 3D/particles/autoplay video or bouncing stock totals in operations screens. Keep transitions consistently fast on low-end handsets and 60fps-target hardware. Do not add long delays to network-backed actions.

## Safety invariants
- Approval, cylinder inspection, stock dispatch, invoicing and POD must display exact confirmed state and audit IDs where applicable; **no simulated completed checkmarks** before response.
- Double-submit lock, timeout/retry outcome and idempotency protect operations independently of visuals.
- Offline pending is visually distinct from server accepted; background resumes must refresh authorized workspace.
- Red/pulsing attention is reserved for true critical alerts; no flashing animation.
- No motion that obscures field focus, screen-reader announcement, QR viewfinder or driver task controls.

## Accessibility and internationalization
Honor OS reduced-motion preference (`MediaQuery.disableAnimations` and platform behavior as appropriate). Provide non-animated state changes, semantic labels, visible focus, contrast and keyboard access. Test Android/iOS screen reader and Arabic RTL. Animations must not rely only on direction or color.

## Per-screen motion acceptance
For each entry in [docs/UI_SCREEN_INVENTORY.md](docs/UI_SCREEN_INVENTORY.md), specify trigger, start/end state, duration, easing, interruption/cancel, reduced-motion alternative and semantic announcement. Review frame drops, layout jumps, focus retention and account-switch route cleanup on physical devices. PR #18 has **unmerged** visual QA work; never present its previews as released UI.

## Verification
Widget tests for state and navigation; manual video capture on a real entry-level Android handset and iPhone; 200% text/reduced-motion/RTL and slow-network checks. Record defects in [docs/DEFECT_REGISTER.md](docs/DEFECT_REGISTER.md), not as unverified “premium polished” claims.
