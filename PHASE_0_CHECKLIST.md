# Phase 0 — Foundation Setup: Completion Checklist

Code/project scaffolding is done in the repo. The remaining items require an
Apple ID / Apple Developer account or a full Xcode build, so they're **yours to
do**. Phase 0 isn't "green" until every box is checked (Roadmap Phase 0).

## Apple Developer portal (do day one — Family Controls approval takes weeks)

- [x] Submit the **Family Controls Framework** entitlement request at
      <https://developer.apple.com/contact/request/family-controls> (the
      `/family-controls-distribution` URL now redirects to this same form).
      The form asks only for Name / Email / **Team ID** — it is granted at the
      **team level** (Team `6WSVMM9FGS`), so **one** submission covers the main
      app *and* all 3 extensions. Do **not** submit per bundle ID.
- [ ] Screenshot the confirmation page for records.
- [ ] Wait for Apple's approval email (typically a few hours up to ~4 weeks).
      This single grant covers both development and App Store/TestFlight.

> Sky does **not** need the more privileged
> `com.apple.developer.family-controls.app-and-website-usage` entitlement — the
> standard shield + DeviceActivity APIs are covered by the request above.

## In Xcode (Signing & Capabilities)

- [ ] Open `Sky.xcodeproj`. For **each** of the 4 targets, select your **Team**
      under Signing & Capabilities (lets Xcode auto-register the App IDs).
- [ ] Confirm the **App Group** `group.com.shirolepranav.sky` shows enabled on all 4
      targets (entitlements files already declare it; Xcode registers it on the
      portal when you sign).
- [ ] Confirm **iCloud → CloudKit** (container `iCloud.com.shirolepranav.sky`) and
      **Sign in with Apple** show enabled on the **Sky** target.
- [ ] If the **SkyTests** action isn't in the Sky scheme, add it:
      Product → Scheme → Edit Scheme → Test → **+** → SkyTests.

> Note: until Apple approves the Family Controls requests, signing may report the
> `family-controls` entitlement as **pending** on a personal team. That's the
> expected "entitlement-pending state" (Roadmap Phase 0 manual test) — keep going.

## Build & test verification (the part this machine can't run)

- [ ] **Build all 4 targets** in **Debug** and **Release** — no errors.
- [ ] App runs and launches `DesignSystemPreviewScreen` (no behavior change).
- [ ] Run **SkyTests** — `testColorValuesParseCorrectly` and
      `testProductIDsAreUnique` both pass.

## Deferred (intentionally NOT Phase 0)

- App Store Connect product/subscription setup → Phase 14.
- `NSCameraUsageDescription` / `NSLocationWhenInUseUsageDescription` → Phase 7.
- "Treat warnings as errors" + "Strict Concurrency = Complete" (Tech Spec §15):
  recommend enabling once a Team is set and the baseline build is green, so any
  resulting warnings surface against a known-good build rather than during setup.
