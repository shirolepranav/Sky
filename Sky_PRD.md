# Sky — Product Requirements Document (PRD)

*Working title: "Sky." Mascot: "Nimbus." Both names live in `AppBranding.swift` and can be renamed by editing one file.*

---

## 1. Vision & Positioning

Sky is an iOS app that helps people break the doomscroll loop by physically getting them outside. **Every morning at a time the user picks, selected social apps pause — and they stay paused until the user goes outside.** A short walk plus a 5-second clip of the sky unlocks them for the rest of the day. The hook: *"My phone doesn't work until I go outside."* (Model adopted 2026-10-14 — see `DAILY_LOCK_PLAN.md`.)

**Positioning:** *"Touch Grass for people who actually want to quit."* Step count + GPS + sky-clip verification, Screen Time API enforcement, a daily morning lock, friendly cloud mascot. No skip credits. No escape hatches beyond a friction-loaded emergency override.

**Target user:** Gen Z and younger millennials (16–32) doing self-improvement, "dopamine detox," or "phone detox." Price-sensitive, organic-acquisition-friendly, shares apps on TikTok and Reddit.

---

## 2. Problem Statement

Existing screen-time apps fail because they make blocking too easy to bypass:
- Apple Screen Time has a "One more minute" button that trains users to ignore it
- Most third-party apps can be uninstalled or disabled in Settings
- The current category leader for outdoor verification (Touch Grass) uses a single photo of grass and sells skip credits, so high-motivation users find it ineffective

Sky exists for users who **want the friction**. The verification has to be genuinely hard to fool, and the app has to be genuinely hard to bypass.

---

## 3. Core User Journey

1. User downloads Sky, sees onboarding featuring Nimbus the cloud mascot
2. User grants Family Controls (Screen Time) authorization for individual mode
3. User picks which apps to lock via Apple's `FamilyActivityPicker` (typically Instagram, TikTok, Snapchat, X)
4. User picks a **lock time** (default 9:00 AM)
5. Every day at the lock time the selected apps pause. Tapping one shows Nimbus and an "Unlock with Sky" button
6. User takes a short walk outside (~200 steps), opens Sky, and films a 5-second clip tilting from the ground up to the sky
7. Sky checks GPS, recent steps, and (in daylight) the scene — entirely on-device
8. On success the apps stay open **until the next lock time**; Nimbus brightens; the streak counter increments
9. Going outside *before* the lock time (an early bird) skips that day's lock
10. If the user never goes outside, the apps stay paused — midnight does not release them

> **Why a morning lock, not a usage budget.** The usage-threshold model counted
> screen time with `DeviceActivityEvent` thresholds, which fired at arbitrary
> times ("30 minutes left" on days the apps were never opened) and buried the
> hook under mechanics. Scheduled interval starts are the reliable part of the
> Screen Time API, and "apps pause until you go outside" is one sentence anyone
> can repeat.

**Alternative path (emergency unlock):** If user can't or won't go outside, they tap "Emergency unlock" → must type (not paste) a reason why they need to unlock → 5-second forced pause → apps unlock but streak breaks and Nimbus turns sad/rainy.

---

## 4. Features in v1.0

### 4.1 App Selection
- User can pick any combination of apps and app categories using Apple's `FamilyActivityPicker`
- Apple's system shows opaque tokens — Sky cannot name apps directly, only the user sees the names
- Selection persists across app launches and iOS updates (with re-pick fallback if tokens become invalid)

### 4.2 Lock Time Configuration
- **Lock time:** when the selected apps pause each day — every 30 minutes from 5:00 AM to 11:00 PM, default 9:00 AM
- **Lock days (Pro):** which weekdays the lock applies (e.g. weekends off). Free users lock every day
- Moving the lock time to an hour already past today applies immediately; finishing first-time setup after today's lock time waives only that first day

### 4.3 Screen Time Enforcement
- Built on `FamilyControls`, `DeviceActivity`, and `ManagedSettings` frameworks
- Two daily schedules, no usage events: a midnight rollover and a lock-time schedule whose start shields the selection
- If the lock-time callback is missed, the app applies the lock on its next foreground
- App icon launch is replaced by the shield until the user verifies

### 4.4 Outdoor Verification
A **5-second clip**, captured live in-app, tilting from the ground up to the sky. Never uploaded; deleted right after processing.

Three checks, all on-device (thresholds live in `VerificationThresholds.swift` and are placeholders until field-tested):
1. **GPS:** not spoofed (`sourceInformation`), horizontal accuracy ≤ 50 m. A cached fix up to 60 s old is accepted, and Sky waits up to 6 s after the clip for one
2. **Steps:** ≥ 200 steps in the 15 minutes before recording, read from `CMPedometer` history — the walk happens first, Sky needn't be open. Waived on devices without step counting
3. **Outdoor scene (daylight only):** ≥ 60% of sampled frames classify outdoor *and* the best frame shows ≥ 10% sky. After civil dusk this check is waived and GPS + steps decide — which is what makes evening verification work

