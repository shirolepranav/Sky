# Phase 0 — Foundation Setup: Completion Checklist

Code/project scaffolding is done in the repo. The remaining items require an
Apple ID / Apple Developer account or a full Xcode build, so they're **yours to
do**. Phase 0 isn't "green" until every box is checked (Roadmap Phase 0).

## Apple Developer portal (do day one — Family Controls approval takes weeks)

- [x] Submit the **Family Controls Framework** entitlement request at
      <https://developer.apple.com/contact/request/family-controls> (the
      `/family-controls-distribution` URL now redirects to this same form).
- [x] Screenshot the confirmation page for records.
- [x] Apple approved the request — confirmed both by the approval email
      (Jun 21, 2026: "The entitlement for Family Controls (Distribution) has
      been assigned to your account...") and, more authoritatively, directly in
      the portal on 2026-08-06: **Certificates, Identifiers & Profiles →
      Identifiers**, each of the 4 App IDs (`com.shirolepranav.sky`,
      `.deviceactivity`, `.shieldaction`, `.shieldconfig`) shows **Family
      Controls (Distribution)** checked under Capabilities. This grant covers
      both development and App Store/TestFlight.

> Current public guidance (an Apple DTS engineer's forum response plus several
> 2026 developer reports) says this entitlement is normally requested/approved
> **per bundle ID** and does **not** automatically cascade from the main app to
> extensions — so don't assume one submission is enough on a *new* project
> without checking the portal per App ID, the way we verified here. For Sky
> specifically, the portal confirms all 4 IDs are enabled regardless of the
> underlying request mechanism.
>
> Provisioning profiles: confirmed **2026-08-07** these don't need manual
> generation. `xcodebuild archive` + `-exportArchive` (ExportOptions method
> `app-store-connect`, `signingStyle: automatic`) produced a real `.ipa` signed
> `Apple Distribution: Pranav Shirole (6WSVMM9FGS)` on all 4 targets — Xcode
> auto-generated "iOS Team Store Provisioning Profile" per bundle ID on the fly
> during export. Note: a bare `xcodebuild archive` on its own signs with your
> **Development** identity by default (a known CLI quirk, not a project bug) —
> the `-exportArchive` step is what actually re-signs for distribution. Xcode's
> Organizer UI ("Product → Archive" then "Distribute App") handles this
> transparently if you archive that way instead.

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

> Note: Family Controls (Distribution) is now approved on all 4 App IDs (see
> above), so signing should no longer report it as pending. If Xcode still shows
> a pending/missing-entitlement error after selecting your Team, try Product →
> Clean Build Folder and re-signing — the portal-side approval can lag a stale
> local profile cache.

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
