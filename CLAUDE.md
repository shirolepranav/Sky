# CLAUDE.md

Guidance for working in the Sky codebase. Read this first.

## What Sky is

iOS app (SwiftUI, iOS 17+) that blocks selected social apps after a time budget
and requires a verified ~30-second **outdoor video** to unlock them. The
strict on-device verification is the entire product. Friendly cloud mascot
("Nimbus"). No skip credits; the only escape is a friction-loaded emergency
unlock. iOS-only, no third-party SDKs, on-device only (no user videos leave the
phone).

A pass buys **one more session** — another budget's worth of usage — not the rest
of the day. iOS will not deliver a second threshold callback for the same event
in one day, so `DeviceActivityService` pre-registers a *ladder* of events at 1×,
2×, 3×… the session length, and `SkyDeviceActivityMonitor` tracks the highest
rung it has acted on. Read that file's header before touching monitoring. The
emergency unlock is the one path that still covers the whole day.

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

**All 16 roadmap phases are built** (through Phase 16 — Launch Readiness & Dark
Mode). The layout follows `Sky_Technical_Spec.md §5`:

- `Sky/App/` — `SkyApp.swift` (@main, routing via `AppCoordinator`),
  `AppBranding.swift` (PRD §11 swappable constants).
- `Sky/Core/` — `DesignSystem/` (color/type/spacing/motion tokens, buttons,
  cards, icons, ring, toast), plus `Notifications/`, `ScreenTime/`, `Storage/`,
  `Subscription/`.
- `Sky/Features/` — AppSelection, Celebrations, EmergencyUnlock,
  LimitConfiguration, Mascot (`NimbusView.swift` + `NimbusRendering.swift`),
  Onboarding, Paywall, Permissions, Settings, Streaks, Today, Verification.
- Extension targets: `DeviceActivityMonitorExtension/`,
  `ShieldActionExtension/`, `ShieldConfigurationExtension/`.
- Tests: `SkyTests/` (unit), `SkyUITests/`.

Keep this section a short orientation only — the folder tree is the source of
truth. Per-phase checklists live in `PHASE_*_CHECKLIST.md`.

## Build & verify

**Full Xcode is required to build/run/preview** (iOS SDK, Simulator, `#Preview`
macro). Open `Sky.xcodeproj` in Xcode 16+. The project uses a file-system
synchronized group, so **new `.swift` files under `Sky/` are picked up
automatically** — no need to edit the project file.

**Xcode is installed** (`/Applications/Xcode.app`), but `xcode-select` still
points at the Command Line Tools and repointing it needs `sudo`. Prefix commands
with `DEVELOPER_DIR` instead — no password required:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Sky.xcodeproj -scheme Sky -destination 'generic/platform=iOS Simulator' build
```

This is a real iOS build and is always preferred over the macOS type-check
fallback below. Run the unit tests the same way:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Sky.xcodeproj -scheme Sky -destination 'platform=iOS Simulator,name=iPhone 17'
```

The suite runs **266 tests, 2 failures** (plus 8 StoreKit tests skipped on runtimes
where StoreKit Testing is broken — see gap 1 below). The 2 are long-standing and live
in `OnboardingViewModelTests` and `SetupRoutingTests` — **not** regressions. Treat
that as the baseline; a change is clean if it adds no failures beyond those.

The old baseline said "242 tests, 8 failures", 6 of which were assertion failures
inside a single `SunriseSunsetTests` case. Those were **bad reference data, not an
algorithm bug**: the Helsinki vector implied a 4h47m winter-solstice day when the
true length at 60.17°N is 5h55m. The vectors were regenerated from an independent
source and the suite now passes. `SolarCalculator` does still drift ~4.5 min at 60°N
(vs ~1 min at the equator), which is why `toleranceSeconds` is 420 rather than 120 —
see the rationale comment on that constant before tightening it.

Several tests read and write the real `SharedDefaults` / `UserDefaults.standard`
and don't reset it, so **stale simulator state can cause spurious failures**
(`GatingTests.testPerAppModeSetsGateFlagForFreeUser` is the usual victim — it
constructs a `LimitConfigurationViewModel`, which loads a persisted `limitMode`).
If you see a failure you can't explain, re-run after
`xcrun simctl erase <device>` before assuming your change caused it.

⚠️ **Known gaps — don't mistake these for regressions from your change:**

1. **StoreKit Testing is broken on the iOS 26.5 simulator runtime** — an Apple
   bug, not a project defect. `SKTestSession` connects to
   `com.apple.storekit.configuration.xpc` fine, but storekitd rejects the first
   "save configuration" request with `SKInternalErrorDomain Code=3`, leaving an
   empty storefront and zero products. **Run StoreKit tests on iOS 26.2**, where
   they all pass:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Sky.xcodeproj -scheme Sky -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyTests/StoreKitServiceTests
   ```
   On a bad runtime they skip (via `skipIfStoreKitTestingIsBroken()`) instead of
   failing red. Beware: `AppStore.sync()` *hangs* on a broken runtime, so any new
   restore test must call that guard first or it stalls the whole run.
2. **`#Preview` blocks must sit inside any `#if DEBUG` that guards the type they
   reference.** A preview left outside the `#endif` compiles in Debug but breaks
   the **Release** build — and therefore any archive for submission. Debug-only
   test seams follow the same rule; verify with
   `xcodebuild -configuration Release ... build`, which is not covered by a
   plain Debug build.