The intro screen shows a live step count toward the goal.

### 4.5 Emergency Unlock (Typed-Reason Path)
- Accessible from the shield UI as "Emergency unlock"
- Opens a modal requiring the user to type (not paste) why they need the app
- Minimum 20 characters; maximum 200 characters
- "Unlock" button is disabled until the user has waited 5 seconds and met character minimum
- Paste action disabled at the text field level (UIViewRepresentable override of `canPerformAction(_:withSender:)`)
- On confirmation: apps unlock until the next lock time, streak resets, Nimbus turns into a sad rainy cloud for the rest of the day
- Reason text logged locally so the user sees a weekly "Top reasons you unlocked" insight

### 4.6 Daily Rollover
- At 00:00 local time streaks update based on whether a verification or emergency unlock happened yesterday, and the per-day flags reset
- **Midnight never touches the lock.** An unverified day stays paused until the user goes outside; a verified one stays open until the next lock time

### 4.7 Nimbus the Mascot
Mascot has 5 visual states tied directly to user behavior:
- **Cloudy-grey (default indoor):** Default appearance when limits are active and user hasn't verified today
- **Fluffy white (idle):** Normal state before the lock time, with apps open
- **Sunny (happy):** Right after a successful outdoor verification (24-hour state)
- **Rainbow (streak celebration):** When user hits a milestone streak (3, 7, 14, 30, 60, 100 days)
- **Rainy (sad):** When user uses an emergency unlock or breaks a streak

Mascot is built as composable SwiftUI shapes plus optional Lottie file for v1.1+; can be replaced by swapping a single `MascotView` component.

### 4.8 Streaks & Badges (v1.0 — Local & CloudKit only)
- Current streak (consecutive days with a successful verification *and* no emergency unlock)
- Longest streak ever
- Total verifications
- 10 launch badges:
  - First verification ("First Light")
  - 3-day streak ("Cumulus")
  - 7-day streak ("Stratus")
  - 14-day streak ("Cirrus")
  - 30-day streak ("Sunburst")
  - 60-day streak ("Clear Sky")
  - 100-day streak ("Boundless")
  - First verification before 8am ("Early Bird")
  - 5 different verification locations ("Wanderer")
  - First emergency unlock recovered with a 7-day streak afterward ("Comeback")

All progress syncs across user's devices via CloudKit private database. No leaderboards or social in v1.0.

### 4.9 Pricing & Paywall
- **Free tier:** Lock up to 2 apps, every day, daily verification, mascot, streaks
- **Sky Pro:** **$19.99 one-time** — unlimited apps, lock days (e.g. weekends off), all badges, all mascot states, full insights, 24-hour pause
- **One SKU only.** A single non-consumable (`com.sky.pro.lifetime`). No subscriptions, no tiers, no founder's edition. The target user is price-sensitive and subscription-averse (§2), so the pitch is "pay once, yours forever" rather than a tier ladder.
- **No free trial.** Apple does not offer introductory offers on non-consumables; the free tier serves that purpose.
- Regional pricing is configured per-storefront in App Store Connect. A launch discount is done by shipping at a lower base price and raising it later — not by adding a second SKU.
- Restore purchases is required and always available (paywall + S-SET-07).
- Implemented via StoreKit 2 directly (no RevenueCat in v1.0; can be added later)

### 4.10 Settings
- Manage selected apps (re-open FamilyActivityPicker)
- Manage the lock time and (Pro) lock days
- Pause Sky for 24 hours (Pro only, max once per week, requires emergency-style typed confirmation)
- Notifications (toggle the streak warning; the lock notification is always on)
- Sign in with Apple (for CloudKit sync verification)
- Manage subscription (deep link to App Store)
- Restore purchases
- Privacy policy, terms, support email, version

### 4.11 Notifications (local only, v1.0)
- **Lock time:** "Apps are paused — Nimbus is waiting outside for you ☁" (always on, once a day; tap opens verification)
- **Shield button tap:** "Tap to head outside and unlock your apps ☁" — the shield can't open Sky directly, so a tap posts this and the notification opens the right screen
- **Streak warning at 10 PM:** "Don't break your 14-day streak — verify or it resets at midnight." (toggleable, Pro only)
- ~~30-minute warning / "Time's up"~~ — removed with the usage budget. ~~8:30 AM morning hello~~ — removed earlier

---

## 5. Explicit Non-Goals for v1.0

