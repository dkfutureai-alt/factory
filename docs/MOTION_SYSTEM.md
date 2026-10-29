# FactoryOS motion system — Flutter + international SaaS quality

## Intent

Motion clarifies relationship, hierarchy and outcome, while industrial workflows demand predictable control. Every animation must answer: *What changed? Why? What should the user do next?* The default is subtle, non-distracting motion.

## Motion tokens (starting recommendations)

| Token | Duration | Curve / purpose |
| --- | --- | --- |
| `motion.instant` | 0ms | Reduced-motion and state cut |
| `motion.micro` | 100–140ms | Press, toggle, icon response |
| `motion.fast` | 150–180ms | Small row/status transition |
| `motion.standard` | 200–240ms | Cards, sheet, reveal |
| `motion.navigation` | 220–280ms | Major destination change |
| `motion.long` | 280–320ms maximum | Carefully justified onboarding context |

Reuse Flutter's existing `ThemeData` / transition primitives and shared package tokens; adopt numbers only after checking current animation classes and actual device behavior. Prefer ease-out for entrances, ease-in for exits, and platform-native treatment for keyboard/back transitions. Avoid custom spring/bounce for safety-critical controls.

## Interaction behavior

- **Navigation:** short fade-through/slide depending on route relationship; preserve back-stack semantics and focus.
- **Bottom navigation:** immediate content swap or short restrained fade; don't repeatedly animate persistent chrome.
- **Cards/accordion:** animate height only if small and stable, otherwise direct expansion; no long scroll jump.
- **Forms:** helper/error appears near field without moving submit far from view. Preserve typed values after failure.
- **Loading:** skeleton approximates final geometry; don't use endless shimmer as success proxy.
- **Scan result:** clear authorized result summary; subtle haptic/audio if supported and user enabled. Duplicate/unknown codes use text.
- **Stock transaction:** pending → server confirmed receipt → success with reference ID. A timeout is unknown/pending until authoritative reconciliation.
- **Destructive actions:** confirmation before executing, short in-place progress and final audit reference. No confetti or celebratory animation.
- **Charts:** optional restrained reveal only; accessible static/table alternative.

## Accessibility and safety requirements

- Honor `MediaQuery.disableAnimations` and platform accessible motion preferences; conditional non-animation path is first-class and fully functional.
- Prevent flashing/rapid transitions and flashing hazardous status patterns. All feedback must also be available in text/semantics.
- Use focus management after modal/navigation operations and announce state transitions where appropriate.
- Prevent overlapping rapid taps from double-posting requests; UI debounce **does not replace server idempotency**.
- Cancel animations/timers when disposed or changing workspace/user. No stale tenant data during transitions.
- Avoid animated colors as the sole meaning of warning/danger; show icon + text + corrective next action.

## Performance criteria and measurement

Use Flutter performance overlay/DevTools profiling on **actual target hardware**. Budget for sustained smoothness on common 60Hz phones (roughly 16.7ms per frame at 60fps), but do not claim frame-rate acceptance until measured. Favor `AnimatedOpacity`/transform where appropriate; watch compositing, `RepaintBoundary` use and image memory. Avoid rebuilding giant tables or camera previews per animation tick.

## QA acceptance checklist

- [ ] Same task completes with motion disabled.
- [ ] UI remains readable/accessible during loading and transitions.
- [ ] Button rapid-tap cannot create duplicate business actions.
- [ ] Camera / auth signout / background-resume lifecycle cancels abandoned transitions.
- [ ] 320dp + 200% text + slow network checked.
- [ ] Actual low-end Android/iOS measured where hardware available.
- [ ] No gratuitous looping, shimmer, or failure-as-success animation.
- [ ] Screenshots/videos and any benchmark include device, OS, build and SHA.

See [../motion.md](../motion.md) for the compact team charter.
