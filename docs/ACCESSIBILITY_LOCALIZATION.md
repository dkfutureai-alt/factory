# FactoryOS — Accessibility, Localization and Inclusive Enterprise UX

## Accessibility acceptance baseline
- Touch targets **at least 44dp**; clear labels, states and logical keyboard/screen-reader focus order.
- Contrast appropriate for text, controls and semantic badges; status must not rely on color or animation alone.
- Text must survive **200% scaling** and small mobile viewports; no clipped buttons, overlapped dialogs or inaccessible horizontal form steps.
- Form validation announced adjacent to the affected field; controls have useful semantic names and errors preserve entered data.
- Respect OS reduced-motion preferences; avoid flashing, autoplay, excessive transitions and non-dismissible busy indicators.
- Dynamic progress, network errors, scan outcomes and successful server confirmation require understandable semantic announcements.

## Localization architecture
Keep all user-facing strings out of hardcoded presentation fragments where reasonable and manage translation keys centrally. Plan English, Marathi, Hindi and Arabic support, with future regional languages per business need. Use locale-aware dates, times, numbers, decimals, currencies, addresses and phone formatting. Record the factory-local timezone separately from timestamps saved in UTC. Arabic RTL requires reflow testing (navigation, row direction, icon mirroring, scan indicators), not just translated text.

## Responsive/device checks
Android widths **320, 360, 390 and 412 logical px**, landscape/keyboard, low-end device performance; iOS small/large; Admin desktop/tablet width and browser zoom. Test at 200% text, high contrast, dark-system settings if supported, screen-reader traversal, keyboard-only and reduced-motion. Use [UI_SCREEN_INVENTORY.md](UI_SCREEN_INVENTORY.md) with screenshot evidence.

## Release policy
A future-language intention is **not** a completed localization feature. Record locale coverage as not started/in progress/verified by exact screenshot and QA result. Do not automatically enable unreviewed RTL or translated operational/safety instructions.
