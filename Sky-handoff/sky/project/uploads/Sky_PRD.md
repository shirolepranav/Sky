# Sky — Product Requirements Document (PRD)

*Working title: "Sky." Mascot: "Nimbus." Both names live in `AppBranding.swift` and can be renamed by editing one file.*

---

## 1. Vision & Positioning

Sky is an iOS app that helps people break the doomscroll loop by physically getting them outside. It blocks selected social media apps after a user-set daily limit and requires a verified ~30-second outdoor video to unlock them again. The verification is strict by design — it is the entire product.

**Positioning:** *"Touch Grass for people who actually want to quit."* Multi-sensor video verification, Screen Time API enforcement, daily midnight reset, friendly cloud mascot. No skip credits. No escape hatches beyond a friction-loaded emergency override.

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
3. User picks which apps to block via Apple's `FamilyActivityPicker` (typically Instagram, TikTok, Snapchat, X)
4. User picks a daily time budget — combined (1/2/3 hours total) or per-app
5. User uses their phone normally throughout the day; Sky tracks usage silently
6. When the budget is reached, selected apps are blocked. Tapping a blocked app shows a shielded screen with Nimbus and a "Go outside to unlock" button
7. User goes outside, opens Sky, records a ~30-second video while following on-screen prompts
8. Sky verifies the video using GPS, barometer, light sensor, scene classification, and sky detection — entirely on-device
9. On success, apps unlock for the rest of the day; Nimbus brightens; streak counter increments
10. At midnight local time, usage resets and apps are blocked again at the configured budget

**Alternative path (emergency unlock):** If user can't or won't go outside, they tap "I can't go outside right now" → must type (not paste) a reason why they need to unlock → 5-second forced pause → apps unlock but streak breaks and Nimbus turns sad/rainy.

---

## 4. Features in v1.0

### 4.1 App Selection
- User can pick any combination of apps and app categories using Apple's `FamilyActivityPicker`
- Apple's system shows opaque tokens — Sky cannot name apps directly, only the user sees the names
- Selection persists across app launches and iOS updates (with re-pick fallback if tokens become invalid)

### 4.2 Time Limit Configuration
Two modes, user choice:
- **Combined limit:** Single total budget across all selected apps (1, 2, or 3 hours)
- **Per-app limits:** Individual budget for each selected app (15 min to 4 hours, in 15-minute steps)
- Limits reset at **midnight local time** daily

### 4.3 Screen Time Enforcement
- Built on `FamilyControls`, `DeviceActivity`, and `ManagedSettings` frameworks
- When threshold is hit, selected apps are shielded with a custom Sky UI
- App icon launch is replaced by the shield until the user verifies

### 4.4 Outdoor Video Verification (Strict)
30-second video required, captured live in-app, never uploaded.

Sky verifies all of the following on-device:
- **GPS:** location accuracy ≤ 25m and horizontal speed > 0.3 m/s at any point during recording
- **Barometric pressure:** detectable change in relative altitude over 30 seconds (walking)
- **Ambient light:** camera exposure/ISO indicates daylight-level brightness (or moonlit, with explicit night mode opt-in)
- **Scene classification:** `VNClassifyImageRequest` returns "outdoor," "sky," "tree," "grass," "park," "street," or similar in ≥ 80% of sampled frames
- **Sky pixel detection:** at least one segment of the video has ≥ 15% sky-colored pixels
- **Spoof check:** `CLLocation.sourceInformation.isProducedByAccessory` is false (rejects developer-injected GPS)
- **Time-of-day check:** verification must occur between sunrise and sunset (with user-toggleable night mode)

User sees the prompts during recording ("Point at the sky for 5 seconds", "Now slowly turn around"). All processing happens on-device using Apple Vision and Core Location.

### 4.5 Emergency Unlock (Typed-Reason Path)
- Accessible from the shield UI as "I can't go outside right now"
- Opens a modal requiring the user to type (not paste) why they need the app
- Minimum 20 characters; maximum 200 characters
- "Unlock" button is disabled until the user has waited 5 seconds and met character minimum
- Paste action disabled at the text field level (UIViewRepresentable override of `canPerformAction(_:withSender:)`)
- On confirmation: apps unlock, streak resets, Nimbus turns into a sad rainy cloud for the rest of the day
- Reason text logged locally so the user sees a weekly "Top reasons you unlocked" insight

### 4.6 Daily Midnight Reset
- At 00:00 local time:
  - Daily usage counters reset to zero
  - Shields reapply if previously unlocked via verification or emergency
  - Streaks update based on whether a verification or emergency unlock occurred yesterday

### 4.7 Nimbus the Mascot
Mascot has 5 visual states tied directly to user behavior:
- **Cloudy-grey (default indoor):** Default appearance when limits are active and user hasn't verified today
- **Fluffy white (idle):** Normal state when user is under budget
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
- **Free tier:** Block up to 2 apps, combined-limit mode only, daily verification, mascot, streaks
- **Sky Pro Monthly:** $4.99/month — unlimited apps, per-app limits, all badges, all mascot states, full insights
- **Sky Pro Annual:** $29.99/year (highlighted as default) — same as monthly + 7-day free trial on first install
- **Sky Pro Lifetime:** $79 — same forever, no recurring
- **Founder's Lifetime:** $39 — first 500 purchasers only, displayed in-app with remaining-seats counter, removed once cap is hit
- Implemented via StoreKit 2 directly (no RevenueCat in v1.0; can be added later)

### 4.10 Settings
- Manage selected apps (re-open FamilyActivityPicker)
- Manage limits (mode, durations)
- Pause Sky for 24 hours (Pro only, max once per week, requires emergency-style typed confirmation)
- Notifications (toggle morning reminder, mascot check-in, streak warning)
- Sign in with Apple (for CloudKit sync verification)
- Manage subscription (deep link to App Store)
- Restore purchases
- Privacy policy, terms, support email, version

### 4.11 Notifications (local only, v1.0)
- **8:30 AM local:** "Good morning. Nimbus is ready for today's outdoor break." (toggleable)
- **30 minutes before block:** "You have 30 minutes left on Instagram/TikTok/etc." (toggleable)
- **Block start:** "Selected apps are blocked. Go outside to unlock them." (always on)
- **Streak warning at 10 PM:** "Don't break your 14-day streak — verify or it resets at midnight." (toggleable, Pro only)

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
    static let mossGreen = Color(hex: "7CB342")       // tints, nav active, success cues on light bg
    static let mossGreenAction = Color(hex: "52822A") // primary button fill — white label clears WCAG AA (4.6:1)
    static let mossGreenActionDeep = Color(hex: "3D6420") // pressed / drop-shadow under the button
    static let coralStreak = Color(hex: "FF8A7A")
    static let cloudGrey = Color(hex: "B8C5D0")
    static let sunYellow = Color(hex: "FFD66B")

    // Subscription product IDs (App Store Connect)
    static let monthlyProductID = "com.sky.pro.monthly"
    static let annualProductID = "com.sky.pro.annual"
    static let lifetimeProductID = "com.sky.pro.lifetime"
    static let founderLifetimeProductID = "com.sky.pro.founder"
}
```

Renaming the app or mascot requires editing only this file.
