# App Store Submission — Sky v1.0

Text-based submission package for Phase 15. Binary assets (icon, screenshots) are
produced in Xcode / design tools — see the checklist at the bottom. Everything here
must match the on-device behavior and the privacy invariants in `CLAUDE.md` and
`Sky_Technical_Spec.md §14`.

---

## App Store Connect — listing

**Name:** Sky
**Subtitle:** Touch grass to unlock your apps

**Promotional text (170 char):**
Sky blocks your time-wasting apps after a daily limit. The only way back in is a
verified 30-second walk outside. No skips, no bypass — just Nimbus, waiting in the sky.

**Description:**
> Sky is a screen-time app for people who actually want to quit — not just track it.
>
> Pick the apps that eat your day. Set a daily limit. When you hit it, Sky blocks them.
>
> There's no "5 more minutes" button and no skip credits. The one way back in is to go
> outside and record a short, private, on-device-verified video of the real world —
> daylight, movement, open sky. Nimbus, your cloud companion, is waiting out there.
>
> • Block any apps or whole categories after a daily budget
> • Strict outdoor verification — checked entirely on your device
> • Streaks and gentle badges for showing up
> • Friendly, honest notifications (never guilt-trips)
> • A friction-loaded emergency unlock for the days life genuinely requires it
>
> Privacy first: your verification videos are deleted the moment they're checked and
> never leave your phone. No third-party SDKs. No ads. No accounts to create.
>
> Sky Pro unlocks more than two apps, per-app limits, a weekly 24-hour pause, and
> streak-risk reminders.

**Keywords (ASO, ≤100 char):**
`screen time,block apps,touch grass,digital detox,focus,go outside,app blocker,streak,limit`

**Support URL:** https://sky.app/support
**Marketing URL:** https://sky.app
**Privacy Policy URL:** https://sky.app/privacy  *(must be live before submission)*

---

## Privacy Nutrition Label (App Store Connect → App Privacy)

Declare **Data Not Collected**. Sky collects and transmits no personal data. Specifically:

| Category | Declaration |
|---|---|
| Contact info, identifiers | Not collected |
| Health, financial, location | **Not collected off-device.** GPS is used transiently for verification, rounded to 0.01°, and never transmitted. |
| User content (videos, reasons) | **Not collected.** Verification videos are deleted immediately after processing; emergency/pause reasons stay in the App Group container. |
| Usage data / diagnostics | Not collected. No third-party analytics SDKs. |
| Purchases | Handled by Apple (StoreKit). One non-consumable, no subscriptions. Sky stores no purchase data on any server. |
| Photos | **Not collected.** `NSPhotoLibraryAddUsageDescription` exists only so the user can pick "Save Image" for a streak card they chose to share. Sky never reads the photo library. |

iCloud (CloudKit) sync of streak/progress uses the user's **private** CloudKit
database and is not "data collection by the developer" — no data reaches a Sky server.

---

## App Review notes (App Store Connect → App Review Information)

> **Family Controls usage.** Sky uses the Family Controls, Managed Settings, and
> Device Activity frameworks for **individual self-management** — the user restricts
> their *own* apps on their *own* device. This is NOT a parental-controls or MDM app;
> there is no second user, no guardian/child relationship, and no remote management.
>
> **Verification.** Unlocking a blocked app requires a ~30-second outdoor video that is
> analyzed entirely on-device (Vision + Core Location + sensor fusion) and then deleted.
> No video, location, or screen-time data is uploaded.
>
> **To test:** use the bundled StoreKit configuration for Pro. On the Settings tab, the
> version row unlocks a debug menu (tap 7×) with "Force shield apply" and "Simulate Pro"
> so review can exercise the blocked → verify flow without waiting out a real budget.
>
> The Family Controls Distribution entitlement is approved for all four bundle IDs
> (main app + Shield, Shield Action, and Device Activity Monitor extensions).

---

## Notifications (all local)

Sky requests only `.alert` + `.sound` local authorization and **never** registers for
remote push / APNs (`LocalNotificationScheduler`, and the Device Activity Monitor
extension for event-driven ones). Four notifications: morning reminder (8:30 AM),
30-minute pre-block warning, block-start (always on), and a Pro 10 PM streak warning.

---

## Binary asset checklist (produce in Xcode / design tools)

- [ ] App icon: 1024×1024 source + all required sizes in the asset catalog (derive from
      Nimbus via `NimbusPNGExporter` / design source; no alpha on the 1024 marketing icon).
- [ ] 6 screenshots — iPhone 6.9" (16 Pro Max) **and** 6.5", light + dark:
      1. Onboarding / Nimbus intro
      2. App picker (S-CFG-01)
      3. Today with mascot + streak (S-TODAY-01)
      4. Verification recording (S-VER)
      5. Verification success (S-VER-06)
      6. Paywall (S-PAY-01)
- [ ] Privacy policy + terms hosted and linked (URLs in `AppBranding`).
- [ ] Support email account active and monitored.

## Final pre-submission gate

Mirror `Sky_Development_Roadmap.md` "Final Pre-Submission Checklist" (lines 616–633):
entitlement approved for all four bundle IDs; tested on iOS 17.0 / 17.6 / latest 18.x
and on iPhone SE 3 / 14 / 16 Pro Max; no leaked sandbox entitlements; Privacy Label
matches behavior; CloudKit production schema deployed; `com.sky.pro.lifetime`
configured as a $19.99 non-consumable; 7 crash-free days in TestFlight with ≥20 testers; `otool -L`
shows no third-party SDKs; policy/terms hosted; support inbox live.
