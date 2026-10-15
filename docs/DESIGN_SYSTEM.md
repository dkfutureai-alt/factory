# FactoryOS Design System

## Direction

Clean, modern, mobile-first industrial UI. It should look like real business software rather than an AI concept dashboard.

## Visual Rules

- Primary visual language: deep navy/blue with white surfaces and restrained semantic colors.
- Rounded cards and controls, but avoid oversized decorative radii.
- High information clarity with short labels and meaningful icons.
- Strong numeric hierarchy for operational KPIs.
- Minimum touch target: 44 logical pixels.
- Do not place long descriptive paragraphs inside daily-operation screens.
- Tables on desktop must become cards/lists or horizontal-scroll structures on smaller widths.
- Destructive/critical actions require confirmation and clear state feedback.

## Navigation

### Mobile
Bottom navigation should keep the most frequent employee actions close: Home, Tasks/Work, Scan, Alerts, Profile. Role-specific modules appear as dashboard shortcuts rather than overcrowding the bottom bar.

### Admin Web
Left navigation with grouped modules, compact top app bar and contextual factory selector. Keep the dashboard operational: exceptions, approvals and current workload first; decorative charts second.

## Major Screen Workflow

For every new major screen:

Existing context -> inspect current implementation -> design reference image -> implement -> connect real data/functionality -> test -> compare -> fix -> retest.

## Data Presentation

Never fake production KPIs in release builds. Skeleton/loading, empty, error and stale/offline states are mandatory where applicable.
