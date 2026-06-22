# CLAUDE.md

Guidance for working in the Sky codebase. Read this first.

## What Sky is

iOS app (SwiftUI, iOS 17+) that blocks selected social apps after a daily time
budget and requires a verified ~30-second **outdoor video** to unlock them. The
strict on-device verification is the entire product. Friendly cloud mascot
("Nimbus"). No skip credits; the only escape is a friction-loaded emergency
unlock. iOS-only, no third-party SDKs, on-device only (no user videos leave the
phone).

## Source-of-truth documents (read before non-trivial work)

| Doc | Use it for |
|---|---|
| `Sky_PRD.md` | Product requirements, brand voice, `AppBranding` constants (§11) |
| `Sky_Technical_Spec.md` | Architecture, frameworks, data model, folder structure (§5), verification thresholds (§8.5) |
| `Sky_Development_Roadmap.md` | The 16 build phases, in dependency order, with tests per phase |
| `Sky_App_Workflow.md` | Every screen (catalog with IDs like `S-VER-03`), user journeys, state machines, gating table, copy library |
| `DESIGN_SYSTEM.md` | Authoritative visual spec — color, type, spacing, components, Nimbus |

If two docs conflict on visuals, **`DESIGN_SYSTEM.md` and the design tokens win**
(it says so itself). For product behavior, the PRD wins.

The original design handoff (HTML/JS prototypes from claude.ai/design) lives in
`Sky-handoff/sky/project/` — useful as a pixel reference (`tokens.jsx`,
`nimbus.jsx`, `screens-*.jsx`). Don't edit it; it's a read-only reference.

## Current state

Built so far (**Roadmap Phase 1 — Design System & Mascot**):

```
Sky/
├── App/
│   ├── SkyApp.swift                       // @main — launches DesignSystemPreviewScreen for now
│   └── AppBranding.swift                  // PRD §11 swappable constants
├── Core/DesignSystem/
│   ├── ColorTokens.swift                  // Color(hex:) + SkyColor (all tokens)
│   ├── Typography.swift                   // SkyTextStyle + .skyText(_:)
│   ├── Spacing.swift                      // SkySpacing / SkyRadius / SkyLayout
│   ├── Buttons.swift                      // SkyPrimaryButton / Secondary / Coral
│   ├── Cards.swift                        // SkyCard / SkyStatusPill / SkyStreakChip
│   ├── SkyIcons.swift                     // SunIcon / FlameIcon
│   └── SkyProgressRing.swift
├── Features/Mascot/
│   └── NimbusView.swift                   // MascotState (5) + NimbusView (Canvas) + NimbusMini
└── DesignSystemPreviewScreen.swift        // visual QA showcase (debug surface)
```

**Not built yet:** everything else (onboarding, Family Controls, blocking,
verification pipeline, streaks, paywall, settings, the 3 extension targets). See
the Roadmap for order. The target full structure is in `Sky_Technical_Spec.md §5`.

## Build & verify

**Full Xcode is required to build/run/preview** (iOS SDK, Simulator, `#Preview`
macro). Open `Sky.xcodeproj` in Xcode 16+. The project uses a file-system
synchronized group, so **new `.swift` files under `Sky/` are picked up
automatically** — no need to edit the project file.

This machine currently has **only Command Line Tools** (no full Xcode). When you
can't open Xcode, type-check the cross-platform SwiftUI code against the macOS
SDK to catch real compile errors. The `#Preview` macro plugin ships only with
full Xcode, so strip preview blocks first:

```bash
# type-check all design-system sources (previews stripped)
tmp=$(mktemp -d)
for f in $(find Sky -name '*.swift'); do
  awk '/^#Preview/{exit}{print}' "$f" > "$tmp/$(echo "$f"|tr '/' '_')"
done
xcrun --sdk macosx swiftc -typecheck -target arm64-apple-macosx13.0 "$tmp"/*.swift
```

Exit 0 = clean. This validates Swift/type correctness only — not iOS layout or
runtime behavior. Always note this limitation when reporting "verified."

With full Xcode available, prefer:
```bash
xcodebuild -project Sky.xcodeproj -scheme Sky -destination 'generic/platform=iOS Simulator' build
```

## Design system rules (non-negotiable)

1. **Use tokens, never literals.** Colors come from `SkyColor`, spacing from
   `SkySpacing`, radii from `SkyRadius`, type from `SkyTextStyle` via
   `.skyText(_:)`. Don't inline hex or magic numbers. Off-scale spacing is a bug.
2. **Never pure white or pure black.** Text is `SkyColor.ink` (`#2D3748`),
   backgrounds are the warm surface tokens. `#000`/`#FFF` only appear inside
   Nimbus shape fills and button labels.
3. **Filled elements with white labels use `mossGreenAction` (`#52822A`)**, not
   the brighter `mossGreen` tint — only the deeper green clears WCAG AA (4.6:1).
   `mossGreen` is for tints, nav-active, and checkmarks on light backgrounds.
4. **One color, one meaning** (DESIGN_SYSTEM §2). Coral = streak/alert/paused.
   Sun yellow = verified/milestone. Don't use accents decoratively.
5. **Calm, soft, mascot-first.** Cards use a hairline `divider` border, not heavy
   shadows. The "pressable" button look is a *solid offset* shadow (radius 0).
6. **Subtle motion only.** Nimbus has a ~2s idle bob and ~0.5s state transitions.
   Respect `accessibilityReduceMotion` — freeze loops, shorten transitions.
7. **Min touch target 44×44.** Buttons are full-width by default.

## Brand voice (copy)

Friendly but honest; **never guilt-trip** (PRD §7). Warm and truthful, not cold
or punishing. Example: *"Nimbus is waiting outside for you ☁"* — not *"You've
wasted enough time."* The mascot reacts emotionally to behavior; the words stay
kind. Exact strings for built screens live in `Sky_App_Workflow.md §3.3`.

## Code conventions

- **File header comment** on every file: what it is + which doc/section it
  implements (see existing files for the pattern).
- **SwiftUI-first.** UIKit interop only where unavoidable (paste-blocking text
  field, shield extensions) — see Tech Spec.
- **`#Preview` on every component**, including light + dark where relevant.
- **Mascot is one replaceable component** (`NimbusView.swift`). Swapping it (e.g.
  a Lottie file in v1.1+) must touch only that file.
- **Branding is swappable from one file** (`AppBranding.swift`). Renaming the app
  or mascot edits only that file.
- Reference screens by their workflow ID (e.g. `S-TODAY-01`) in comments and PRs.

## Privacy invariants (do not break)

- Verification videos are written to `temporaryDirectory` and **deleted right
  after** processing (pass or fail). No upload, ever.
- **Emergency-unlock reasons stay on-device** (App Group container) — never
  CloudKit, never any server.
- GPS is rounded to 0.01° before any storage. No raw screen-time data leaves the
  device. No third-party analytics SDKs.

## Gotchas

- **Family Controls Distribution entitlement** is required for the main app +
  each of the 3 extension targets, applied separately; approval can take weeks
  (Roadmap Phase 0). Verification work is blocked on it.
- Screen Time / Shield APIs are historically unstable across iOS versions — test
  on iOS 17.0, 17.6, latest 18.x.
- Verification thresholds (`VerificationThresholds.swift`, when built) are the
  single tunable source — measured on real devices in 5+ environments. Never
  duplicate threshold values elsewhere.

## Project skills

- `sky-screen` — implement a screen from the `Sky_App_Workflow.md` catalog,
  wired to the design system.
- `sky-component` — add or change a `Core/DesignSystem` component honoring tokens.
