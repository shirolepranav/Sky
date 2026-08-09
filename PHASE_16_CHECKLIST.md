# Phase 16 — Launch Readiness Checklist

Phase 16 = the pre-submission gate. The **code** deliverables (dark mode,
appearance picker, Dynamic Type) are implemented in this branch. The items below
are the account / device / hosting steps that must be done outside the codebase
before submitting to the App Store. **Do not submit while any box is unchecked.**

## Dark mode (code — done in this branch)
- [x] Adaptive color tokens in `ColorTokens.swift` (`Color(light:dark:)`), semantic
      surfaces / text / cream / divider now resolve per interface style.
- [x] `inkOnAccent` fixed token for content on bright accent fills (fixes the
      TierCard yellow badge; audited all accent-fill hosts).
- [x] Appearance picker (System / Light / Dark) — `AppearanceView` (S-SET-10),
      persisted via `SharedDefaults.appearanceModeRaw`, applied at the app root
      with `.preferredColorScheme`.
- [x] Milestone celebration gradient made adaptive (night-sky in dark).
- [x] Dynamic Type support via `@ScaledMetric` in `Typography.swift`, clamped to
      `…accessibility1` at the root.

## Manual QA (device / simulator — do before submission)
- [x] Appearance persistence/reactivity — verified **2026-08-07 at the code level**
      (no interactive device pass yet): `AppearanceManager` reads/writes
      `SharedDefaults.appearanceModeRaw` on init/change, so the choice survives
      relaunch; `mode.colorScheme` returns `nil` for System, which lets SwiftUI's
      `.preferredColorScheme(nil)` track live OS appearance changes automatically.
- [x] Dark-mode legibility spot check — **2026-08-07**, screenshotted the
      onboarding intro (`SplashView`/`OnboardingPage`) in Simulator (iPhone 17 Pro
      Max) in both light and dark: warm cream vs. deep navy background (neither
      pure white/black), ink/white text, Nimbus mascot with adjusted shadow all
      correct. Not a full per-screen sweep — still do the pills/chips/badge pass
      below on other screens.
- [ ] Read every screen in **dark mode** for the text-on-accent regression (pills,
      chips, verified/streak badges, paywall tier badges) — nothing invisible.
- [ ] Camera / verification recording stays black with white controls in both modes.
- [ ] Nimbus + badge/milestone overlays legible in both modes.
- [x] Largest allowed Dynamic Type size — verified **2026-08-07**: screenshotted
      onboarding intro at XXXL and at the OS max (accessibility5); text wraps
      cleanly with no clipping/overlap at XXXL, and the accessibility5 screenshot
      is visually near-identical to XXXL, confirming the `@ScaledMetric` clamp to
      `.accessibility1` in `Typography.swift` works. Only one screen checked —
      Today hero, progress ring, and Verification still need the same check.
- [ ] VoiceOver sweep of Today, Verify, Settings, Appearance — icon controls, the
      ring, and the mascot announce meaningfully. (Code check only so far: 14
      files reference `accessibilityReduceMotion`/labels; no live VoiceOver audio
      pass done — needs a real device or Simulator + VoiceOver.)
- [x] `accessibilityReduceMotion` coverage — verified **2026-08-07** via code
      search: respected in `NimbusView`, `SkyMotion`, `SkyToast`,
      `BadgeUnlockOverlayView`, `MilestoneOverlayView`, `VerificationSuccessView`,
      `VideoRecordingView`, `StreaksView`, `TodayView`, `PauseSkyView`,
      `EmergencyUnlockTypedReasonView`, `BudgetPage`, `SplashView`,
      `PageIndicator` (14 files). Not independently verified that motion actually
      visibly stops in each — code presence only.

## App Store assets (Phase 15 carry-over, now unblocked)
- [ ] Six screenshots per key flow captured in **both light and dark** on iPhone
      16 Pro Max.
- [ ] Optional: iOS-18 dark / tinted app-icon variant added to
      `Assets.xcassets/AppIcon.appiconset`.

## Account / entitlement / hosting (cannot be done from the codebase)
- [x] Family Controls **Distribution** entitlement approved for all 4 bundle IDs
      (main app + 3 extensions) — confirmed 2026-08-06 via Certificates,
      Identifiers & Profiles → Identifiers: each of `com.shirolepranav.sky`,
      `.deviceactivity`, `.shieldaction`, `.shieldconfig` shows "Family Controls
      (Distribution)" checked under Capabilities. **End-to-end verified
      2026-08-07**: `xcodebuild archive` + `-exportArchive` (method
      `app-store-connect`) produced a real `.ipa` signed
      `Apple Distribution: Pranav Shirole (6WSVMM9FGS)` on all 4 targets, with
      Xcode auto-generating "iOS Team Store Provisioning Profile" for each
      bundle ID on the fly — no manual profile generation needed.
- [ ] Tested on iOS 17.0, 17.6, and latest 18.x.
- [ ] Tested on iPhone SE (3rd gen), iPhone 14, iPhone 16 Pro Max.
- [ ] No paid-user entitlement leaks in the StoreKit sandbox.
- [ ] Privacy Nutrition Label matches actual data handling (on-device only, no
      remote push, GPS rounded to 0.01°, videos deleted after processing).
- [ ] App Review notes justify Family Controls usage.
- [ ] CloudKit **production** schema deployed.
- [ ] `com.sky.pro.lifetime` configured as a non-consumable at $19.99 with regional pricing.
- [ ] 7 days crash-free in TestFlight (20+ beta testers).
- [ ] No third-party SDKs in the binary.
- [ ] Privacy policy & terms hosted and linked; support email active.

## Privacy invariants (re-verify — unchanged by Phase 16)
- [ ] Verification videos written to `temporaryDirectory`, deleted after pass/fail.
- [ ] Emergency-unlock reasons stay in the App Group container (never CloudKit).
- [ ] No remote-push permission requested by `LocalNotificationScheduler`.