3. **Extension-point identifiers fail silently.** Shield *configuration* is
   `com.apple.ManagedSettingsUI.shield-configuration-service`; shield *action* is
   `com.apple.ManagedSettings.shield-action-service` — different namespaces, and
   the `UI` variant of the action point does not exist. A wrong identifier builds,
   signs and embeds cleanly, then PluginKit never matches the appex and the
   delegate is simply never called. `ShieldActionExtensionPointTests` reads the
   built `.appex` and pins all three.

**Fallback (no Xcode / preview-macro issues):** type-check the cross-platform
SwiftUI against the macOS SDK. The `#Preview` macro plugin needs full Xcode, so
strip preview blocks first:

```bash
tmp=$(mktemp -d)
for f in $(find Sky -name '*.swift'); do
  awk '/^#Preview/{exit}{print}' "$f" > "$tmp/$(echo "$f"|tr '/' '_')"
done
xcrun --sdk macosx swiftc -typecheck -target arm64-apple-macosx14.0 "$tmp"/*.swift
```

(macOS 14 ≙ iOS 17, the app's minimum target — needed for `keyframeAnimator`,
`phaseAnimator`, and `numericText(value:)`.) Note this only covers cross-platform
code: files touching FamilyControls, DeviceActivity, or `fullScreenCover` are
iOS-only and will error under the macOS SDK regardless of correctness. Exit 0
validates Swift/type correctness only — never iOS layout or runtime behavior.

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
- **Mascot is one replaceable component** (`NimbusView.swift` +
  `NimbusRendering.swift`). Swapping it (e.g. a Lottie file in v1.1+) must touch
  only those two files.
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

- **Family Controls Distribution entitlement** is approved for the main app and
  all 3 extension targets — confirmed 2026-08-06 via Certificates, Identifiers &
  Profiles → Identifiers → Capabilities, and end-to-end verified 2026-08-07 with
  a real `Apple Distribution`-signed `.ipa` export (see `PHASE_0_CHECKLIST.md`).
  A bare `xcodebuild archive` on its own signs with the Development identity by
  default (CLI quirk) — use `-exportArchive` with a `method: app-store-connect`
  ExportOptions.plist (or Xcode's Organizer UI) to get a real distribution build.
- Screen Time / Shield APIs are historically unstable across iOS versions — test
  on iOS 17.0, 17.6, latest 18.x.
- **iOS silently reissues `ApplicationToken`s.** The persisted
  `FamilyActivitySelection` is *our own* JSON, so iOS never touches it — it keeps
  decoding cleanly while the tokens inside stop matching any app. Stale tokens fire
  no threshold, so the shield is never applied and Sky silently stops working while
  the UI still says "monitoring". There is no reliable direct detection, so
  `SharedDefaults.selectionNeedsRedo` uses an **OS major-version change** as a proxy
  and `configFingerprint` mixes the OS version in so monitoring re-arms once per
  upgrade. Deliberate tradeoff: one false "Re-select apps" prompt per annual iOS
  release, versus a silent permanent failure with no user-facing recovery.
  ⚠️ `ShieldService.unlockApps` must keep assigning `nil` to
  `managed.shield.applications` rather than subtracting a token set — the nil clears
  orphaned old tokens too, and is the only reason a reissue can't strand a user
  permanently shielded.
- Verification thresholds (`VerificationThresholds.swift`) are the single tunable
  source. Never duplicate threshold values elsewhere. ⚠️ They are **not yet
  measured** — the file's own header says "re-measure against real-world recordings
  in 5+ environments before launch (Roadmap Phase 10)", so treat the current values
  as placeholders. (This line previously claimed they *had* been measured; the file
  is the authority.)
- **Night verification does not work**, and Night Mode is misleading about it.
  `SkyPixelCounter` gates sky detection on brightness (`v >= 0.35` blue, `v >= 0.75`
  overcast), so it returns ~0 in darkness. Night Mode waives only the daylight check,
  so a user who enables it is sent outside at night and then fails on "Show some
  sky." A DEBUG-only spike under
  `Sky/Features/Verification/VisionAnalysis/Debug/` measures candidate
  daylight-independent signals (depth, texture energy); a Core ML night-sky
  classifier is the intended primary fix because it is the only candidate that
  covers every iOS 17 device.

## Project skills

- `sky-screen` — implement a screen from the `Sky_App_Workflow.md` catalog,
  wired to the design system.
- `sky-component` — add or change a `Core/DesignSystem` component honoring tokens.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
