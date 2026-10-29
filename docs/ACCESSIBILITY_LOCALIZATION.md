# Accessibility, multilingual support and international readiness

## Core standard

The product must remain usable under constrained screen width, large text, impaired vision, industrial lighting, gloves, camera permission limits and poor connectivity. Target WCAG 2.2 AA where applicable, including measured color contrast and keyboard accessibility. No country feature is accepted merely because flags or translated strings exist.

## Language roadmap and implementation

- Primary product content should support **English**; localization architecture must permit **Marathi and Hindi** without manually editing widgets.
- For international licensing, prepare language and format direction for Arabic/RTL, without claiming Arabic translation exists until actual reviewed resources and QA pass.
- Use Flutter localization resources (`l10n`/ARB or established project pattern). No hard-coded user-visible sentences in new widgets if localization infrastructure is present.
- Translate errors, form labels, status, empty state, notifications and accessibility semantics—not only screen titles.
- Keep abbreviations industrially understandable. Maintain glossary for cylinder, Dura, GRN, inventory unit, stock location, quarantine, proof of delivery and attendance terms.
- Do not present machine translations as reviewed professional content without native-speaker validation.

## Formatting and RTL

- Store timestamps in UTC; display local date/time with explicit timezone where a factory/shift decision depends on it.
- Use locale-aware dates, decimal grouping, currency symbol/code and measurement units. Preserve underlying decimal precision; never translate database identifiers.
- Explicitly test mixed Latin identifiers, mobile numbers, serial/QR codes and Arabic/RTL text; raw identifiers may need fixed LTR direction.
- Mirror navigation/directional affordances logically for RTL, but do not mirror brands, numeric graphs or physical QR content.
- Test string expansion (30–50% longer text), 200% font scaling and long organization names.

## Accessibility acceptance

- Semantic name/role/state for controls, form errors, tables and stock-status badges.
- Reach all critical Admin actions by keyboard; predictable tab/focus order and visible focus indicator.
- Support TalkBack/VoiceOver and dynamic text scaling; no unreadable truncated critical quantity or warning.
- Color not the sole state indicator. Maintain at least 4.5:1 normal text and 3:1 large text/essential UI contrast when applicable.
- Logical tap targets at least 44–48 logical px; adapt dense desktop tables without shrinking mobile touch areas.
- Reduce motion consistent with [MOTION_SYSTEM.md](MOTION_SYSTEM.md). Avoid flashing, autoplay video or distracting loops.
- Provide manual entry/retry for camera/QR refusal and visible feedback for offline/permissions.
- Form validation tied to field, not only toast; announce important status changes accessibly.

## International product experience

- Safe area and keyboard handling on Android/iOS; date locale, numbers, unit display and address fields region aware.
- Role/workspace and navigation concepts should not assume a single country or a single factory.
- Clarify subscription, billing, tax and legal requirements by actual deployment market before implementing jurisdiction-specific behavior.
- Avoid flags/imagery stereotypes or fake staff photos; use neutral enterprise-grade product imagery only when needed.

## Evidence

Include locale, text scale, platform, screen size, screen-reader state, contrast audit and screenshot/recording in QA record. Record which languages are *implemented*, which are *reviewed* and which are *planned*. Cross-locale QA is mandatory for release claims that mention multilingual support.
