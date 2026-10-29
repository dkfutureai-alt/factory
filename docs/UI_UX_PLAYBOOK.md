# FactoryOS international UX/UI design playbook

## Product experience goal

Deliver a professional, coherent industrial operations SaaS experience equal in craft to leading global enterprise applications, while optimizing real shop-floor safety and speed. **International feel means consistency, clarity, accessible motion, strong typography, honest system feedback and high-quality local adaptation—not unnecessary animation or copied third-party screens.**

## Research and discovery

For each feature:
1. Identify primary and secondary roles, setting (shop floor, driver cab, warehouse, desk), device and connectivity.
2. Identify high-frequency tasks, critical information and costly mis-taps.
3. Map happy path, exception path, retry, permission denial, interruption and recovery.
4. Define an observable metric: task completion, number of steps, scan success, error rate or time to decision.
5. Prototype or screenshot the flow **before** committing substantial UI architecture; obtain explicit review.

## Navigation and information architecture

**Mobile:** keep role-specific Home, Work/Tasks, Scan (only when authorized), Alerts and Profile discoverable. Do not force a driver through admin-only UI. Show active factory, role and data freshness near transaction context. Support one-hand use for routine tasks; demand safe explicit confirmation for irreversible actions.

**Admin Web:** sidebar grouped by operational domain, organization/factory selector with trustworthy scope, readable dense tables, sorting/search/pagination, actionable exceptions, contextual forms and audit details. Large tables should degrade deliberately for tablets/phones rather than shrink unreadably.

**Super Admin:** cross-client platform tooling must not imply access to tenant data without proper authorization. Distinguish platform configuration from factory operations.

## Component standards

| Component | Quality bar |
| --- | --- |
| App bar/nav | Persistent location/context, clear Back, predictable action hierarchy |
| Forms | Explicit labels, optional/required, units, inline validation, unsaved changes guard |
| KPI cards | Real source, time range, context/factory, skeleton/error/empty states |
| Tables | Readable headers, sort, sticky if appropriate, totals, pagination, empty state |
| Scan | Camera permissions, manual fallback, flash, focus, invalid/duplicate scan, audible/haptic optional |
| Approval | Amount/quantity/unit, source/destination, actor, irreversible effect and confirmation |
| Timeline/audit | Chronological changes, who/when/action; avoid exposing private metadata |
| Notifications | Severity + meaning, action link authorized on open, actionable retry |

## Screen-state specification

For *every important screen*, design:
- Initial; loading; success; empty; offline/stale; timeout/server error; permission denied; validation error; conflict/duplicate; destructive confirmation; long-data and large-type cases.
- Disabled actions with understandable explanation; submit progress and a firm distinction between pending, accepted, committed and failed.
- Expected voice/screen-reader reading order and keyboard focus behavior.

Do not let animation or color alone communicate success. Every state needs accessible semantics.

## Foundation: tokens and visual quality

Use shared Flutter `factoryos_core` design primitives before adding one-off colors/spacing. Design token hierarchy:
- Semantic color roles: primary, on-primary, surface, text primary/muted, success, warning, danger, informational, disabled and focus.
- Predictable spacing scale (suggested 4/8/12/16/24/32), responsive container width, density variants and consistent corner radii.
- Accessible type: clear style names for display, heading, title, body, label, numeric/table. Prefer tabular figures for stock and monetary values.
- Consistent icon language; no emoji in professional transaction UI.
- State chips include text, icon and accessible label; green/red alone never sufficient.
- Light/dark palettes validated for contrast; never override legibility for a trendy gradient.

**These are design targets; inspect existing tokens before modifying them.** Don't silently create competing systems.

## Responsive reference matrix

| Context | Test |
| --- | --- |
| Compact mobile | 320dp and typical 360/390dp widths |
| Large phone | portrait/landscape and camera/keyboard interactions |
| Tablet | 600–1024dp content/navigation adaptation |
| Desktop | 1280px+ dense table, filters, dialogs, keyboard navigation |
| Text zoom | at least 200%, no clipping/truncation of critical content |
| Locale | English, Marathi, Hindi expansion; test RTL mirroring when enabled |
| Accessibility | keyboard, TalkBack/VoiceOver, contrast, switch/large targets |
| Network | loading, slow, offline, background/resume, stale session |

## Module-specific UX acceptance

**HR:** check-in unmistakably confirms server result; overnight shift labels and leave day units are clear.
**Inventory/Production:** quantity and measurement units visually dominant; source/destination and lot/serial near submit.
**Cylinder safety:** hold/inspection expiry must be prominent; never animate a hazardous failure as success.
**Fleet/Dispatch:** driver's next action is clear; failed POD upload is visibly pending, not delivered.
**Warehouse/Returns:** pickup, quarantine and inspected receipt are visibly different stages.
**Reports:** periods/time zones, source and null/unavailable states explicit.

## Review process

Design brief → user journey → state wireframes → shared components → polished screens → developer handoff → implementation comparison → real-device UX → defect log → acceptance. For significant redesign, attach before/after screenshots and note chosen tradeoffs in [DECISION_LOG.md](DECISION_LOG.md). Review visual details, cognitive load and correctness of business context—not aesthetics alone.

## Release gate for design

No critical screen may be marked design-accepted if important text clips on 320dp/large text, critical actions lack confirm/undo rules, permission/offline states are unhandled, or quantity/safety consequences are obscured. See [../ui-ux.md](../ui-ux.md), [MOTION_SYSTEM.md](MOTION_SYSTEM.md) and [ACCESSIBILITY_LOCALIZATION.md](ACCESSIBILITY_LOCALIZATION.md).
