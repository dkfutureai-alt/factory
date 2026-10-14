# FactoryOS Design System

## Product character
FactoryOS must feel like reliable industrial operations software: calm, fast, legible, dense enough for real work, and never futuristic or decorative for its own sake.

## Core tokens

### Color
- Brand / primary: `#1457D9`
- Primary pressed: `#0E43AC`
- Navigation ink: `#162033`
- Page background: `#F6F8FB`
- Surface: `#FFFFFF`
- Border: `#E4E9F1`
- Muted text: `#667085`
- Strong text: `#101828`
- Success: `#168A50`
- Warning: `#B7791F`
- Danger: `#C83B3B`
- Info: `#2563EB`

Status color must never be the only carrier of meaning; always show a label/icon too.

### Typography
Use Inter where available; fall back to system sans-serif.
- Display: 28/34, 700
- Page title: 24/30, 700
- Section title: 18/24, 650
- Card title: 15/20, 650
- Body: 14/20, 400
- Supporting: 12/17, 400
- Table: 13/18, 400–600

### Spacing
Use a 4px base grid. Common spacing: 4, 8, 12, 16, 20, 24, 32.
Desktop content padding: 24–32px. Mobile horizontal padding: 16px.

### Radius
- Controls: 8px
- Cards: 12px
- Large panels: 14px
- Pills/status chips: 999px
Avoid excessive rounded containers.

### Elevation
Prefer borders over shadows. Use subtle shadow only for menus, dialogs and floating action surfaces.

## Components

### Buttons
Primary, secondary, ghost, destructive. Minimum height 40px desktop, 48px operational mobile. Icon-only controls require 40x40 minimum target.

### Inputs
Labels remain visible above fields. Validation text appears below field. Scanner-assisted fields expose a scan affordance next to the input rather than replacing manual entry.

### Tables
Sticky header where useful. Server-side pagination. Row actions grouped behind contextual menu except one dominant action. Numeric values right-aligned. Status is shown as text chip.

### Cards
Use cards only to group a real concept. KPI cards must have metric, context and comparison/status—not decorative icons alone.

### Navigation
Desktop uses a compact grouped sidebar. Mobile uses role-specific bottom navigation plus direct quick actions. Do not expose inaccessible modules and do not create giant navigation trees.

## Operational UX rules
1. Primary task visible without scrolling where practical.
2. Scan-first workflows minimize typing.
3. Confirmation required for destructive/irreversible actions.
4. Every async state: loading, empty, error, success; offline state on operational mobile flows.
5. Long entity names truncate safely but remain inspectable.
6. Status wording is consistent across modules.
7. Current factory/warehouse context is visible when it materially affects an action.

## Responsive breakpoints
- Mobile: < 600
- Tablet: 600–1023
- Desktop: 1024–1439
- Wide: >= 1440

The admin shell collapses sidebar labels before collapsing navigation entirely. Tables switch to priority columns or record cards on narrow layouts; never force unreadable horizontal compression.

## Design-to-code rule
Every approved SVG in `/designs` is a visual specification. Implementation should preserve hierarchy, spacing, control prominence and workflow placement. Differences must be deliberate and recorded in the work log.