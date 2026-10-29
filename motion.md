# FactoryOS — motion, animation & interaction contract

**Motion should communicate cause and effect, never delay a task.** Follow [docs/MOTION_SYSTEM.md](docs/MOTION_SYSTEM.md), [docs/UI_UX_PLAYBOOK.md](docs/UI_UX_PLAYBOOK.md), and [docs/ACCESSIBILITY_LOCALIZATION.md](docs/ACCESSIBILITY_LOCALIZATION.md).

## Principles

1. Prefer predictable, subtle motion and fast feedback, suitable for an industrial workplace.
2. Animate state changes—not arbitrary banners, bouncing metrics or looping decorative objects.
3. Preserve focus, semantics and state; a transition must not trigger an extra stock/dispatch request.
4. Honor OS accessibility settings, especially `MediaQuery.disableAnimations` / accessible motion preferences and screen-reader workflows.
5. Never signal success before the server confirms the transaction; distinguish locally queued vs remotely committed vs failed.

## Suggested design tokens (targets; validate on devices)

| Pattern | Typical duration | Behavior |
| --- | --- | --- |
| Tap/press feedback | 80–140 ms | Immediate ripple/highlight; do not delay input |
| Small state/icon change | 120–180 ms | Opacity/scale restrained, linear or ease-out |
| Page/content change | 180–260 ms | Short fade/slide with clear spatial relationship |
| Dialog/bottom sheet | 180–260 ms | Standard platform motion, focus managed |
| Loading skeleton | Minimal/subtle | Stable layout; static fallback |
| Success acknowledgement | 120–220 ms | Only on committed result; semantic text is authoritative |
| Error/shake | Avoid default shake | Prefer non-motion textual/semantic feedback |

## Hard constraints

- Animated content must not obscure quantities, QR camera view, action controls or critical warnings.
- Prefer transforms/opacity over repeated layout/rebuild work. Profile frame timing and memory.
- A user disabling animations sees instantaneous equivalent state, never missing content.
- Animations must stop on route disposal, logout, user switch and detached scans.
- No endless shimmer/loading spinner without cancellation, timeout and visible explanation.
- Respect alert severity; avoid flashy colors, celebratory motion after hazardous cylinder or quality events.

## Motion review

Record a short annotated clip or deterministic golden/wiget behavior where supported; check 60Hz budget, 320dp, large text, low-end Android, offline and reduced-motion behavior. Never claim device performance from code inspection alone.
