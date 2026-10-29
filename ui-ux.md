# FactoryOS — international-grade product design team

**Design ambition:** A calm, high-trust, globally competitive operational SaaS experience—not a glossy fake industrial dashboard. Prioritize operator speed, error prevention, coherent visual hierarchy and accessibility over decoration.

See [docs/UI_UX_PLAYBOOK.md](docs/UI_UX_PLAYBOOK.md), [docs/ACCESSIBILITY_LOCALIZATION.md](docs/ACCESSIBILITY_LOCALIZATION.md), [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md), and [motion.md](motion.md).

## Design roles

- **Product/UX lead:** research shop-floor actors, jobs, information architecture, role-specific journeys and task outcomes.
- **Visual systems designer:** semantic colors, type scale, spacing, data density, icons, reusable Flutter component variants.
- **Interaction designer:** task states, responsive navigation, meaningful transitions and recovery from partial failures.
- **Accessibility/localization reviewer:** keyboard/screen reader, contrast, text scaling, long translations, Hindi/Marathi/English/RTL readiness.
- **Design QA:** compare implemented states and screen sizes against approved reference screenshots; record concrete issues.

## Mandatory state coverage

Each screen must specify **default, loading, empty, success, error, no-permission, offline/stale, destructive confirm and high-volume data** where applicable. Transactional flows must show exact quantity, unit, factory, document, actor and status. Design explicit undo/retry rules: never pretend a stock write succeeded while still pending.

## Acceptance standards

- Primary workflows reachable with predictable navigation, clear affordances and minimum 44dp interactive targets.
- Mobile 320dp–large tablets and desktop responsive layouts; not horizontal clipping under 200% text scale.
- Semantically labelled controls and accessible focus order, contrast target WCAG AA and meaningful non-color status cues.
- Visual consistency for numbers, units, dates, currency and status chips; skeletons stable without janky layout jumps.
- No fake metrics, generated user photos or misleading filler data on actual connected screens.
- Validate real employees wearing gloves or working under bright light where feasible; use high contrast and scan feedback.

Before a feature is merged, the designers sign off screenshots, UI state coverage, token usage, accessibility and reduced motion. Code correctness does not establish design acceptance.
