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
- [ ] Toggle Settings → Appearance across System / Light / Dark; confirm the whole
      app recolors and the choice **persists across relaunch**.
- [ ] With mode = System, flip the iOS system appearance; confirm live adaptation.
- [ ] Read every screen in **dark mode** for the text-on-accent regression (pills,
      chips, verified/streak badges, paywall tier badges) — nothing invisible.
- [ ] Camera / verification recording stays black with white controls in both modes.
- [ ] Nimbus + badge/milestone overlays legible in both modes.
- [ ] Largest allowed Dynamic Type size: Today hero, progress ring, Settings, and
      Verification don't clip or overlap.
- [ ] VoiceOver sweep of Today, Verify, Settings, Appearance — icon controls, the
      ring, and the mascot announce meaningfully.
- [ ] `accessibilityReduceMotion` on: Nimbus bob freezes, overlay transitions
      shorten.

## App Store assets (Phase 15 carry-over, now unblocked)
- [ ] Six screenshots per key flow captured in **both light and dark** on iPhone
      16 Pro Max.
- [ ] Optional: iOS-18 dark / tinted app-icon variant added to
      `Assets.xcassets/AppIcon.appiconset`.

## Account / entitlement / hosting (cannot be done from the codebase)
- [ ] Family Controls **Distribution** entitlement approved for all 4 bundle IDs
      (main app + 3 extensions).
- [ ] Tested on iOS 17.0, 17.6, and latest 18.x.
- [ ] Tested on iPhone SE (3rd gen), iPhone 14, iPhone 16 Pro Max.
- [ ] No paid-user entitlement leaks in the StoreKit sandbox.
- [ ] Privacy Nutrition Label matches actual data handling (on-device only, no
      remote push, GPS rounded to 0.01°, videos deleted after processing).
- [ ] App Review notes justify Family Controls usage.
- [ ] CloudKit **production** schema deployed.
- [ ] Founder's Lifetime SKU configured with limited availability.
- [ ] 7 days crash-free in TestFlight (20+ beta testers).
- [ ] No third-party SDKs in the binary.
- [ ] Privacy policy & terms hosted and linked; support email active.

## Privacy invariants (re-verify — unchanged by Phase 16)
- [ ] Verification videos written to `temporaryDirectory`, deleted after pass/fail.
- [ ] Emergency-unlock reasons stay in the App Group container (never CloudKit).
- [ ] No remote-push permission requested by `LocalNotificationScheduler`.
