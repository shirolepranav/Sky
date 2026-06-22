---
name: sky-screen
description: Implement or update a screen in the Sky iOS app from the Sky_App_Workflow.md catalog (screens identified like S-TODAY-01, S-VER-03, S-SHIELD-01). Use when building any app screen, view, or flow — onboarding, Today, shield, verification, emergency unlock, streaks, paywall, settings, celebrations. Wires the screen to the existing SwiftUI design system and follows brand voice and gating rules.
---

# Implementing a Sky screen

Build a screen that matches its spec in `Sky_App_Workflow.md` exactly, using the
existing design system. Do not invent layout, copy, or colors.

## 1. Gather the spec (before writing code)

1. Find the screen entry in `Sky_App_Workflow.md` Part 1 by its ID (e.g.
   `S-VER-03`). Read the full entry: Purpose, Entry/Exit points, Layout,
   Components, **Copy** (exact strings), States, Interactions, Transitions, Edge
   cases, Accessibility, Persistence, **Gating**.
2. Read the matching journeys in Part 2 to understand how the screen connects.
3. Check the relevant state machine in §3.1 and the gating row in §3.2.
4. If a pixel reference exists, open the prototype in `Sky-handoff/sky/project/`
   (`screens-*.jsx`) for visual detail — match the visual output, not the JS
   structure.
5. If the spec is ambiguous or conflicts with a doc, ask before guessing.

## 2. Build it

- **Location:** `Sky/Features/<FeatureName>/<ScreenName>View.swift` (see Tech
  Spec §5 folder map). New files under `Sky/` are auto-included by the Xcode
  project — no project-file edits.
- **Use the design system — never raw values:**
  - Color → `SkyColor.*`
  - Type → `.skyText(.titleL)` etc. (`SkyTextStyle`)
  - Spacing/padding/gaps → `SkySpacing.*`; radii → `SkyRadius.*`; layout consts →
    `SkyLayout.*`
  - Buttons → `SkyPrimaryButton` / `SkySecondaryButton` / `SkyCoralButton`
  - Containers → `SkyCard`, `SkyStatusPill`, `SkyStreakChip`
  - Ring → `SkyProgressRing`; mascot → `NimbusView` / `NimbusMini`
- **Copy:** use the exact strings from the screen's Copy section / §3.3 copy
  library. Brand voice is warm and honest, never guilt-trip (PRD §7).
- **States:** implement every state listed (default, loading, success, error,
  empty, disabled, Pro-locked, edge cases). Don't ship only the happy path.
- **Gating:** apply `[Free]` vs `[Pro]` exactly. Free-tier limits (e.g. 2 apps,
  combined-mode only) and in-context Pro gates (`S-PAY-05`) per §3.2.
- **Accessibility:** Dynamic Type, VoiceOver labels/hints, and Reduce Motion
  fallbacks per the screen's Accessibility section. Min touch target 44×44.
- **File header comment:** what the screen is + its workflow ID + which phase.
- **Add `#Preview`(s)** covering the key states (and dark mode if it differs).

## 3. Persistence & wiring (only what the spec calls for)

- Read/write only the `SharedDefaults` / `UserProgress` / local-store fields the
  screen's Persistence section names. Respect the privacy invariants in
  `CLAUDE.md` (videos deleted after use; emergency reasons never leave device).
- For navigation, follow the route model in `Sky_App_Workflow.md §0` (tab bar +
  full-screen covers for verification/emergency/paywall; deep links
  `sky://verify`, `sky://emergency`).

## 4. Verify

- If full Xcode is available: build for an iOS Simulator and check the screen
  renders, every state, light + dark, and a large Dynamic Type size.
- Otherwise: run the type-check from `CLAUDE.md` (Build & verify) and clearly
  state that only compilation — not iOS layout/runtime — was verified.
- Cross-check against the spec: does every Component, Copy string, State, and
  Interaction in the workflow entry appear in the implementation?