- **No friend leaderboards or social features.** Deferred to v2.
- **No Android.** iOS only.
- **No Apple Watch companion.** May add post-launch based on demand.
- **No cloud AI verification.** On-device only; no user videos leave the phone.
- **No skip credits or pay-to-bypass.** Strict philosophy.
- **No DNS/VPN-based blocking workarounds.** Family Controls API only.
- **No real-time accountability partners or shared sessions.** v2.
- **No web dashboard.** App-only.

---

## 6. Success Metrics

### Launch metrics (first 90 days)
- App Store rating ≥ 4.4
- D1 retention ≥ 35% (industry benchmark for productivity)
- D7 retention ≥ 18%
- Install-to-paid conversion ≥ 3% (Day 35)
- Successful verification rate when attempted ≥ 90% (target outdoors first try)
- Emergency unlock rate < 30% of all unlocks (we want users actually going outside)

### Year-1 targets
- 50,000+ installs
- $25,000+ ARR (realistic case for solo dev with organic-only acquisition)
- Median user reduces selected-app screen time by ≥ 25% (self-reported in App Store reviews)

### Anti-goals (we are not optimizing for these)
- DAU/MAU ratio — Sky succeeds when users open it *less*, not more
- Time spent in Sky — short verification sessions are good
- Notification engagement — friendly nudges, never naggy

---

## 7. Brand & Tone

- **Visual:** Calm, cute, soft. Sky-blue (`#A8D8EA`), warm cream (`#FFF6E5`), moss green accent (`#7CB342`), gentle coral for streaks (`#FF8A7A`). Never pure white or pure black.
- **Typography:** SF Rounded (built-in). Generous line height.
- **Voice:** Friendly but honest. Never guilt-trip in v1.0. The mascot reacts emotionally to user behavior, but copy stays warm. Example shield message: *"Selected apps are paused for today. Nimbus is waiting outside for you. ☁️"* — not *"You've wasted enough time."*
- **Animation:** Subtle, never jarring. Mascot has 3 idle loops + 1 transition per state change.

---

## 8. Privacy Commitments

These commitments are also marketing — Sky's strict on-device verification is a competitive advantage:

- **No video upload, ever.** Verification videos exist only on the user's device; deleted automatically after verification completes (success or fail)
- **No raw screen time data sent to any server.** Apple's API prevents this anyway, and Sky has no backend that would store it
- **No app names sent to any server.** Apple's opaque-token system enforces this
- **CloudKit private database only.** User progress (streaks, badges, mascot state) syncs only to user's own iCloud account
- **No third-party analytics SDKs in v1.0.** Apple's privacy-respecting App Store analytics only
- **Emergency-unlock reasons stay on-device.** Never sent anywhere

These commitments are displayed prominently in onboarding and on the App Store listing.

---

## 9. Risks & Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple Family Controls Distribution entitlement denied or delayed | Medium | Apply Phase 0; have a "we're waiting on Apple" landing page; do not start verification work until applied |
| iOS 27 breaks the Screen Time API | Medium | Build the verification engine modularly so it can survive an API replacement |
| Touch Grass copies strict verification | High | Ship faster; the mascot + emergency-typed-reason UX is the deeper moat |
| User verification fails too often in real conditions | High | Thresholds must be tuned on real devices in 5+ environments before launch (urban park, suburban yard, basement, near-window, sunny street) |
| Camera/Vision changes in iOS 18.x → 19.x | Low | Test on iOS 17.0, 17.6, 18.x, 19 beta before each release |
| Family Controls entitlement requires re-application after major iOS upgrade | Documented in Apple forums | Plan one buffer week before each iOS major release |

---

## 10. Versioning Plan

- **v1.0** — Everything in this document
- **v1.1** — Polish based on launch feedback, Lottie mascot animations, additional badges
- **v1.2** — Cosmetic mascot skins (in-app purchases), seasonal events
- **v2.0** — Friends & leaderboards (self-reported streaks), accountability partners, weekly check-in summaries
- **v3.0** — Apple Watch companion, iPad optimization, "outdoor moments" photo journal

---

## 11. Appendix: AppBranding Constants

The following constants live in a single file and define all swappable branding:

```swift
struct AppBranding {
    // Product
    static let appName = "Sky"
    static let appNameTagline = "Touch grass for people who actually want to quit."

    // Mascot
    static let mascotName = "Nimbus"
    static let mascotPronouns = "they"  // "Nimbus is waiting" — keep singular/neutral

    // Color palette
    static let primarySky = Color(hex: "A8D8EA")
    static let warmCream = Color(hex: "FFF6E5")
    static let mossGreen = Color(hex: "7CB342")
    static let coralStreak = Color(hex: "FF8A7A")
    static let cloudGrey = Color(hex: "B8C5D0")
    static let sunYellow = Color(hex: "FFD66B")

    // Product ID (App Store Connect) — one non-consumable, no subscriptions
    static let lifetimeProductID = "com.sky.pro.lifetime"
}
```

Renaming the app or mascot requires editing only this file.
