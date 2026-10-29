# FactoryOS — International-Grade Product UI/UX Team Guide

**North star:** Calm, fast, credible industrial software for factory teams under time pressure. **No generic AI-looking dashboards, pointless ornamentation or fake KPIs.** This complements [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md); source tokens in `packages/factoryos_core/lib/src/design_system.dart` are authoritative.

## Product roles and priorities
| Persona | Primary decisions | UX emphasis |
| --- | --- | --- |
| Platform owner | Tenant setup, access and global security | Scoped settings, approvals, strong confirmation |
| Organization admin | Factory operations, orders, exceptions | Dense but readable dashboards and audit context |
| Factory manager/supervisor | Production, quality and warehouse | Queue/action hierarchy, urgent exceptions, transactional clarity |
| Employee/technician | Shift, scanning, assignments, maintenance | Big action targets, minimal forms, safe offline messaging |
| Driver | Assigned vehicle, trip, delivery, POD, empty pickup | One-task-at-a-time, daylight legibility, reliable retry and receipts |
| Viewer/customer pilot | Read-only insight / optional feedback | Explicit permissions, no misleading edit affordances |

## Visual design system (existing implementation)
- Material 3, Navy `#0A2A43`, Blue `#0B6FFB`, Canvas `#F5F8FC`, Border `#DCE5EF`; semantic green/amber/red **only** for actual status.
- Spacing tokens 4, 8, 12, 16, 24, 32; radii 10, 14, 20. Tokens are references, not license to override existing code casually.
- 44dp minimum touch targets, accessible focus states, readable typography, consistent labels, aligned numeric tables and coherent icon set.
- One primary action per screen, explicit safe secondary actions, confirmation for irreversibility, undo where domain permits.
- Do not encode status by color alone; show label + icon + action. Never use misleading fixed percentages on production KPI cards.
- Admin desktop: side navigation, context header/factory selection, search/filter, responsive rows; mobile: bottom destinations Home/Work/Scan/Alerts/Profile only when authorized.

## Screen-to-code process
Discover actual screen → inventory states → wireframe → polished visual reference → product/design review → implement with shared tokens → wire real API → widget/golden/manual tests → compare screenshots at 320px, 390px and desktop → accessibility audit → sign off. Keep a screenshot link and acceptance note for every reviewed screen.

## Universal states for every screen
**Initial / loading / loaded / empty / error / permission denied / offline or stale / transaction in progress / success confirmed / validation error / retry / expired session.** Prefer skeletons for repeatable layout; do not hide failures behind endless spinners. Confirmation messages must reflect committed server operations.

## International UX localization
Design for English first but translation-ready for Marathi, Hindi, Arabic and other future regions. Prevent text clipping at 200% scale, support RTL (including directional icons), locale-aware dates/numbers/currency and facility timezone. Do not hardcode region-specific address assumptions. Industrial site safety and local regulations are separate operational review gates.

## Delivery artifacts
Each major screen requires a named spec in [docs/UI_SCREEN_INVENTORY.md](docs/UI_SCREEN_INVENTORY.md): purpose, role, information architecture, inputs, outputs, authorized actions, states, mobile/desktop adaptations, motion cues, accessibility criteria, API mapping and design QA outcome.
