# Sky — App Workflow Specification

*Companion to `Sky_PRD.md`, `Sky_Development_Roadmap.md`, and `Sky_Technical_Spec.md`.*

This document enumerates **every screen, every component, every state, every interaction, and every navigation path** in Sky v1.0. It is written to be fed page-by-page into an AI coding assistant alongside the roadmap, so that each phase can be implemented without re-deriving UX decisions.

---

## How to Use This Document

1. **Per-phase builds.** Open the Phase-to-Screen Index (§3.10) and pull only the screens flagged for the phase you're building. Feed those screens (Part 1) + the relevant journeys (Part 2) + the relevant cross-cutting refs (Part 3) into the AI session.
2. **Reference, don't duplicate.** Thresholds, product IDs, color values, and bundle IDs live in the three source docs. This document points at them; it never re-states them.
3. **Treat screen IDs as stable.** `S-VER-03` is the recording screen forever. Renaming requires updating every reference.
4. **Copy strings are normative.** All quoted user-facing text in this doc is the v1.0 copy. Localizable.strings keys mirror the screen IDs.
5. **Annotations.** `[Free]` and `[Pro]` mark gating differences. `[Phase N]` marks the roadmap phase that introduces the screen. `[Optional]` marks behavior the user can disable.

---

## Conventions

| Notation | Meaning |
|---|---|
| `S-XXX-NN` | Screen identifier (Part 1) |
| `J-NN` | User journey identifier (Part 2) |
| `[Phase N]` | Introduced or substantively modified in Roadmap Phase N |
| `[Free]` / `[Pro]` | Gating annotation |
| `→ S-XXX-NN` | Navigates to that screen |
| `⤴ S-XXX-NN` | Returns to that screen |
| `❶ … ❷ …` | Numbered step in a journey |
| `↻` | Auto-recurring action (e.g. midnight reset) |

---

## Glossary

- **Nimbus** — the cloud mascot; visual avatar of user state. Has 5 states (PRD §4.7).
- **Verification** — the strict ~30s outdoor video flow that earns the user back access to blocked apps for the rest of the day.
- **Shield** — the iOS-level block applied to user-selected apps via `ManagedSettingsStore`. Tapping a shielded app launches Sky's custom shield UI, not the system one.
- **Emergency unlock** — the typed-reason escape path; unlocks apps but breaks streak and makes Nimbus sad.
- **Day** — a local-time 24-hour window starting at 00:00. All resets, streaks, and budgets pivot on local midnight.
- **Reset token** — a `YYYY-MM-DD` string written at midnight to invalidate yesterday's flags.
- **App Group** — `group.com.sky.shared`, shared by main app + 3 extensions.
- **Pro** — the paid tier (any of Monthly, Annual, Lifetime, or Founder's Lifetime).

---

# Part 0 — Foundations

## 0.1 Navigation Model

```
SkyApp (@main)
└── AppCoordinator (top-level route state)
    ├── Splash (first frame only, < 200ms)
    ├── OnboardingHost (full-screen, replaces root)
    │   └── 5-screen TabView(.page)
    ├── PermissionHost (full-screen, sequential gates)
    │   ├── Family Controls
    │   ├── Notifications
    │   └── (Camera/Mic/Location requested lazily at first verification)
    └── MainTabView
        ├── TodayTab        (NavigationStack)
        ├── StreaksTab      (NavigationStack)
        └── SettingsTab     (NavigationStack)
            ├── .fullScreenCover ← VerificationFlow
            ├── .fullScreenCover ← EmergencyUnlockFlow
            ├── .fullScreenCover ← Paywall
            ├── .sheet           ← FamilyActivityPicker
            ├── .sheet           ← BadgeDetail
            ├── .sheet           ← LimitConfiguration sub-views
            └── .overlay         ← Celebrations, Toasts
```

- **Onboarding is sticky.** Once `OnboardingCompleted = true` in `UserDefaults.standard`, the user never sees it again unless they reinstall.
- **Permission gates run on every cold launch** until satisfied. If Family Controls is revoked mid-life (e.g. iOS major upgrade), the gate reappears.
- **Tab bar is permanent** once reached. Modals always cover the tab bar, never replace it.
- **Verification, emergency, and paywall are full-screen covers** — they must feel weighty and uninterruptable. `.sheet` is reserved for non-blocking choices (badge detail, limit config, picker).

## 0.2 Cold-Launch Route Table

| State | Result |
|---|---|
| First launch, `OnboardingCompleted = false` | → `S-ONB-01` |
| Onboarding done, Family Controls not authorized | → `S-PERM-01` |
| Onboarding + auth done, no apps selected | → `S-TODAY-01` with "Select apps" empty state |
| Onboarding + auth + apps selected, no limit set | → `S-TODAY-01` with "Set limit" empty state |
| All configured, currently shielded | → `S-TODAY-01` with active-shield banner |
| All configured, already verified today | → `S-TODAY-01` with "Verified — enjoy your day" banner |
| Launched via `sky://verify` deep link | → `S-VER-01` (full-screen cover over Today) |
| Launched via `sky://emergency` deep link | → `S-EMG-01` (full-screen cover over Today) |

## 0.3 Mascot State Machine (Nimbus)

States from PRD §4.7. The state lives in `MascotStateManager.swift` (Roadmap Phase 11), persisted in CloudKit (`UserProgress.mascotState`) and mirrored to local cache.

| State | Visual | Enter from | Trigger | Duration |
|---|---|---|---|---|
| `cloudyGrey` | Default indoor cloud | midnight reset, app launch with `didVerifyToday=false` | day start, no verification yet | until verification or emergency |
| `fluffyWhite` | Idle puffy white | `cloudyGrey` | user is under budget (any usage check tick) | until budget hit or midnight |
| `sunny` | Bright sunny cloud | `celebrating` after 5s, OR verification success | successful verification | 24 hours, until next midnight |
| `rainbow` | Rainbow celebration | verification success that hits a milestone streak (3/7/14/30/60/100) | streak milestone | 5 seconds, then → `sunny` |
| `rainy` | Sad rainy cloud | emergency unlock used | emergency unlock confirmed | until next midnight |

**Transitions:** SwiftUI `.transition(.scale.combined(with: .opacity))` over 0.5s. If `Reduce Motion` is on, fade only.

## 0.4 App-Block State Machine

| State | Stored as | UI effect |
|---|---|---|
| `unblocked` | `isCurrentlyBlocked=false`, `didVerifyToday=false`, `didEmergencyUnlockToday=false` | Selected apps work normally. Today banner: "Sky is watching" |
| `blocked` | `isCurrentlyBlocked=true` | Selected apps show Sky shield. Today banner: "Time's up — go outside" |
| `verifiedToday` | `didVerifyToday=true`, `isCurrentlyBlocked=false` | Apps unlocked. Today banner: "Verified ☀ Enjoy your day" |
| `emergencyUnlocked` | `didEmergencyUnlockToday=true`, `isCurrentlyBlocked=false` | Apps unlocked. Today banner: "Emergency unlock used. Try again tomorrow." |
| `paused` | written by `S-SET-03`; expires 24h after start | Shields removed. Today banner: "Paused until <time>" |

## 0.5 Verification Result State Machine

`recording → processing → success | failure(reason) → cleanup`

- `recording`: 30 seconds, sensors capturing concurrently. Cancelable.
- `processing`: < 5s on iPhone 12+. Not cancelable.
- `success`: triggers unlock + mascot transition + streak update + badge check.
- `failure(reason)`: one of the 7 `FailureReason` cases. User may retry or take the emergency path.
- `cleanup`: video file deleted, sensor data cleared. Runs in both success and failure paths.

## 0.6 Deep-Link Router

Handled in `SkyApp.swift` `.onOpenURL { url in router.handle(url) }`.

| URL | Source | Action |
|---|---|---|
| `sky://verify` | `ShieldActionExtension` primary button, notifications, widgets (v1.1+) | Present `S-VER-01` as full-screen cover over the active tab |
| `sky://emergency` | `ShieldActionExtension` auxiliary button | Present `S-EMG-01` as full-screen cover |
| `sky://today` | Reserved for v1.1+ widgets | → `S-TODAY-01` |
| Any unrecognized scheme | — | Open Today, log to debug menu |

## 0.7 Design Primitives (reference only)

- Colors: `AppBranding.swift` (PRD §11) — `primarySky`, `warmCream`, `mossGreen`, `coralStreak`, `cloudGrey`, `sunYellow`.
- Typography: `Typography.swift` (Roadmap Phase 1) — SF Rounded at semantic sizes.
- Components: `SkyPrimaryButton`, `SkySecondaryButton`, `SkyDestructiveButton`, `SkyCard`, `SkyProgressRing`, `NimbusView` (Roadmap Phase 1).
- Motion: 0.3s spring for most transitions, 0.5s for mascot, 0.2s for toasts. All disabled under Reduce Motion.

---

# Part 1 — Screen Catalog

## Group A — Onboarding & Permissions

### S-ONB-01 · Splash / First-Launch Router · [Phase 0, wired Phase 2]

**Purpose.** A near-instant routing frame that decides whether to show onboarding, permission gates, or the main tab bar. Never shown for more than ~200ms.

**Entry points.** App cold launch (always).

**Exit points.** → `S-ONB-02` (first launch) · → `S-PERM-01` (onboarding done, auth missing) · → `S-TODAY-01` (configured) · → `S-VER-01` or `S-EMG-01` (deep link).

**Layout.** Full-screen `AppBranding.warmCream` background. Centered: large `NimbusView(state: .fluffyWhite)`, app wordmark below.

**Components.** `NimbusView`, wordmark `Text("Sky")` in SF Rounded Heavy 56pt.

**Copy.** None besides the wordmark.

**States.** Single state. No spinner — if routing takes >300ms, show one subtle pulse on Nimbus.

**Interactions.** None.

**Transitions.** Crossfade (0.25s) into destination screen.

**Edge cases.** If CloudKit fetch on launch is slow, do NOT block on it — route by local cache and let sync resolve in background.

**Accessibility.** `accessibilityLabel("Sky is starting")`. Skipped entirely by VoiceOver if route resolves in < 100ms.

**Persistence.** Reads `OnboardingCompleted` (UserDefaults.standard), `AuthorizationCenter.shared.authorizationStatus`, `SharedDefaults.familyActivitySelection`.

**Gating.** N/A.

---

### S-ONB-02 · Onboarding 1: Welcome · [Phase 2]

**Purpose.** Greet the user, introduce the brand and Nimbus, set the emotional tone.

**Entry points.** ← `S-ONB-01` on first launch.

**Exit points.** Swipe left → `S-ONB-03`.

**Layout.** Vertical: large NimbusView at top (40% of screen height, idle bob animation), title, body, page-indicator dots above bottom safe area.

**Components.** `NimbusView(state: .fluffyWhite)`, `Text` title (largeTitle), `Text` body (body), `PageIndicator` (5 dots).

**Copy.**
- Title: **"Hi, I'm Nimbus."**
- Body: *"I'll help you spend less time scrolling and more time outside. It's going to take a little work — but you've got this."*

**States.** Single. Idle Nimbus bob loops every 2s.

**Interactions.** Horizontal swipe → next page. Tap Nimbus → tiny squish animation (delight micro-interaction).

**Transitions.** `TabView(.page)` default page slide on swipe.

**Edge cases.** None.

**Accessibility.** Nimbus has `accessibilityHidden(true)`. Title and body are read as the page. VoiceOver swipe right advances pages.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-03 · Onboarding 2: Pick Apps Preview · [Phase 2]

**Purpose.** Illustrate the app-selection step without triggering the system picker yet.

**Entry points.** ← `S-ONB-02` swipe.

**Exit points.** Swipe → `S-ONB-04`. Swipe back → `S-ONB-02`.

**Layout.** Top: illustration (stylized phone with generic app icons — Sky never names real apps). Title and body below. Page dots above bottom safe area.

**Components.** `SkyCard` containing a static SVG/SwiftUI illustration of three generic colored squares; `Text` title; `Text` body.

**Copy.**
- Title: **"Pick the apps that pull you in."**
- Body: *"You'll choose from your phone's apps. Sky never sees their names — only you do."*

**States.** Single.

**Interactions.** Horizontal swipe.

**Transitions.** Page slide.

**Edge cases.** None.

**Accessibility.** Illustration `accessibilityHidden(true)`. Title + body read as page.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-04 · Onboarding 3: Set Your Budget Preview · [Phase 2]

**Purpose.** Illustrate the time-budget step.

**Entry points.** ← `S-ONB-03`.

**Exit points.** → `S-ONB-05`. ← `S-ONB-03`.

**Layout.** Top: stylized progress ring half-filled. Title + body. Page dots.

**Components.** `SkyProgressRing` (filled to ~60% as illustration), title, body.

**Copy.**
- Title: **"Decide how much is enough."**
- Body: *"One hour. Two. Three. When you hit your limit, the apps pause until you take a break outside."*

**States.** Single. Ring pulses gently (1s loop, 5% scale).

**Interactions.** Horizontal swipe.

**Transitions.** Page slide.

**Edge cases.** None.

**Accessibility.** Ring `accessibilityHidden(true)`.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-05 · Onboarding 4: Go Outside Preview · [Phase 2]

**Purpose.** Set expectations for the verification flow without scaring the user.

**Entry points.** ← `S-ONB-04`.

**Exit points.** → `S-ONB-06`. ← `S-ONB-04`.

**Layout.** Top: illustration of a phone pointing at a stylized sun + cloud. Title + body. Page dots.

**Components.** Illustration card, title, body.

**Copy.**
- Title: **"Touch grass, then come back."**
- Body: *"To unlock the apps, head outside and record a short video. Sky checks the sky, the light, and your steps — all on your phone."*

**States.** Single.

**Interactions.** Horizontal swipe.

**Transitions.** Page slide.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-06 · Onboarding 5: Privacy + Ready · [Phase 2]

**Purpose.** Reaffirm privacy commitments and dismiss onboarding.

**Entry points.** ← `S-ONB-05`.

**Exit points.** Tap "Let's go" → `S-PERM-01`. ← `S-ONB-05`.

**Layout.** Top: small NimbusView. Three bulleted privacy points with leading sky-blue checkmarks. `SkyPrimaryButton` ("Let's go") pinned above bottom safe area.

**Components.** `NimbusView(state: .sunny)`, three rows of `Image(systemName: "checkmark.seal.fill") + Text`, `SkyPrimaryButton`.

**Copy.**
- Title: **"Your videos stay on your phone."**
- Bullet 1: *"Verification runs on-device. Videos are deleted right after."*
- Bullet 2: *"No screen-time data ever leaves your phone."*
- Bullet 3: *"Your reasons for emergency unlocks stay private to you."*
- Button: **"Let's go"**

**States.** Default. Button is always enabled (no validation).

**Interactions.** Tap button → write `OnboardingCompleted = true` to UserDefaults.standard, push `S-PERM-01`.

**Transitions.** Cross-dissolve to the permission host.

**Edge cases.** None.

**Accessibility.** Button has `accessibilityHint("Continues to permissions")`.

**Persistence.** Writes `OnboardingCompleted = true`.

**Gating.** N/A.

---

### S-PERM-01 · Family Controls Authorization Explainer · [Phase 3]

**Purpose.** Justify the Screen Time permission before triggering the iOS system prompt.

**Entry points.** ← `S-ONB-06` (first time) · ← `S-ONB-01` (cold-launch route when auth is missing).

**Exit points.** Tap "Allow" → iOS system prompt → on grant → `S-CFG-01`. On deny → `S-PERM-02`.

**Layout.** NimbusView, title, body paragraph, primary button.

**Components.** `NimbusView(state: .fluffyWhite)`, `Text` title, `Text` body, `SkyPrimaryButton`.

**Copy.**
- Title: **"Sky needs Screen Time access."**
- Body: *"This is the permission that lets Sky pause apps when you hit your daily limit. We use it for your phone only — never for monitoring anyone else."*
- Button: **"Allow Screen Time access"**

**States.** Default · awaiting-system-prompt (button disabled with subtle progress spinner inside).

**Interactions.** Tap button → `try await AuthorizationCenter.shared.requestAuthorization(for: .individual)`. iOS shows native sheet; result handled in await.

**Transitions.** None on entry. On success → push to `S-CFG-01` with crossfade.

**Edge cases.**
- If user has previously denied at OS level, the request returns immediately denied → route to `S-PERM-02`.
- If user has approved previously (rare reinstall), skip directly to `S-CFG-01`.

**Accessibility.** Button `accessibilityHint("Opens the system Screen Time prompt")`.

**Persistence.** Apple persists the grant. Sky reads `AuthorizationCenter.shared.authorizationStatus` on each launch.

**Gating.** N/A.

---

### S-PERM-02 · Family Controls Denied · [Phase 3]

**Purpose.** Recover from a denied Screen Time grant by pointing the user to Settings.

**Entry points.** ← `S-PERM-01` on denial.

**Exit points.** Tap "Open Settings" → iOS Settings app (Sky pauses). Tap "Try again" → `S-PERM-01`.

**Layout.** Cloudy-grey Nimbus at top, title, body, two-button stack.

**Components.** `NimbusView(state: .cloudyGrey)`, title, body, `SkyPrimaryButton`, `SkySecondaryButton`.

**Copy.**
- Title: **"Sky needs that permission."**
- Body: *"Without Screen Time access, Sky can't pause apps for you. Open Settings → Screen Time and toggle Sky on, then come back."*
- Primary: **"Open Settings"**
- Secondary: **"Try again"**

**States.** Default.

**Interactions.** Primary → `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`. Secondary → pop back to `S-PERM-01`.

**Transitions.** None special.

**Edge cases.** If user fixes in Settings and returns via task switch, `.onChange` of `authorizationStatus` (observed in `AppCoordinator`) auto-routes to `S-CFG-01`.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** N/A.

---

### S-PERM-03 · Notification Permission Rationale · [Phase 15]

**Purpose.** Pre-frame the OS notification prompt so the user knows what they're agreeing to.

**Entry points.** Shown once after `S-CFG-04` or `S-CFG-05` is completed for the first time.

**Exit points.** Tap "Sure" → `UNUserNotificationCenter` prompt → → `S-TODAY-01`. Tap "Not now" → → `S-TODAY-01`.

**Layout.** NimbusView, title, three feature bullets, two-button stack.

**Components.** `NimbusView(state: .fluffyWhite)`, title, three bulleted rows, `SkyPrimaryButton`, `SkySecondaryButton`.

**Copy.**
- Title: **"Want gentle nudges?"**
- Bullet 1: *"Morning hello at 8:30."*
- Bullet 2: *"A heads-up 30 minutes before your apps pause."*
- Bullet 3: *"Streak reminders if you're about to break one. (Pro)"*
- Primary: **"Sure"**
- Secondary: **"Not now"**

**States.** Default.

**Interactions.** Primary → `try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`. Secondary → skip.

**Edge cases.** If denied, the toggles in `S-SET-04` are shown as disabled with a Settings deep link.

**Accessibility.** Standard.

**Persistence.** OS persists. Sky reads via `UNUserNotificationCenter.current().notificationSettings()`.

**Gating.** Streak warning bullet is Pro-only — show with a "(Pro)" suffix here for honesty.

---

### S-PERM-04 · Camera + Mic + Location Rationale · [Phase 7]

**Purpose.** Lazy permission prep right before the first verification recording — only shown once.

**Entry points.** ← `S-VER-01` first time only.

**Exit points.** Tap "OK" → iOS prompts for each (camera → mic → location when-in-use) in sequence → → `S-VER-03`. Cancel → ⤴ caller.

**Layout.** NimbusView, title, three icon-led rows explaining each permission, primary button.

**Components.** `NimbusView(state: .fluffyWhite)`, title, three rows (SF Symbols `camera.fill`, `mic.fill`, `location.fill` + body), `SkyPrimaryButton`, `SkySecondaryButton` (cancel).

**Copy.**
- Title: **"Three quick permissions."**
- Camera: *"To record your outdoor video."*
- Mic: *"Captured with the video by iOS — Sky doesn't analyze audio, but iOS requires the permission for video recording."*
- Location: *"To check you're actually outside (GPS accuracy and motion). Sky stores only a rounded location, never your exact spot."*
- Primary: **"OK, let's set those up"**
- Cancel: **"Not now"**

**States.** Default.

**Interactions.** Primary sequentially calls `AVCaptureDevice.requestAccess(for: .video)`, `AVCaptureDevice.requestAccess(for: .audio)`, `CLLocationManager.requestWhenInUseAuthorization()`. Cancel pops the verification flow entirely.

**Edge cases.** Any denial → show inline note linking to Settings, but allow the user to keep going. The verification will fail later with a clear reason, which is the correct outcome.

**Accessibility.** Standard.

**Persistence.** OS-managed.

**Gating.** N/A.

---

## Group B — Configuration

### S-CFG-01 · App Selection Root · [Phase 3]

**Purpose.** Entry point to picking which apps to block.

**Entry points.** ← `S-PERM-01` (first time) · ← `S-SET-02` (from settings).

**Exit points.** Tap "Choose apps" → `S-CFG-02`. Tap "Continue" (when ≥1 app selected) → `S-CFG-03` (first run) or ⤴ caller (settings).

**Layout.** Title, summary card showing selection count, primary button to open picker, continue button.

**Components.** `Text` title, `SkyCard` (summary with Token rendering for selected apps via `Label(token)`), `SkyPrimaryButton` (choose), `SkyPrimaryButton` (continue).

**Copy.**
- Title: **"Which apps do you want to limit?"**
- Card empty: *"No apps selected yet."*
- Card with selection: *"4 apps selected"* (count is dynamic; no names).
- Choose button: **"Choose apps"** (or **"Edit selection"** if non-empty)
- Continue: **"Continue"**

**States.**
- Empty: continue disabled, choose-button is primary action.
- Has selection: continue enabled, choose-button is secondary style.
- `[Free]` Hard-capped at 2 apps; if picker returns >2, show inline error toast and require a re-pick.

**Interactions.** Choose → sheet presents `S-CFG-02`. Continue → next step.

**Transitions.** Sheet slides up over the screen for the picker.

**Edge cases.**
- Tokens invalidated by iOS upgrade: on detection (decode fails), display warning "Your app selection needs to be redone after an iOS update" and disable continue until re-picked.
- Free user picks >2: show toast "Free includes up to 2 apps. Choose 2 or upgrade." with inline link to `S-PAY-01`.

**Accessibility.** Count text uses `accessibilityValue("\(count) apps")`.

**Persistence.** Reads/writes `SharedDefaults.familyActivitySelection` (Codable-encoded Data).

**Gating.** `[Free]` 2 apps max. `[Pro]` unlimited.

---

### S-CFG-02 · FamilyActivityPicker Sheet · [Phase 3]

**Purpose.** Apple's system app picker. Sky never sees app names — it only receives an opaque `FamilyActivitySelection`.

**Entry points.** ← `S-CFG-01`.

**Exit points.** Dismiss (swipe or Done) → ⤴ `S-CFG-01` with selection persisted.

**Layout.** Apple-owned. Sky cannot style.

**Components.** `FamilyActivityPicker(selection: $selection)` bound to a `@State var`. Sky shows nothing else.

**Copy.** Apple-owned.

**States.** Apple-owned.

**Interactions.** User picks apps and/or categories. On dismiss, Sky encodes the selection to Data and persists.

**Transitions.** Standard sheet.

**Edge cases.**
- User dismisses without picking anything: leave the prior selection intact.
- `[Free]` post-dismiss validation: if `selection.applicationTokens.count + selection.categoryTokens.count > 2`, do not persist; show toast on return (see `S-CFG-01`).

**Accessibility.** Apple-handled.

**Persistence.** Writes encoded `FamilyActivitySelection` to `SharedDefaults`.

**Gating.** Validation happens at persist time, not inside the picker.

---

### S-CFG-03 · Limit Mode Toggle · [Phase 4]

**Purpose.** Choose between a combined budget across all apps and per-app budgets.

**Entry points.** ← `S-CFG-01` (first-run continue) · ← `S-SET-02`.

**Exit points.** Toggle decides which sub-view follows: → `S-CFG-04` (combined) or → `S-CFG-05` (per-app). "Save" → ⤴ caller.

**Layout.** Title, body caption, a `Picker(style: .segmented)`, embedded body (either combined or per-app sub-view), save button, "Resets at midnight, your local time." caption.

**Components.** `Picker`, `SkyCard` containing embedded sub-view, `SkyPrimaryButton` (save), caption `Text`.

**Copy.**
- Title: **"Daily limit"**
- Segmented: **"Combined"** | **"Per app"**
- Caption: *"Limits reset at midnight, your local time."*
- Save: **"Save"**

**States.**
- Combined selected · Per-app selected.
- `[Free]` Per-app segment is shown but tapping it presents `S-PAY-05` (in-context Pro gate) and reverts the segment.

**Interactions.** Toggle segment → swap embedded body. Save → persist mode + values to `SharedDefaults`, then exit.

**Transitions.** 0.2s cross-dissolve when swapping embedded body.

**Edge cases.** Switching modes preserves previously entered values (per-app limits keep their map; combined keeps its hours). On save, only the active mode's data is enforced, but both persist.

**Accessibility.** Segment uses `accessibilityValue` of the chosen segment.

**Persistence.** Writes `limitMode`, `combinedLimitSeconds`, `perAppLimitsData` to `SharedDefaults`.

**Gating.** `[Free]` combined-only. `[Pro]` both.

---

### S-CFG-04 · Combined Limit Picker (embedded) · [Phase 4]

**Purpose.** Pick a daily total of 1, 2, or 3 hours.

**Entry points.** Embedded inside `S-CFG-03` when "Combined" is selected.

**Exit points.** Inherited from `S-CFG-03`.

**Layout.** Body: large `Picker(style: .wheel)` or three `SkyCard` chips. v1.0: three chips horizontally arranged.

**Components.** Three `SkyCard` chips with hour labels ("1 h", "2 h", "3 h"). Selected chip is filled `primarySky`, others outline-only.

**Copy.**
- Caption above chips: *"How long across all selected apps each day?"*

**States.** One chip always selected. Default to "2 h" on first run.

**Interactions.** Tap chip → select. Animates with 0.2s spring scale.

**Transitions.** Selection ring animates between chips.

**Edge cases.** None.

**Accessibility.** Chips are a `Picker` underneath for VoiceOver — `accessibilityValue` reads "Two hours" etc.

**Persistence.** Writes `combinedLimitSeconds` (3600 / 7200 / 10800).

**Gating.** `[Free]` allowed.

---

### S-CFG-05 · Per-App Limits List (embedded) · [Phase 4] [Pro]

**Purpose.** Set per-app daily budgets, 15-minute steps from 15 min to 4 hours.

**Entry points.** Embedded inside `S-CFG-03` when "Per app" is selected.

**Exit points.** Inherited from `S-CFG-03`.

**Layout.** Scrollable list. Each row: `Label(token)` (Apple-rendered icon + name visible to user only via iOS), stepper, current value label.

**Components.** `ForEach` over `selection.applicationTokens`, each row a `HStack` with `Label(token)`, `Stepper(value: $minutes, in: 15...240, step: 15)`, `Text("\(minutes)m")`.

**Copy.**
- Header: *"How long for each app?"*
- Per-row no extra copy (token + minutes only).

**States.**
- Default: each app shows 60m on first entry.
- If selection is empty (shouldn't happen because S-CFG-01 enforces ≥1), show a friendly fallback row.

**Interactions.** Stepper +/- adjusts in 15-min steps. Haptic tick on each.

**Transitions.** Inline value change, no screen transition.

**Edge cases.**
- Many apps: list scrolls naturally. Reserve top + bottom safe-area padding.
- Token rendered as `Label` shows the app icon + name only to the user via iOS — Sky's code does not have access to those strings.

**Accessibility.** Each row labels itself "App icon and name, current limit \(minutes) minutes. Stepper to adjust."

**Persistence.** Writes a `[Token: Int]` map to `perAppLimitsData` (Codable).

**Gating.** `[Pro]` only. `[Free]` users never see this because `S-CFG-03` blocks the segment.

---

### S-CFG-06 · Configuration Confirmation Toast · [Phase 4]

**Purpose.** Lightweight feedback after saving limit changes.

**Entry points.** Appears as an overlay on top of `S-TODAY-01` or `S-SET-02` after `S-CFG-03` save.

**Exit points.** Auto-dismisses after 2.5s. Tap to dismiss immediately.

**Layout.** Bottom-center pill, `warmCream` background, `Image(systemName: "checkmark.circle.fill")` + label.

**Components.** Toast view (`SkyToast`), checkmark icon, text.

**Copy.** *"Saved. Sky's watching."*

**States.** Single.

**Interactions.** Tap → dismiss. Auto-dismiss after 2.5s.

**Transitions.** Slide up + fade in 0.25s. Reverse on dismiss.

**Edge cases.** Suppress if Reduce Motion is on (instant fade).

**Accessibility.** `accessibilityAnnouncement("Settings saved")` — does not steal focus.

**Persistence.** None.

**Gating.** N/A.

---

## Group C — Main App (Tab Bar)

### S-TAB-00 · Tab Bar Root · [Phase 11]

**Purpose.** Persistent home navigation for the configured app.

**Entry points.** ← `S-ONB-01` route when configured · ← any modal dismissal.

**Exit points.** Tap tab → `S-TODAY-01` / `S-STREAK-01` / `S-SET-01`.

**Layout.** Standard SwiftUI `TabView` with `.tabItem` icons + labels. Translucent material background per iOS.

**Components.** Three `Tab`s, each with SF Symbol + label.
- Today: `sun.max.fill` · "Today"
- Streaks: `flame.fill` · "Streaks"
- Settings: `gearshape.fill` · "Settings"

**Copy.** Labels above.

**States.**
- Active tab tinted `mossGreen`.
- Today shows a red dot badge when `isCurrentlyBlocked = true` and not yet verified.
- Streaks shows a small `coralStreak` dot when a new badge is unlocked and unviewed.

**Interactions.** Tab tap selects tab. Long-press tab does nothing in v1.0 (reserved for v1.1 quick actions).

**Transitions.** Standard tab cross-dissolve.

**Edge cases.** When a `.fullScreenCover` is presented (verification, emergency, paywall), the tab bar is hidden — restored on dismiss.

**Accessibility.** Standard SwiftUI tab semantics. Badges use `accessibilityValue("1 new")`.

**Persistence.** Selected tab persists in `@SceneStorage("selectedTab")` so backgrounded-and-returned users land where they left off.

**Gating.** N/A.

---

### S-TODAY-01 · Today Tab Home · [Phase 11]

**Purpose.** The single most-viewed screen. Shows Nimbus, today's status, daily usage progress, and the primary action.

**Entry points.** ← `S-TAB-00` tap · ← cold launch route · ← modal dismissals.

**Exit points.**
- Tap "Verify now" → `S-VER-01`.
- Tap "I can't go outside" → `S-EMG-01`.
- Tap status banner card → no-op (card is informational).
- Tap usage ring → `S-SET-02` (limit editor).
- Tap Nimbus → micro-interaction; if a celebration is queued, replays it.

**Layout.** Scrollable `VStack`:
1. Top spacer respecting safe area
2. Hero `NimbusView` (35% of vertical space, scales down on smaller phones)
3. Status banner card
4. Daily-usage `SkyProgressRing` with center text
5. Streak chip (small)
6. Primary action button(s)
7. Bottom safe area

**Components.** `NimbusView` (state from `MascotStateManager`), `SkyCard` (banner), `SkyProgressRing`, `Text` (streak count), `SkyPrimaryButton`, `SkySecondaryButton`.

**Copy.** See `S-TODAY-02` for banner variants. Buttons:
- When blocked, not verified: **"Verify now"** (primary), **"I can't go outside"** (secondary).
- When verified today: no buttons; show *"Enjoy your day ☀"*.
- When emergency used: no buttons; show *"Try again tomorrow."*.
- When no apps selected: **"Choose apps"** primary, no secondary.
- When apps selected but no limit: **"Set your limit"** primary.

**States.**
- `unblocked` · `blocked` · `verifiedToday` · `emergencyUnlocked` · `paused` · `noApps` · `noLimit` · `entitlementMissing` (Family Controls revoked → CTA "Re-grant").
- Loading state on cold launch: skeleton ring + skeleton banner for ≤300ms.

**Interactions.**
- Primary button per state above.
- Pull-to-refresh re-syncs from CloudKit and refreshes mascot state.
- Long-press Nimbus (≥2s) → opens debug menu `S-SET-09` (only in Debug builds).

**Transitions.** State changes animate the banner copy and button stack with 0.3s opacity. Mascot state crossfades over 0.5s.

**Edge cases.**
- CloudKit unavailable: show fallback values from local cache + small `cloud.slash` icon next to streak chip.
- App in `paused` state: banner says "Paused until <time>" and ring is greyed.
- App in `entitlementMissing`: show "Sky needs Screen Time access again" with a `SkyDestructiveButton` "Reauthorize" → `S-PERM-01`.
- iCloud signed out: don't block — local cache is authoritative. Show toast "Sign in to iCloud to sync your streak" on first hit, dismissible.

**Accessibility.**
- Nimbus `accessibilityLabel` reflects state ("Nimbus is sunny — you're verified today.").
- Ring `accessibilityValue` reads "1 hour 15 minutes used of 2 hours."
- Buttons get explicit hints.

**Persistence.** Reads everything from `SharedDefaults` + `UserProgress` (CloudKit). Writes nothing directly.

**Gating.** N/A on the screen itself — gates appear inside child flows.

---

### S-TODAY-02 · Today Status Banner Variants · [Phase 11]

This is not a separate screen but the catalog of banner states that live inside `S-TODAY-01`. Listed for AI clarity.

| State | Title (bold) | Body | Color stripe |
|---|---|---|---|
| `unblocked` | "Sky is watching." | *"You've used 23 min of 2 h today."* (dynamic) | `mossGreen` |
| `blocked` | "Time's up." | *"Verify outside to unlock the apps for the rest of today."* | `coralStreak` |
| `verifiedToday` | "Verified ☀" | *"Apps are open until midnight. Nice work."* | `sunYellow` |
| `emergencyUnlocked` | "Emergency unlock used." | *"Streak reset. Tomorrow's a fresh start."* | `cloudGrey` |
| `paused` | "Paused until tomorrow." | *"Sky resumes at <time>."* | `cloudGrey` |
| `noApps` | "Nothing selected yet." | *"Choose the apps you'd like Sky to manage."* | `primarySky` |
| `noLimit` | "Almost there." | *"Set your daily limit to start."* | `primarySky` |
| `entitlementMissing` | "Permission needs renewing." | *"Re-grant Screen Time to keep Sky working."* | `coralStreak` |

---

### S-STREAK-01 · Streaks Tab Home · [Phase 12]

**Purpose.** Show current/longest streak, total verifications, and entry points into badges and insights.

**Entry points.** ← `S-TAB-00` tap.

**Exit points.** → `S-STREAK-02` (badges grid) · → `S-STREAK-04` (weekly insights `[Pro]`) · pull to refresh from CloudKit.

**Layout.** Scrollable:
1. Big current-streak number with flame icon (coral)
2. Stat row: "Longest" / "Total verified" / "Emergency unlocks"
3. "Badges" header + horizontal scroll preview of 4 most recent badges (locked greyed) + "See all"
4. "This week" header + insights card `[Pro]` or upgrade prompt `[Free]`

**Components.** Large numeric `Text`, three `SkyCard` stat tiles, `LazyHGrid` for badge preview, `SkyCard` insights.

**Copy.**
- Section title: **"Streaks"**
- Current streak: dynamic number + *"days"*.
- Stat tile labels: **"Longest"**, **"Total verified"**, **"Emergency unlocks"**.
- Badges header: **"Badges"** with `SkySecondaryButton` "See all".
- Free insights upsell: *"Weekly insights help you spot patterns. Available in Sky Pro."* + button "See Pro".

**States.**
- New user (no streak yet): current = 0, show gentle prompt "Your first verification will start your streak."
- Active streak.
- Streak just broken: show breakdown context line *"Streak ended yesterday. Today's a new start."*

**Interactions.** Tap badges preview row → `S-STREAK-02`. Tap "See Pro" → `S-PAY-01`. Pull to refresh → re-fetch `UserProgress`.

**Transitions.** Numbers tick up on first appearance after a verification (1s ease-out).

**Edge cases.** CloudKit offline: show local cache + sync indicator.

**Accessibility.** Numbers read with units ("five days"). Tiles are individually focusable.

**Persistence.** Reads `UserProgress` from CloudKit/cache.

**Gating.** Weekly insights card is `[Pro only]`.

---

### S-STREAK-02 · Badges Grid · [Phase 12]

**Purpose.** Show all 10 launch badges and their unlocked state.

**Entry points.** ← `S-STREAK-01` "See all".

**Exit points.** Tap a badge → `S-STREAK-03` sheet. Back → `S-STREAK-01`.

**Layout.** `LazyVGrid` 3 columns. Each cell: badge artwork, label below.

**Components.** Badge cell view (`BadgeCellView`) — artwork (placeholder shape filled by ColorTokens until art assets land), title, lock icon overlay when locked.

**Copy.**
- Nav title: **"Badges"**
- Per-badge titles: **First Light · Cumulus · Stratus · Cirrus · Sunburst · Clear Sky · Boundless · Early Bird · Wanderer · Comeback**

**States.** Locked (greyscale + lock icon) · Unlocked (full color + sparkle on first view) · Just-unlocked (animated sparkle for 3s on first appearance after earn).

**Interactions.** Tap → present `S-STREAK-03`.

**Transitions.** Sheet slide.

**Edge cases.** New badges arriving via CloudKit during view: animate them into unlocked state with a brief shimmer.

**Accessibility.** Each cell `accessibilityLabel("\(name), \(locked ? "locked" : "unlocked")")`.

**Persistence.** Reads `UserProgress.unlockedBadges`.

**Gating.** All 10 visible to all users. `[Free]` users see unlocked badges they earn (`First Light`, streak badges if they have streaks). `[Pro]` is required to unlock the Pro-only badges listed in PRD §4.7/§4.8 — none in v1.0 are Pro-only by ID, but `[Free]` users may be capped by feature use. *Confirm whether Pro is required to display Pro-only badges in §3.2.*

---

### S-STREAK-03 · Badge Detail Sheet · [Phase 12]

**Purpose.** Explain what each badge means and how it was (or could be) earned.

**Entry points.** ← `S-STREAK-02`.

**Exit points.** Swipe to dismiss → ⤴ `S-STREAK-02`.

**Layout.** Sheet with badge artwork hero, name, description, earned-on date if unlocked.

**Components.** Large badge view, `Text` title, body description, `Text` "Earned <date>" if applicable.

**Copy.**
- First Light: *"You did it. Your first outdoor verification."*
- Cumulus (3-day): *"Three days in a row. Real momentum."*
- Stratus (7-day): *"A whole week. The hard part is starting; you're past it."*
- Cirrus (14-day): *"Two weeks. It's becoming who you are."*
- Sunburst (30-day): *"Thirty days. Sky's proud of you."*
- Clear Sky (60-day): *"Sixty straight days outside."*
- Boundless (100-day): *"One hundred days. Most apps never see numbers like this."*
- Early Bird: *"Verified before 8 AM — you caught the morning light."*
- Wanderer: *"Five different places verified. Touch lots of grass."*
- Comeback: *"Used an emergency unlock, then strung together 7 clean days. That's character."*

**States.** Unlocked (with date) · Locked (with hint instead of date).

**Interactions.** Drag-to-dismiss sheet.

**Transitions.** Standard sheet.

**Edge cases.** Wanderer's location-count progress shown as "(3 of 5)" subtle caption when locked.

**Accessibility.** Standard.

**Persistence.** Reads `UserProgress`.

**Gating.** N/A on detail.

---

### S-STREAK-04 · Weekly Insights · [Phase 13] [Pro]

**Purpose.** Show "Top reasons you unlocked" from the local Emergency Unlock Log.

**Entry points.** ← `S-STREAK-01` insights card.

**Exit points.** Back → `S-STREAK-01`.

**Layout.** Title, "This week" subtitle, list of up to 3 most-frequent reasons with frequency dots, gentle reflective body.

**Components.** `Text` headers, list of reason rows.

**Copy.**
- Title: **"What you told yourself this week"**
- Body: *"These are the reasons you typed when you used an emergency unlock. They never leave your phone."*
- If empty: *"Nothing here yet — and that's the goal."*

**States.** Empty · 1-3 entries · ≥3 entries (only top 3 shown, rest count summarized).

**Interactions.** Pure read view.

**Transitions.** None.

**Edge cases.** If `[Free]` user somehow lands here, render the gate `S-PAY-05` instead.

**Accessibility.** List rows read as "Reason: <text>, used <n> times."

**Persistence.** Reads `EmergencyLogStore` (App Group container, never synced).

**Gating.** `[Pro]` only.

---

### S-SET-01 · Settings Root · [Phase 15]

**Purpose.** Central hub for configuration.

**Entry points.** ← `S-TAB-00` tap.

**Exit points.** Each row pushes a sub-screen.

**Layout.** Grouped list with sections.

**Components.** SwiftUI `List` with `Section` headers.

**Copy / sections.**
- **Apps & Limits**
  - "Apps Sky watches" → `S-SET-02` → `S-CFG-01`
  - "Daily limits" → `S-SET-02` → `S-CFG-03`
- **Pause** *(Pro)*
  - "Pause Sky for 24 hours" → `S-SET-03`
- **Notifications**
  - Morning reminder (toggle)
  - 30-minute warning (toggle)
  - Streak warning (toggle) *(Pro)*
  - "All notifications" → `S-SET-04`
- **Night Mode**
  - "Allow verification after sunset" → `S-SET-05`
- **Account**
  - "iCloud sync status" → `S-SET-06`
  - Sign in with Apple status
- **Subscription**
  - Current tier (e.g. "Pro Annual · Renews 2026-12-01")
  - "Manage in App Store" (deep link)
  - "Restore purchases"
- **About**
  - "Privacy policy" → opens browser
  - "Terms of service" → opens browser
  - "Support" → `mailto:`
  - "Version 1.0 (build N)" → tap 7 times → enable debug menu

**States.** Standard list. Pro-only sections show a small lock chip when free.

**Interactions.** Standard list pushes. Inline toggles for notification quick-toggles.

**Transitions.** Push navigation.

**Edge cases.** No subscription found: subscription row shows "Free" + "Upgrade" link to `S-PAY-01`. iCloud signed out: account row shows "Not signed in" + CTA.

**Accessibility.** Standard list semantics. Toggle rows announce their state.

**Persistence.** Reads many flags; writes notification toggles directly.

**Gating.** Pause + Streak warning + Per-app limits are Pro.

---

### S-SET-02 · Apps & Limits Sub-screen · [Phase 15]

**Purpose.** Re-entry into `S-CFG-01` and `S-CFG-03` for editing.

**Entry points.** ← `S-SET-01`.

**Exit points.** "Apps" row → `S-CFG-01`. "Limits" row → `S-CFG-03`. Back → ⤴ `S-SET-01`.

**Layout.** Two rows in a section. Each shows current state at a glance.

**Components.** `List` with two `NavigationLink`s.

**Copy.**
- Row 1: "Apps" with subtitle "4 apps selected" (dynamic).
- Row 2: "Daily limit" with subtitle "2 hours combined" or "Per-app: 4 apps".

**States.** Reflects current `SharedDefaults`.

**Interactions.** Standard pushes.

**Transitions.** Push.

**Edge cases.** Token invalidation surface: if decode fails, row reads "Re-select apps" in coral.

**Accessibility.** Standard.

**Persistence.** Read-only.

**Gating.** Per-app sub-screen is Pro-gated downstream.

---

### S-SET-03 · Pause Sky for 24 Hours · [Phase 15] [Pro]

**Purpose.** Friction-loaded path to pause all blocking for 24 hours, limited to once per week.

**Entry points.** ← `S-SET-01`.

**Exit points.** Confirm → pause active until next-day-same-time → ⤴ `S-SET-01`. Cancel → ⤴.

**Layout.** Sad-ish `NimbusView(state: .cloudyGrey)`, title, body, `PasteBlockedTextField`, 5s countdown, two-button stack.

**Components.** Mascot view, title, body, `PasteBlockedTextField` (min 20 chars, max 200), countdown `Text`, `SkyDestructiveButton`, `SkySecondaryButton`.

**Copy.**
- Title: **"Pause Sky for 24 hours?"**
- Body: *"This removes all shields for a day. Use this when life genuinely requires it — like travel or a work emergency. Tell yourself the reason."*
- Field placeholder: *"Why are you pausing?"*
- Primary: **"Pause Sky"** (disabled until 5s + 20 chars)
- Cancel: **"Cancel"**

**States.**
- Default: button disabled, countdown 5.
- Counting (4..1): button still disabled.
- Ready (≥20 chars and 0s): button enabled.
- Already paused this week: render an alternate screen with *"You already paused once this week. Next pause available <date>."* and just a Close button.

**Interactions.** Typing handled by `PasteBlockedTextField`. Confirm writes pause state, schedules un-pause via `DispatchQueue` + `DeviceActivityMonitor` re-eval, and shows confirmation toast `S-CFG-06`-style.

**Transitions.** Standard push.

**Edge cases.**
- If user manages to type >5 chars at once (e.g. autocomplete), `PasteBlockedTextField` rejects.
- If pause active and user revisits, show the "next pause" screen.

**Accessibility.** Field announces "Tell us why you're pausing. Paste is disabled."

**Persistence.** Writes `pauseStartedAt` to `SharedDefaults`. Pause reason stored locally in `EmergencyLogStore` (re-used) tagged `kind = .pause`.

**Gating.** `[Pro]` only. `[Free]` users see the row in `S-SET-01` greyed with a lock; tapping → `S-PAY-05`.

---

### S-SET-04 · Notification Toggles · [Phase 15]

**Purpose.** Per-notification opt-in/out.

**Entry points.** ← `S-SET-01`.

**Exit points.** Back → ⤴ `S-SET-01`.

**Layout.** List with four `Toggle` rows + section caption.

**Components.** Four `Toggle`s, section footer text.

**Copy.**
- "Morning reminder (8:30 AM)"
- "30-minute warning before block"
- "Block start"
- "Streak warning at 10 PM" *(Pro)*
- Footer: *"All notifications are scheduled by your phone. Sky doesn't use push servers."*

**States.** Toggle on/off, persisted. If OS notifications denied, all toggles disabled with a CTA "Enable in Settings".

**Interactions.** Toggle writes to `SharedDefaults` and re-schedules via `LocalNotificationScheduler`.

**Edge cases.** "Block start" notification is "always on" per PRD; show it as a non-toggleable row with disabled appearance and footnote.

**Accessibility.** Toggle rows announce their state.

**Persistence.** `notifMorningEnabled`, `notifWarningEnabled`, `notifStreakEnabled` in `SharedDefaults`.

**Gating.** Streak warning `[Pro]`.

---

### S-SET-05 · Night Mode · [Phase 15]

**Purpose.** Allow verification between sunset and sunrise with explicit opt-in.

**Entry points.** ← `S-SET-01`.

**Exit points.** Back.

**Layout.** Title, body explaining the trade-off, single toggle, sample illustration optional.

**Components.** `Toggle`, body text.

**Copy.**
- Title: **"Night mode"**
- Body: *"Sky normally requires daylight for verification. Turn this on if you want to verify after sunset — the rest of the checks (movement, GPS, scene) still apply."*
- Toggle label: **"Allow after-dark verification"**

**States.** Off (default) · On.

**Interactions.** Toggle writes `nightModeEnabled` to `SharedDefaults`.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** `nightModeEnabled` (Bool).

**Gating.** Available to all.

---

### S-SET-06 · Account / iCloud · [Phase 12, 15]

**Purpose.** Show Sign in with Apple status and iCloud sync health.

**Entry points.** ← `S-SET-01`.

**Exit points.** "Sign in with Apple" CTA → iOS sheet. "Sign out" not provided in v1.0.

**Layout.** Two stat rows ("Apple ID", "iCloud sync"), small status icons.

**Components.** Two `LabeledContent` rows; if missing, replaced by a `SkyPrimaryButton` "Sign in with Apple".

**Copy.**
- Row 1 (signed in): *"Apple ID: linked"*
- Row 1 (not signed in): button **"Sign in with Apple"**
- Row 2 (synced): *"iCloud: up to date"*
- Row 2 (syncing): *"iCloud: syncing…"*
- Row 2 (offline): *"iCloud: waiting for connection"*

**States.** Per above.

**Interactions.** Sign in button triggers `ASAuthorizationAppleIDProvider` flow.

**Edge cases.** Sign-in failure: inline error "Couldn't sign in. Try again later."

**Accessibility.** Standard.

**Persistence.** Apple ID handle stored in Keychain. Sync status derived from `CloudKitSyncService` published state.

**Gating.** N/A.

---

### S-SET-07 · Subscription · [Phase 14]

**Purpose.** Display current tier and offer management entry points.

**Entry points.** ← `S-SET-01`.

**Exit points.** "Manage subscription" → App Store deep link. "Restore purchases" → in-app sheet. "Upgrade" → `S-PAY-01`.

**Layout.** Tier header card, two action rows.

**Components.** `SkyCard` summary, two list rows.

**Copy.**
- Free: header *"Sky Free"*, body *"Up to 2 apps, combined limits only."*, button **"Upgrade to Pro"**.
- Pro Monthly: *"Sky Pro · Monthly"* + renew date + "Manage in App Store".
- Pro Annual: *"Sky Pro · Annual"* + renew date + "Manage in App Store".
- Lifetime: *"Sky Pro · Lifetime"* + *"Thanks for going all in."* + Restore.
- Founder: *"Sky Pro · Founder's Lifetime"* + special art + Restore.

**States.** As above.

**Interactions.** Manage → `URL(string: "https://apps.apple.com/account/subscriptions")!`. Restore → calls `StoreKitService.restore()`, presents result sheet.

**Edge cases.** Trial active: show "Free trial — renews <date>". Cancellation pending: "Cancels <date>".

**Accessibility.** Standard.

**Persistence.** Reads `StoreKitService.currentTier` (`@Published`).

**Gating.** N/A on display.

---

### S-SET-08 · About · [Phase 15]

**Purpose.** Legal, support, and version info.

**Entry points.** ← `S-SET-01`.

**Exit points.** Each row opens browser/mail. 7 taps on version row → enable debug menu.

**Layout.** List of rows.

**Components.** Four `Button` rows.

**Copy.**
- "Privacy policy" (opens hosted URL)
- "Terms of service"
- "Support" (mailto link)
- "Version 1.0 (Build X)"

**States.** Single.

**Interactions.** Tap row opens. Version row counts taps; on 7th, toast "Debug menu enabled" and a new row "Debug menu" appears in `S-SET-01` linking to `S-SET-09`.

**Transitions.** Standard.

**Edge cases.** No mail app configured: fall back to "Copy support@sky.app to clipboard".

**Accessibility.** Standard.

**Persistence.** Debug-enabled flag in UserDefaults.standard.

**Gating.** N/A.

---

### S-SET-09 · Debug Menu (hidden) · [Phase 1, 0]

**Purpose.** Developer/QA utilities. Never visible in App Store builds without the version-tap trick.

**Entry points.** ← `S-SET-01` (after enabling) · ← long-press Nimbus in Debug builds.

**Exit points.** Back.

**Layout.** List of utility rows.

**Components.** Rows for: Design System Preview, Force midnight reset, Force shield apply, Force mascot state (each state as a sub-row), View temp video files, Wipe local progress, Toggle Pro entitlement (sandbox), View `SharedDefaults` dump.

**Copy.** Bare descriptive labels.

**States.** N/A.

**Interactions.** Each row triggers a side effect; show a result toast.

**Transitions.** Standard.

**Edge cases.** "Wipe local progress" requires a 3-tap confirmation.

**Accessibility.** Not localized; English-only debug tool.

**Persistence.** Side effects depend on row.

**Gating.** Debug-build or version-tap unlocked.

---

## Group D — Shield (Extension UI)

### S-SHIELD-01 · Custom Shield · [Phase 6]

**Purpose.** Replace the iOS default shield with a Sky-branded surface when a user taps a blocked app.

**Entry points.** User taps a shielded app icon (managed by iOS).

**Exit points.** Primary button → `sky://verify` → main app `S-VER-01`. Secondary → `sky://emergency` → `S-EMG-01`. iOS-provided close button → returns to home screen.

**Layout.** ShieldConfiguration UIKit-based:
- Background: `warmCream`.
- Top: Nimbus PNG (pre-rendered at @2x and @3x at build time — UIKit can't render SwiftUI cleanly here).
- Title.
- Subtitle.
- Two stacked buttons.

**Components.** `ShieldConfiguration` instance — Nimbus `UIImage`, title `String`, subtitle `String`, primary `ShieldConfiguration.Label`, auxiliary `ShieldConfiguration.Label`.

**Copy.**
- Title: **"Sky — Time's up"**
- Subtitle: **"Nimbus is waiting outside for you ☁"**
- Primary: **"Go outside to unlock"**
- Auxiliary: **"I can't go outside right now"**

**States.** Single. iOS does not let the extension know which app is being shielded by name, but `configuration(shielding:)` vs `configuration(shielding:in:)` lets you differentiate per-app vs per-category if needed (v1.0 ignores this and shows one shield).

**Interactions.** iOS handles taps and forwards to `ShieldActionExtension`.

**Transitions.** iOS-controlled.

**Edge cases.** Render time budget < 100ms (`Sky_Technical_Spec.md §13`). Nimbus image must be small and ready synchronously.

**Accessibility.** Title + subtitle read by VoiceOver. Buttons get default labels from `ShieldConfiguration.Label.text`.

**Persistence.** Reads `SharedDefaults` (mascot state can theme the shield color subtly — v1.0 uses static warmCream).

**Gating.** N/A.

---

### S-SHIELD-02 · `sky://verify` Landing in Main App · [Phase 6]

**Purpose.** Route the deep link to `S-VER-01`.

**Entry points.** ← `S-SHIELD-01` primary button.

**Exit points.** → `S-VER-01` (full-screen cover).

**Layout.** No UI; transient route.

**Components.** `SkyApp.swift` `.onOpenURL` handler invoking `AppCoordinator.present(.verification)`.

**Copy.** None.

**States.** N/A.

**Interactions.** None.

**Transitions.** Full-screen cover slides up.

**Edge cases.**
- App in background → handler runs on resume, presents cover.
- App not configured (no apps, no auth): route to `S-TODAY-01` instead, with a toast "Set up Sky first."

**Accessibility.** N/A.

**Persistence.** None.

**Gating.** N/A.

---

### S-SHIELD-03 · `sky://emergency` Landing · [Phase 6]

**Purpose.** Route the emergency deep link to `S-EMG-01`.

Same structure as `S-SHIELD-02`. Target: `S-EMG-01`.

---

## Group E — Verification Flow

### S-VER-01 · Verification Intro · [Phase 7]

**Purpose.** Brief the user on what's about to happen and capture last-mile permissions.

**Entry points.** ← `S-TODAY-01` "Verify now" · ← `sky://verify` deep link · ← `S-VER-07` "Try again".

**Exit points.** Tap "I'm outside" → `S-VER-02` (if any permission missing) or `S-VER-03` (if all granted). Cancel (X top-left) → ⤴ caller.

**Layout.** Top-left X close button (small, low contrast). Centered Nimbus, title, three short bullets describing the recording, primary button.

**Components.** Close button, `NimbusView(state: .fluffyWhite)`, title, bullets with SF Symbol leads, `SkyPrimaryButton`.

**Copy.**
- Title: **"Ready to head outside?"**
- Bullet 1 (`figure.walk`): *"You'll record a 30-second video while walking."*
- Bullet 2 (`sun.max`): *"Point at the sky for a few seconds when Sky asks."*
- Bullet 3 (`lock`): *"Everything stays on your phone."*
- Button: **"I'm outside"**

**States.** Default.

**Interactions.** Tap primary → permission preflight (`S-PERM-04` if first time, else direct to `S-VER-03`). Close → confirm via system action sheet "Cancel verification?" with destructive option.

**Transitions.** Full-screen cover.

**Edge cases.** If apps are not currently blocked (e.g. user opened verify proactively), still allow it — successful verification is recorded; mascot turns sunny; no-op on shields.

**Accessibility.** Bullets read as a list.

**Persistence.** None.

**Gating.** N/A.

---

### S-VER-02 · Permission Preflight Check · [Phase 7]

**Purpose.** Verify camera/mic/location are granted; route to settings or request if not.

**Entry points.** ← `S-VER-01`.

**Exit points.** All granted → `S-VER-03`. Any missing → `S-PERM-04` first time, else inline retry screen with Settings deep link.

**Layout.** Three rows with status icons (checkmark/lock), summary, action button.

**Components.** Status row view, `SkyPrimaryButton`.

**Copy.** Dynamic: shows which permission is missing and a Settings deep link.

**States.** All granted (auto-advances) · One or more missing.

**Interactions.** Open Settings → resumes after foreground re-entry and rechecks.

**Transitions.** Auto-dismiss to `S-VER-03` when satisfied.

**Edge cases.** This screen often flashes by — if permissions resolve in < 300ms, skip it visually.

**Accessibility.** Rows read each permission's state.

**Persistence.** OS-managed.

**Gating.** N/A.

---

### S-VER-03 · Video Recording · [Phase 7, 8, 9]

**Purpose.** Capture 30 seconds of outdoor video with synchronized sensor capture and on-screen prompts.

**Entry points.** ← `S-VER-02`.

**Exit points.** 30s elapsed → `S-VER-05`. Cancel → `S-VER-04`. Interruption (call, background) → `S-VER-08`.

**Layout.** Full-bleed `AVCaptureVideoPreviewLayer` with rounded corners (8pt inset from edges). Overlays:
- Top-center: `SkyProgressRing` countdown, 30→0, with seconds remaining as label inside.
- Mid-screen: prompt text card (translucent), animated in/out per timeline.
- Bottom-left: small recording dot (pulsing red).
- Bottom-right: Cancel button (SF Symbol `xmark.circle.fill`).

**Components.** UIKit-bridged `PreviewView`, `SkyProgressRing`, animated `Text` card, dot, cancel button.

**Copy timeline.**
- 0–6s: **"Hold steady, point your camera up."**
- 6–14s: **"Now slowly look around."**
- 14–22s: **"Point at the sky for 5 seconds."**
- 22–30s: **"Last bit — show where you are."**
- 30s+ (briefly): **"Processing…"** (then S-VER-05 takes over)

**States.**
- `requestingCamera` (≤500ms after entry; show black with spinner if any)
- `recording` (active capture, sensors running)
- `cancelConfirming` (presents `S-VER-04`)
- `interrupted` (shows `S-VER-08`)

**Interactions.** Cancel → present `S-VER-04`. Other gestures (pinch, tap-to-focus) are intentionally disabled — keep the user honest.

**Transitions.** Prompt card fades in/out 0.4s per slot. Ring counts down smoothly.

**Edge cases.**
- Low storage: pre-flight check; if < 200 MB free, abort with friendly error "Free up some space and try again."
- Phone call mid-recording: AVCaptureSession interruption → `S-VER-08`.
- App backgrounded: same as call interruption.
- Low battery (< 5%): pre-flight warning; user can proceed or cancel.
- Camera unavailable (rare hardware fault): error toast "Camera unavailable — try again or restart your phone."

**Accessibility.**
- VoiceOver announces each prompt as it appears.
- Reduce Motion → ring counts in 1s discrete ticks instead of smooth.
- Provide a "Skip prompt" hidden gesture? No — keep behavior strict.

**Persistence.** Writes video to `FileManager.default.temporaryDirectory/verification_<UUID>.mov`. Sensor stream held in memory only.

**Gating.** N/A.

---

### S-VER-04 · Cancel Confirmation Sheet · [Phase 7]

**Purpose.** Confirm a cancel mid-recording to prevent accidental dismissal.

**Entry points.** ← `S-VER-03` cancel tap.

**Exit points.** "Stop recording" → recording cancelled, video deleted, ⤴ caller of `S-VER-01`. "Keep going" → ⤴ `S-VER-03`.

**Layout.** Action sheet (`.confirmationDialog`).

**Components.** SwiftUI confirmation dialog.

**Copy.**
- Title: **"Stop recording?"**
- Message: *"You'll need to start over."*
- Destructive: **"Stop"**
- Cancel: **"Keep going"**

**States.** Single.

**Interactions.** Standard.

**Transitions.** OS-controlled.

**Edge cases.** Recording continues during the dialog presentation? No — pause the capture session while the dialog is up; resume on cancel-cancel.

**Accessibility.** Standard.

**Persistence.** On confirm, delete partial video.

**Gating.** N/A.

---

### S-VER-05 · Processing · [Phase 8, 9, 10]

**Purpose.** Run the verification pipeline (sensor aggregation + frame analysis + decision) with reassuring UI.

**Entry points.** ← `S-VER-03` after 30s.

**Exit points.** Success → `S-VER-06`. Failure → `S-VER-07`.

**Layout.** Centered Nimbus (fluffyWhite), `Text` status, animated dotted progress.

**Components.** `NimbusView`, status `Text`, indeterminate spinner.

**Copy.** Status rotates every ~1s to feel alive:
1. *"Checking your surroundings…"*
2. *"Looking at the sky…"*
3. *"Almost done…"*

**States.** `running` · `unexpectedError` (with retry).

**Interactions.** Pull-to-cancel disabled — pipeline is short (< 5s) and not safely interruptible.

**Transitions.** When done, crossfade to `S-VER-06` or `S-VER-07`.

**Edge cases.**
- Pipeline takes > 10s: show "Taking longer than usual…" but don't abort.
- Hard crash inside pipeline: catch and route to `S-VER-07` with reason "Something went wrong, try again."

**Accessibility.** Status text announced; spinner has `accessibilityValue("Processing")`.

**Persistence.** None during processing. On completion, video deleted.

**Gating.** N/A.

---

### S-VER-06 · Verification Success · [Phase 10, 11, 12]

**Purpose.** Reward the user, unlock apps, update streak, possibly trigger badge.

**Entry points.** ← `S-VER-05` on success.

**Exit points.** Tap "Done" → ⤴ tab bar (Today shows verified state). If a milestone hit, the rainbow overlay `S-CEL-02` appears first, then this screen. If a new badge unlocked, `S-CEL-01` follows on dismiss.

**Layout.** Centered rainbow Nimbus (`celebrating` then `sunny`), big title, body, streak chip animated ticking up, primary button.

**Components.** `NimbusView(state: .rainbow)` for 5s then `.sunny`, title, body, streak tile, `SkyPrimaryButton`.

**Copy.**
- Title: **"Verified ☀"**
- Body: *"Apps are open until midnight. Enjoy your day."*
- Streak chip: *"<n>-day streak"* (animates from prior count)
- Button: **"Done"**

**States.**
- Default.
- New milestone (3/7/14/30/60/100): rainbow overlay precedes.
- New badge earned: badge overlay follows on dismiss.

**Interactions.** Done → dismiss cover. Streak chip is tappable → `S-STREAK-01`.

**Transitions.** Mascot transitions rainbow → sunny over 5s. Streak ticks 1s. Confetti optional (Reduce Motion off).

**Edge cases.**
- `ShieldService.unlockApps()` failure: still show success, log error, schedule a retry; user-visible behavior is unlocked + a quiet toast "Couldn't fully clear shields — restart Sky if apps remain blocked."
- CloudKit failure: cache write succeeds; sync retries.

**Accessibility.** Announces "Verified. Apps are open until midnight."

**Persistence.** Calls `ShieldService.unlockApps()` → `ManagedSettingsStore().shield.applications = nil` and `shield.applicationCategories = nil`. Writes `didVerifyToday=true`, `isCurrentlyBlocked=false`, `verificationCompletedAt=Date()`. Updates `UserProgress` (streak +1 if conditions met, totalVerifications +1, last location appended rounded to 0.01°).

**Gating.** N/A.

---

### S-VER-07 · Verification Failure · [Phase 10]

**Purpose.** Tell the user *what* went wrong in friendly terms and offer next steps.

**Entry points.** ← `S-VER-05` on failure.

**Exit points.** "Try again" → `S-VER-01`. "I can't go outside" → `S-EMG-01`. X close → ⤴ tab bar.

**Layout.** Sad Nimbus (`rainy`), title (generic), specific reason body, two-button stack.

**Components.** `NimbusView(state: .rainy)`, title, body keyed by `FailureReason`, `SkyPrimaryButton`, `SkySecondaryButton`.

**Copy per `FailureReason`.**

| Reason | Title | Body |
|---|---|---|
| `gpsSpoofingDetected` | *"Hmm, that doesn't add up."* | *"Sky couldn't trust the GPS reading. If you've got a location-spoofing tool installed, turn it off and try again."* |
| `outsideDaylightWindow` | *"It's dark out."* | *"Sky uses daylight as part of the check. Try again after sunrise, or turn on Night Mode in Settings."* |
| `poorGPSSignal` | *"Couldn't find you."* | *"GPS was too fuzzy. Try moving away from buildings or being more in the open."* |
| `notEnoughMovement` | *"Not enough walking."* | *"Take a few real steps while you record. It only needs to be a short walk."* |
| `notBrightEnough` | *"Too dim."* | *"Sky needs daylight on the camera. Try somewhere brighter."* |
| `sceneNotOutdoor` | *"That didn't look outdoor."* | *"The camera mostly saw indoor scenes. Try again outside, ideally with sky in view."* |
| `noSkyVisible` | *"Show some sky."* | *"Sky needs at least a glimpse of sky in the video. Tilt up for a few seconds and try again."* |

- Primary: **"Try again"**
- Secondary: **"I can't go outside"**

**States.** One per failure reason.

**Interactions.** Try again resets the verification flow. Secondary leads to emergency unlock.

**Transitions.** Fade in.

**Edge cases.** Repeat failures (3 in a row) → after the third, a small inline tip "Trouble? Check the troubleshooting guide" with link to Settings → About → Support.

**Accessibility.** Reason body is announced; buttons get hints.

**Persistence.** No streak change (streak only changes on success or emergency). Video deleted.

**Gating.** N/A.

---

### S-VER-08 · Recording Interrupted · [Phase 7]

**Purpose.** Recover gracefully from interruptions (calls, backgrounding, low battery, OS audio session preemption).

**Entry points.** ← `S-VER-03` interruption notification (AVCaptureSession `.wasInterruptedNotification`).

**Exit points.** "Try again" → `S-VER-01`. Close → ⤴ tab bar.

**Layout.** Fluffy-white Nimbus, title, body, primary + secondary buttons.

**Components.** Same as `S-VER-07` shell with friendly copy.

**Copy.**
- Title: **"Recording got interrupted."**
- Body: *"That's OK. Let's start over when you're ready."*
- Primary: **"Try again"**
- Secondary: **"Not now"**

**States.** Single.

**Interactions.** Standard.

**Edge cases.** Multiple interruptions in a row: same screen, no escalation.

**Accessibility.** Standard.

**Persistence.** Partial video deleted on transition.

**Gating.** N/A.

---

## Group F — Emergency Unlock

### S-EMG-01 · Emergency Unlock Intro · [Phase 13]

**Purpose.** Soft on-ramp to the typed-reason path.

**Entry points.** ← `S-SHIELD-01` aux · ← `S-VER-07` secondary · ← `S-TODAY-01` "I can't go outside".

**Exit points.** "Continue" → `S-EMG-02`. Cancel → ⤴ caller.

**Layout.** Sad-ish Nimbus (`cloudyGrey`), title, body, two buttons.

**Components.** `NimbusView(state: .cloudyGrey)`, title, body, `SkyPrimaryButton`, `SkySecondaryButton`.

**Copy.**
- Title: **"Are you sure?"**
- Body: *"If you can't go outside right now, Nimbus understands — life happens. But using this resets your streak. If you'd rather try outside again, that's still an option."*
- Primary: **"Yes, I need to unlock"**
- Secondary: **"Try outside again"**

**States.** Single.

**Interactions.** Primary → `S-EMG-02`. Secondary → `S-VER-01`.

**Transitions.** Full-screen cover or push within cover.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** N/A.

---

### S-EMG-02 · Typed-Reason Screen · [Phase 13]

**Purpose.** Friction-loaded confirmation. Paste-blocked, 5-second forced pause, character minimum.

**Entry points.** ← `S-EMG-01`.

**Exit points.** "Unlock anyway" → `S-EMG-03`. Cancel → ⤴ caller.

**Layout.** Vertical stack:
1. Sad Nimbus.
2. Title.
3. Helper text.
4. `PasteBlockedTextField` (multi-line look but single-line UITextField under the hood per spec; if multi-line needed, use UITextView with same paste-block).
5. Live counter "X / 200".
6. 5-second countdown indicator.
7. Two-button row: Cancel, Unlock.

**Components.** `NimbusView(state: .rainy)`, title, body, `PasteBlockedTextField`, character counter `Text`, countdown `Text`, `SkyDestructiveButton`, `SkySecondaryButton`.

**Copy.**
- Title: **"Tell yourself why."**
- Helper: *"Type at least a sentence. Paste is off — this needs to come from you."*
- Placeholder: *"I need to unlock because…"*
- Counter: "20 / 200" (dynamic; 20 shown red until met)
- Countdown: "Ready in 5…4…3…2…1" then "Ready"
- Primary (destructive): **"Unlock anyway"**
- Secondary: **"Cancel"**

**States.**
- Initial (countdown ticking, button disabled).
- Counting (each second).
- Min-not-met (countdown done, but < 20 chars).
- Ready (both conditions met).
- Submitted (button shows brief spinner).

**Interactions.**
- Typing: `PasteBlockedTextField` rejects any insertion > 5 chars (paste bypass) and any newline. Dictation off via `canPerformAction` rejection.
- Tap Unlock → write log entry → `S-EMG-03`.
- Tap Cancel → ⤴ caller.
- Keyboard "return" pressed: ignored (rejected as newline) — button is the only submit.

**Transitions.** Subtle shake on rejected paste (50ms, Reduce Motion respects).

**Edge cases.**
- App backgrounded mid-type: text persists in `@State` (not written anywhere until submission).
- 200-char limit hit: further typing rejected silently.
- Smart paste / autocomplete: a 6-character autocomplete insertion is rejected → field shakes → toast "Type it out, please."

**Accessibility.**
- Field labeled "Reason. Paste is disabled. Type at least 20 characters."
- Countdown announced once per state change ("Ready").
- Buttons get hints.

**Persistence.** On submit, writes `EmergencyUnlockEntry(id, date, typedReason, dayOfWeek, hourOfDay)` to `EmergencyLogStore` (local-only).

**Gating.** N/A.

---

### S-EMG-03 · Emergency Unlock Result · [Phase 13, 11, 12]

**Purpose.** Confirm the unlock, transition mascot to sad, communicate streak impact.

**Entry points.** ← `S-EMG-02` submission.

**Exit points.** "Done" → ⤴ tab bar.

**Layout.** Rainy Nimbus, title, body, optional streak-broke chip, primary button.

**Components.** `NimbusView(state: .rainy)`, title, body, optional `SkyCard` chip, `SkyPrimaryButton`.

**Copy.**
- Title: **"Apps unlocked."**
- Body: *"Try again tomorrow. Nimbus will be here."*
- Streak chip (if applicable): *"Your <n>-day streak ended."*
- Button: **"Done"**

**States.** Default. If streak was 0 already, omit the chip.

**Interactions.** Done → dismiss to tab bar.

**Transitions.** Standard fade.

**Edge cases.**
- Repeat emergency unlocks the same day: only the first writes the day flag and resets streak; subsequent taps are no-ops at the data layer but still show this screen.
- ShieldService unlock failure: same fallback as `S-VER-06`.

**Accessibility.** Announces "Apps unlocked. Streak ended."

**Persistence.**
- Writes `didEmergencyUnlockToday = true`, `isCurrentlyBlocked = false` to SharedDefaults.
- Resets `UserProgress.currentStreak = 0`, increments `totalEmergencyUnlocks`.
- Calls `ManagedSettingsStore().shield.applications = nil` and `applicationCategories = nil`.
- **NEVER writes the typed reason to CloudKit.**
- Triggers mascot transition to `.rainy`.

**Gating.** N/A.

---

## Group G — Paywall & Pro

### S-PAY-01 · Paywall Main · [Phase 14]

**Purpose.** Convert free users to Pro with the four tiers laid out clearly.

**Entry points.** ← First successful verification (one-shot upsell after `S-VER-06`'s "Done") · ← `S-PAY-05` (any in-context gate) · ← `S-SET-07` Upgrade · ← `S-STREAK-01` Pro CTA.

**Exit points.** Purchase success → `S-PAY-04` (trial) or close + entitlement refresh. Restore → `S-PAY-03`. Close (X) → ⤴ caller.

**Layout.** Scrollable:
1. Close button (X top-right) — visible but subtle.
2. Hero: Nimbus rainbow + title + value props (3 bulleted features).
3. Three primary tier cards in a row: Monthly · Annual (centered, larger, "Best Value" ribbon) · Lifetime.
4. Founder's Lifetime card (separate row, with seats counter) — IF available.
5. Free-vs-Pro comparison list (3 rows minimum).
6. Restore purchases button (subtle).
7. Legal microcopy footer.

**Components.** Close button, hero stack, three `TierCard`s, optional `FounderCard`, comparison `SkyCard`, restore button, footer text.

**Copy.**
- Hero title: **"Sky Pro"**
- Hero subtitle: *"Go further than the free tier."*
- Bullets: *"Unlimited apps."* · *"Per-app limits."* · *"Weekly insights & all badges."*
- Monthly: *"$4.99 / month"*
- Annual: *"$29.99 / year"* + ribbon *"Best Value"* + small *"7-day free trial"*.
- Lifetime: *"$79 once"*
- Founder: *"Founder's Lifetime — $39 · only N seats left"* (N dynamic, see §3 for seat-count strategy).
- Comparison row examples: *"Apps you can manage — Free: 2 · Pro: Unlimited"*, *"Per-app limits — Free: — · Pro: ✓"*, *"All 10 badges — Free: 3 · Pro: 10"*.
- Restore: **"Restore purchases"**
- Footer: *"Subscriptions auto-renew. Cancel anytime in App Store settings. Terms · Privacy."*

**States.**
- Default · Loading (StoreKit fetching products — show skeleton cards) · Purchase in progress (one tier shows spinner; others disabled) · Already Pro (entire paywall hidden — replaced with "You're already on Pro" with manage link).
- Founder availability: visible with seat count · sold out (replaced with `S-PAY-02` content).

**Interactions.** Tap tier card → call `StoreKitService.purchase(_:)` → success/fail handled.

**Transitions.** Slide-up cover.

**Edge cases.**
- Network unavailable: show error card "Couldn't load prices. Try again." with retry button.
- StoreKit denies purchase: toast "Purchase couldn't complete. Try again."
- Subscription pending family approval (Ask to Buy): show "Waiting for approval" state.

**Accessibility.** Each tier is a single accessible element with `accessibilityLabel` summarizing price + tier name.

**Persistence.** Reads `StoreKitService.products` and `isPro`. Writes nothing directly; entitlement refresh after purchase.

**Gating.** N/A on display.

---

### S-PAY-02 · Founder's Lifetime — Sold Out Variant · [Phase 14]

**Purpose.** Communicate the cap is hit; do not hide tiers entirely.

**Entry points.** Rendered inside `S-PAY-01` when seats counter reaches 0.

**Exit points.** Same as `S-PAY-01`.

**Layout.** Same as `S-PAY-01` but with a non-tappable card explaining the founder tier sold out.

**Copy.**
- Card title: **"Founder's seats are gone."**
- Body: *"All 500 founder spots have been claimed. The Lifetime tier is still available."*

**States.** Single.

**Interactions.** None.

**Edge cases.** Counter is approximate (App Store availability is the source of truth) — if counter says 1 left but App Store rejects the purchase as unavailable, show toast "Just missed it — Founder is sold out now" and update counter to 0.

**Accessibility.** Standard.

**Persistence.** Seat count cached locally (refreshed from a static plist updated via App Store Connect metadata).

**Gating.** N/A.

---

### S-PAY-03 · Restore Purchases Result · [Phase 14]

**Purpose.** Communicate restore success/failure.

**Entry points.** ← `S-PAY-01` restore tap · ← `S-SET-07` Restore.

**Exit points.** Done → ⤴ caller.

**Layout.** Sheet with icon, title, body, button.

**Components.** SF Symbol, title, body, `SkyPrimaryButton`.

**Copy.**
- Success: **"You're all set."** *"Your Sky Pro purchase has been restored on this device."*
- Nothing found: **"No purchases found."** *"If you bought Sky Pro on this Apple ID, make sure you're signed in."*
- Network error: **"Couldn't reach the App Store."** *"Check your connection and try again."*

**States.** Three (success · empty · error).

**Interactions.** Done dismisses.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** N/A.

---

### S-PAY-04 · Trial Start Confirmation · [Phase 14]

**Purpose.** Confirm a 7-day free trial began.

**Entry points.** ← `S-PAY-01` after Annual purchase success with active trial.

**Exit points.** Done → ⤴ tab bar.

**Layout.** Sunny Nimbus, title, body, button.

**Components.** Mascot, title, body, button.

**Copy.**
- Title: **"7 days free, on us."**
- Body: *"You're on Sky Pro Annual. Your trial ends <date>. You can cancel anytime in App Store settings."*
- Button: **"Got it"**

**States.** Single.

**Interactions.** Done dismisses.

**Transitions.** Standard.

**Edge cases.** Trial revoked (system reasons): downgrade silently and show toast on next launch "Your trial couldn't start — please try again."

**Accessibility.** Standard.

**Persistence.** Entitlement reflected via `StoreKitService.isPro`.

**Gating.** N/A.

---

### S-PAY-05 · In-Context Pro Gate · [Phase 14]

**Purpose.** Compact prompt when a free user taps a Pro-gated feature in-line.

**Entry points.** ← anywhere a `[Pro]` action is attempted by a `[Free]` user (per-app limits, pause, weekly insights, streak warning toggle).

**Exit points.** "See Pro" → `S-PAY-01`. "Maybe later" → ⤴ caller.

**Layout.** Bottom sheet (medium detent).

**Components.** Small Nimbus, headline, two buttons.

**Copy.**
- Headline (varies by feature):
  - Per-app: **"Per-app limits is a Pro feature."**
  - Pause: **"Pausing Sky is a Pro feature."**
  - Weekly insights: **"Weekly insights is a Pro feature."**
- Body (shared): *"Sky Pro unlocks per-app limits, the full insight set, all badges, and supports development."*
- Primary: **"See Pro"**
- Secondary: **"Maybe later"**

**States.** Single.

**Interactions.** Standard.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** This screen exists *because* of gating.

---

## Group H — Celebrations & Notifications

### S-CEL-01 · Badge Unlocked Overlay · [Phase 12]

**Purpose.** Celebrate a newly earned badge.

**Entry points.** ← `S-VER-06` dismiss when a new badge has been earned.

**Exit points.** Tap "Nice" or anywhere outside → ⤴ tab bar.

**Layout.** Centered overlay over a dim background. Badge art enlarges from 0 to full size with bounce. Title, body, primary button.

**Components.** `BadgeOverlayView`, title, body, `SkyPrimaryButton`.

**Copy.**
- Title: **"Badge unlocked: <name>"**
- Body: per-badge from `S-STREAK-03`.
- Button: **"Nice"**

**States.** Single per badge.

**Interactions.** Tap → dismiss.

**Transitions.** Scale + opacity, 0.5s spring.

**Edge cases.** Multiple badges earned in one verification: queue them, show in order.

**Accessibility.** Announces "Badge unlocked: <name>. <body>"

**Persistence.** Reads `UserProgress.unlockedBadges`; marks the badge as "viewed" locally to suppress further celebration.

**Gating.** N/A.

---

### S-CEL-02 · Streak Milestone Overlay · [Phase 11, 12]

**Purpose.** Celebrate milestone streaks before showing `S-VER-06`.

**Entry points.** ← `S-VER-05` success when streak hits a milestone (3/7/14/30/60/100).

**Exit points.** Auto-advances to `S-VER-06` after 3-5s, or tap to advance.

**Layout.** Full-screen rainbow Nimbus, big numeric streak, title.

**Components.** `NimbusView(state: .rainbow)`, large `Text` streak count, title.

**Copy.**
- Title: **"<n>-day streak!"**
- Body: micro-line per milestone:
  - 3: *"Three days. Real momentum."*
  - 7: *"A whole week. You're doing it."*
  - 14: *"Two weeks. This is who you are now."*
  - 30: *"Thirty days. Most people quit by now. Not you."*
  - 60: *"Sixty days. We're in rare air."*
  - 100: *"One hundred days. Take a screenshot."*

**States.** One per milestone.

**Interactions.** Tap → advance.

**Transitions.** Full-screen wash → next screen.

**Edge cases.** Reduce Motion → static fade.

**Accessibility.** Announces streak count and milestone copy.

**Persistence.** None (already written by `S-VER-06` path).

**Gating.** N/A.

---

### S-NOT-01 · Local Notifications Content · [Phase 15]

Not a screen — a catalog of the four local notifications and what each does when tapped. Listed for AI clarity.

| ID | Trigger | Title | Body | On-tap target |
|---|---|---|---|---|
| `morning` | Daily 8:30 AM | *"Good morning."* | *"Nimbus is ready for today's outdoor break."* | `S-TODAY-01` |
| `pre_block` | Dynamic: 30 min before projected block time | *"30 minutes left."* | *"You're about to hit your daily limit. Pause now if you want to save time for later."* | `S-TODAY-01` |
| `block_start` | When `eventDidReachThreshold` fires (always on) | *"Apps are paused."* | *"Go outside to unlock — Nimbus is waiting."* | `S-VER-01` (deep link to verify) |
| `streak_warn` *(Pro)* | 10 PM local if `didVerifyToday=false` and `currentStreak ≥ 3` | *"Don't break your <n>-day streak."* | *"Verify or it resets at midnight."* | `S-VER-01` |

Tap handling is via the URL deep-link mechanism described in §0.6 — each notification carries a `userInfo["link"]` that the app routes through the same `.onOpenURL` pipeline used by the shield.

---

# Part 2 — End-to-End User Journeys

Each journey references screen IDs from Part 1. Numbered steps assume no skipping unless a branch is called out. Most journeys are < 1 minute of clock time.

---

## J-01 · First Install → Configured

❶ User downloads Sky from App Store, opens it.
❷ `S-ONB-01` flashes (< 200ms) → `S-ONB-02` (welcome).
❸ User swipes through `S-ONB-02 → S-ONB-03 → S-ONB-04 → S-ONB-05 → S-ONB-06`.
❹ Tap "Let's go" → writes `OnboardingCompleted=true` → `S-PERM-01`.
❺ Tap "Allow Screen Time access" → iOS system prompt → user grants → `S-CFG-01`.
   - Branch: deny → `S-PERM-02` → user opens Settings → grants → returns → `S-CFG-01` (via `.onChange` of `authorizationStatus`).
❻ Tap "Choose apps" → `S-CFG-02` sheet → user picks 4 apps. (Free user cap: 2 — if exceeds, toast + re-pick.)
❼ Tap "Continue" → `S-CFG-03` → user picks "Combined" (Free) → `S-CFG-04` → picks "2 h" → tap "Save".
❽ `S-CFG-06` toast appears.
❾ First-time `S-PERM-03` (notifications) → user grants or skips.
❿ Lands on `S-TODAY-01` in `unblocked` state. `DeviceActivityService.startMonitoring()` is called in the background; status banner reads "Sky is watching."

---

## J-02 · Normal Day Under Budget

❶ Cold launch → `S-TODAY-01` `unblocked`. Banner: "Sky is watching." Ring shows 0 / 2h.
❷ User goes about their day. Ring updates each foreground (read from `DeviceActivityCenter`).
❸ ↻ At local midnight, no action needed by user. `DeviceActivityMonitor.intervalDidStart` writes reset flags.
❹ Next launch shows the same state (counters reset).

---

## J-03 · Hitting Budget → Successful Verification

❶ User scrolls Instagram. Hits 2h cap.
❷ iOS calls `SkyDeviceActivityMonitor.eventDidReachThreshold` → `ManagedSettingsStore().shield.applications = selection.applicationTokens` → `isCurrentlyBlocked=true`.
❸ `block_start` notification fires.
❹ User taps Instagram icon → `S-SHIELD-01` (custom shield) renders.
❺ User taps "Go outside to unlock" → `sky://verify` → main app opens → `S-VER-01`.
❻ First-time path: `S-PERM-04` → permissions granted.
❼ User taps "I'm outside" → `S-VER-03` recording begins.
❽ User walks outside following prompts (0s, 6s, 14s, 22s). 30s elapses.
❾ `S-VER-05` processing for < 5s.
❿ Pipeline passes → `S-VER-06`. Apps unlocked: `shield.applications = nil`, `didVerifyToday=true`. Mascot → `.celebrating` 5s → `.sunny`. Streak +1.
⓫ If milestone hit, `S-CEL-02` precedes `S-VER-06`.
⓬ On `S-VER-06` "Done", if a badge unlocked, `S-CEL-01`.
⓭ Dismiss → `S-TODAY-01` shows `verifiedToday` banner.

---

## J-04 · Hitting Budget → Emergency Unlock

Steps 1–4 same as J-03.

❺ User taps "I can't go outside right now" → `S-EMG-01`.
❻ Tap "Yes, I need to unlock" → `S-EMG-02`.
❼ User types reason (must be ≥20 chars, no paste, no newline). Countdown 5s ticks.
❽ Button enables. User taps "Unlock anyway".
❾ `EmergencyUnlockEntry` written to local store (NEVER CloudKit). `didEmergencyUnlockToday=true`. Shields cleared. Mascot → `.rainy`. Streak reset to 0.
❿ `S-EMG-03` confirms. Tap "Done" → `S-TODAY-01` `emergencyUnlocked` state.

---

## J-05 · Failed Verification → Recovery

Steps 1–9 same as J-03 through `S-VER-05`.

❿ Pipeline fails with e.g. `noSkyVisible` → `S-VER-07` with that reason.
⓫ Branch A — Try again: tap "Try again" → `S-VER-01` → `S-VER-03` (permissions already granted, skip pre-flight if all OK).
⓬ Branch B — Emergency: tap "I can't go outside" → `S-EMG-01` (continues per J-04).
⓭ Branch C — Close: dismiss to `S-TODAY-01` still in `blocked` state. Shields remain.

After 3 consecutive failures in one session, inline tip appears on `S-VER-07` pointing to Support.

---

## J-06 · Midnight Reset

↻ At 00:00 local time, `SkyDeviceActivityMonitor.intervalDidStart(for:)` fires inside the extension:
- `ManagedSettingsStore.shield.applications = nil`, `.applicationCategories = nil`.
- `SharedDefaults.isCurrentlyBlocked = false`, `didVerifyToday = false`, `didEmergencyUnlockToday = false`, `todayResetToken = today YYYY-MM-DD`.

If the user was in `emergencyUnlocked` or `verifiedToday` state, they wake up to `unblocked`.

**Streak evaluation** runs via `StreakManager` on next main-app foreground:
- Yesterday verified, no emergency → no change (streak holds).
- Yesterday neither → streak reset to 0.
- Yesterday emergency → streak already reset on emergency action; verify that `currentStreak == 0`.

Mascot transitions to `.cloudyGrey` on next foreground.

User-facing: no notification or surface unless they open the app.

---

## J-07 · Streak Milestone Hit

Steps 1–9 same as J-03.

⓲ During `S-VER-05`, `StreakManager` increments streak. If new value is in {3, 7, 14, 30, 60, 100}, queue milestone overlay.
⓳ `S-CEL-02` shown with milestone copy.
⓴ Auto-advance to `S-VER-06`.
㉑ Dismiss → `S-CEL-01` if the milestone also unlocked a badge (e.g. 3 days unlocks Cumulus, 7 days unlocks Stratus, etc.).
㉒ Tab bar Streaks tab gets a coral dot until the user visits and views the badge.

---

## J-08 · Free User Hits Pro Gate

❶ User on Free, navigates to `S-CFG-03` and taps "Per app" segment.
❷ Segment reverts; `S-PAY-05` slides up.
❸ Tap "See Pro" → `S-PAY-01`.
❹ Branch A — purchase Annual: tap card → StoreKit sheet → success → `S-PAY-04` (trial confirm). `isPro=true`. Dismiss returns to `S-CFG-03` with Per-app now selectable.
❺ Branch B — close: `S-PAY-05` dismisses; user stays in Combined mode.

Same pattern for:
- Tapping >2 apps in `S-CFG-02` → toast + re-pick or upgrade link.
- Tapping Pause Sky in `S-SET-01`.
- Tapping Weekly insights in `S-STREAK-01`.
- Toggling Streak warning in `S-SET-04`.

---

## J-09 · Purchasing Each Tier

**Monthly.** `S-PAY-01` → tap Monthly card → StoreKit sheet → success → close paywall → `isPro=true` (no `S-PAY-04`).

**Annual w/ trial.** Same path; `S-PAY-04` follows.

**Lifetime.** `S-PAY-01` → tap Lifetime → StoreKit sheet → success → close paywall → `isPro=true`. `S-SET-07` will read "Sky Pro · Lifetime".

**Founder's Lifetime.** Same as Lifetime but only available while seats remain. Seat counter (cached) decrements optimistically on success; refreshes from plist nightly. If App Store rejects (sold out), recover gracefully.

---

## J-10 · Restoring Purchases on Fresh Install

❶ Reinstall Sky → onboarding → `S-PERM-01` → `S-CFG-01`.
   - Or: skip into `S-SET-07` Restore.
❷ Tap Restore → `StoreKitService.refreshEntitlement()` runs.
❸ `S-PAY-03` confirms outcome.
❹ If success, `isPro=true` and Pro-gated UI immediately unlocks.

---

## J-11 · Pause Sky for 24 Hours

❶ Pro user navigates `S-SET-01 → S-SET-03`.
❷ Types reason (≥20 chars, paste blocked, 5s countdown).
❸ Tap "Pause Sky".
❹ `SharedDefaults.pauseStartedAt = Date()`. `DeviceActivityService` is told to ignore threshold callbacks until `Date()+24h`. `ManagedSettingsStore.shield.applications = nil`.
❺ `S-TODAY-01` banner switches to `paused` with countdown.
❻ ↻ At pause expiry, shields reapply if usage already exceeded threshold (re-evaluate); otherwise normal monitoring resumes.
❼ Subsequent attempt within 7 days → `S-SET-03` alternate variant blocks the action with a "next available" date.

---

## J-12 · Editing App Selection After Setup

❶ User opens `S-SET-01 → S-SET-02 → S-CFG-01`.
❷ Tap "Edit selection" → `S-CFG-02`.
❸ Adds/removes apps → dismiss.
❹ Selection persisted, `DeviceActivityService.startMonitoring()` re-run with new events.
   - Branch: tokens invalidated (iOS upgrade): `S-CFG-01` warns and continues to disable until re-pick.

---

## J-13 · Editing Limits After Setup

❶ `S-SET-01 → S-SET-02 → S-CFG-03`.
❷ Toggle mode or change values.
❸ Save → `DeviceActivityService.startMonitoring()` re-run with new thresholds.

Mode-switching preserves per-mode data: if user goes Combined → Per-app → Combined, the combined value is unchanged.

---

## J-14 · CloudKit Sync to Second Device

❶ User installs Sky on iPad/second iPhone signed into same iCloud.
❷ Goes through `S-ONB-*` → `S-PERM-01` → `S-CFG-01`. Note: `FamilyActivitySelection` tokens are **device-specific** and do NOT sync. User must re-select apps.
❸ Streaks/badges/mascot state arrive via CloudKit. `S-STREAK-01` shows the same numbers.
❹ Verification on either device updates both.
❺ Conflict resolution: last-writer-wins for counters; union for `unlockedBadges`. Verification on two devices in the same minute results in one streak +1 (idempotent on date).

---

## J-15 · Notification Tap Handling

| Notification | Tap behavior |
|---|---|
| `morning` | → `S-TODAY-01` |
| `pre_block` | → `S-TODAY-01` |
| `block_start` | → `S-VER-01` (deep link to verify) |
| `streak_warn` | → `S-VER-01` |

If user is already in the target screen, no-op. If in a modal, the deep link is queued and presented on dismissal.

---

## J-16 · Re-Authorize After iOS Major Upgrade

❶ Cold launch after upgrade.
❷ `AppCoordinator` detects `AuthorizationCenter.shared.authorizationStatus != .approved`.
❸ Routes to `S-PERM-01`.
❹ User re-grants. Selection and limits are preserved (they're in `SharedDefaults`). Monitoring resumes.

If `FamilyActivitySelection` tokens were invalidated by the upgrade, additional re-pick prompt in `S-CFG-01`.

---

## J-17 · Recording Interrupted

❶ User in `S-VER-03`, recording at 12s.
❷ Phone rings → `AVCaptureSession` fires interruption.
❸ Sky cancels recording, deletes partial video → `S-VER-08`.
❹ User taps "Try again" → `S-VER-01` → re-record from scratch.

Same for app backgrounded mid-record, low battery emergency, or storage exhausted.

---

# Part 3 — Cross-Cutting References

## 3.1 Global State Machines

### Mascot

States: `cloudyGrey`, `fluffyWhite`, `sunny`, `rainbow`, `rainy`.

Transitions table:

| From | Event | To |
|---|---|---|
| any | midnight reset, no verification today | `cloudyGrey` |
| `cloudyGrey` / `fluffyWhite` | verification success | `rainbow` (5s) → `sunny` |
| `cloudyGrey` / `fluffyWhite` / `sunny` | emergency unlock | `rainy` |
| `cloudyGrey` | normal usage tick under budget | `fluffyWhite` |
| `sunny` | next midnight reset | `cloudyGrey` |
| `rainy` | next midnight reset | `cloudyGrey` |
| `rainbow` | 5s elapsed | `sunny` |

Persisted in `UserProgress.mascotState` (CloudKit) and `SharedDefaults` mirror.

### App-block

States: `unblocked`, `blocked`, `verifiedToday`, `emergencyUnlocked`, `paused`.

Transitions:

| From | Event | To |
|---|---|---|
| `unblocked` | threshold hit | `blocked` |
| `blocked` | successful verification | `verifiedToday` |
| `blocked` | emergency unlock | `emergencyUnlocked` |
| `verifiedToday` | midnight | `unblocked` |
| `emergencyUnlocked` | midnight | `unblocked` |
| `unblocked` / `blocked` | pause activated | `paused` |
| `paused` | 24h elapsed | re-evaluate → `unblocked` or `blocked` |

### Verification

`idle → recording → processing → success | failure → idle (with cleanup)`

## 3.2 Free vs Pro Master Gating Table

| Feature | Screen ID(s) | Free | Pro |
|---|---|---|---|
| Number of apps that can be selected | `S-CFG-01`, `S-CFG-02` | 2 max | unlimited |
| Combined vs per-app limits | `S-CFG-03`, `S-CFG-05` | Combined only | Both |
| Pause Sky for 24h | `S-SET-03` | Hidden gate → `S-PAY-05` | Available, 1 / 7 days |
| Weekly insights | `S-STREAK-01`, `S-STREAK-04` | Gate prompt | Available |
| Streak warning notification | `S-SET-04` | Disabled with `[Pro]` chip | Available |
| All 10 badges | `S-STREAK-02` | Earn-by-action no restriction *(confirm)* | Same |
| Founder's Lifetime tier | `S-PAY-01` | Available while seats remain | n/a (already Pro) |
| Custom mascot reactions (full 5 states) | `S-TODAY-01`, mascot system | All states usable in v1.0 | Same — no Free restriction in v1.0 |

*Note: PRD §4.9 lists "all badges, all mascot states, full insights" as Pro features. v1.0 implementation choice: badges that are inherently locked by behavior (`Boundless`, `Wanderer`) display to free users but only Pro users unlock the special UI. **Confirm with product before Phase 12 ships.**

## 3.3 Copy Library

All user-facing strings, grouped by screen ID. English-only for v1.0. Localizable.strings keys mirror IDs (e.g. `S_ONB_02_title`).

```
S_ONB_02_title  = "Hi, I'm Nimbus."
S_ONB_02_body   = "I'll help you spend less time scrolling and more time outside. It's going to take a little work — but you've got this."
S_ONB_03_title  = "Pick the apps that pull you in."
S_ONB_03_body   = "You'll choose from your phone's apps. Sky never sees their names — only you do."
S_ONB_04_title  = "Decide how much is enough."
S_ONB_04_body   = "One hour. Two. Three. When you hit your limit, the apps pause until you take a break outside."
S_ONB_05_title  = "Touch grass, then come back."
S_ONB_05_body   = "To unlock the apps, head outside and record a short video. Sky checks the sky, the light, and your steps — all on your phone."
S_ONB_06_title  = "Your videos stay on your phone."
S_ONB_06_b1     = "Verification runs on-device. Videos are deleted right after."
S_ONB_06_b2     = "No screen-time data ever leaves your phone."
S_ONB_06_b3     = "Your reasons for emergency unlocks stay private to you."
S_ONB_06_cta    = "Let's go"

S_PERM_01_title = "Sky needs Screen Time access."
S_PERM_01_body  = "This is the permission that lets Sky pause apps when you hit your daily limit. We use it for your phone only — never for monitoring anyone else."
S_PERM_01_cta   = "Allow Screen Time access"

S_PERM_02_title = "Sky needs that permission."
S_PERM_02_body  = "Without Screen Time access, Sky can't pause apps for you. Open Settings → Screen Time and toggle Sky on, then come back."
S_PERM_02_cta1  = "Open Settings"
S_PERM_02_cta2  = "Try again"

… (full library continues with one entry per screen + state — populate during Phase 1)
```

Treat this section as the authoritative source. When implementing a screen, lift strings from here rather than re-inventing.

## 3.4 Error & Edge-Case Catalog

| Situation | Detection | Handling |
|---|---|---|
| Family Controls denied | `authorizationStatus != .approved` | `S-PERM-02` |
| Family Controls revoked post-setup | Re-check on launch | Route to `S-PERM-01` |
| Camera permission denied | `AVCaptureDevice.authorizationStatus(for:)` | `S-VER-02` shows Settings link |
| Microphone permission denied | Same | Same |
| Location permission denied | `CLAuthorizationStatus` | Same |
| Notifications denied | `UNUserNotificationCenter.notificationSettings` | `S-SET-04` rows disabled, Settings link |
| No network on launch | `NWPathMonitor` | CloudKit silent retry; sync icon in `S-SET-06` |
| No GPS lock | Location updates not delivered in 10s | Verification will fail with `poorGPSSignal` → `S-VER-07` |
| Low battery | `UIDevice.current.batteryLevel < 0.05` | Warning in `S-VER-01`, allow proceed |
| Low storage | `FileManager` attributes < 200 MB | Block `S-VER-03` start with friendly error |
| Airplane mode | `NWPathMonitor` | App still works (everything is on-device); CloudKit deferred |
| CloudKit account not signed in | `CKContainer.accountStatus()` | `S-SET-06` prompts; local cache continues working |
| StoreKit unavailable | `Product.products(for:)` throws | `S-PAY-01` shows "Couldn't load prices" + retry |
| Camera hardware unavailable | AVCapture error | `S-VER-03` shows hardware error |
| Token invalidation | Codable decode fails | `S-CFG-01` warns and disables continue |
| Phone call mid-record | AVCaptureSession interruption | `S-VER-08` |
| App backgrounded mid-record | Scene phase change | `S-VER-08` |
| Pause attempted twice in 7 days | `pauseStartedAt` check | `S-SET-03` alternate variant |
| Founder seats sold out | App Store rejects purchase | `S-PAY-02` variant, refresh counter |
| Trial revoked | StoreKit transaction reversed | Silent downgrade, toast on next launch |

## 3.5 Deep Link Routing Table

| URL | Handler | Target | Notes |
|---|---|---|---|
| `sky://verify` | `SkyApp.onOpenURL` | `S-VER-01` | Most common; from shield + notifications |
| `sky://emergency` | Same | `S-EMG-01` | From shield aux |
| `sky://today` (reserved) | Same | `S-TODAY-01` | For v1.1 widgets |
| Notification `userInfo["link"]` | `LocalNotificationScheduler` delegate | Routes via same mechanism | Queue if a modal is up |

## 3.6 Accessibility Checklist (per screen group)

**Dynamic Type.** All `Text` uses semantic styles (`largeTitle`, `body`, etc.). Buttons grow with type size — never truncate primary actions. Test at `.accessibility5`.

**VoiceOver.** Every interactive element has a label and hint. Decorative views (`NimbusView` in onboarding, illustrations) are `accessibilityHidden(true)` and the surrounding text carries the meaning. Mascot in `S-TODAY-01` is *not* hidden — its state carries information ("Nimbus is sunny — you're verified today").

**Reduce Motion.**
- Mascot idle loops freeze on first frame.
- Mascot transitions become 0.2s crossfades.
- `S-VER-03` ring counts in discrete 1-second ticks rather than smooth.
- `S-CEL-*` overlays appear without bounce.
- Page transitions in onboarding become standard fades.

**Color contrast.** All primary text ≥ 4.5:1 against background. Status banners use color + icon, never color alone. Test in both Light and Dark.

**Keyboard / hardware keyboard.** Tab order on `S-EMG-02` is field → cancel → unlock. Return key on `PasteBlockedTextField` is rejected (per spec); use the Unlock button.

## 3.7 Light & Dark Mode

`AppBranding` colors are defined as `Color(hex:)` — they render identically in light and dark in v1.0. Dark mode overrides:

- `warmCream` → a slightly desaturated cream (`#2A2820`) for backgrounds; tokens defined in `ColorTokens.swift`.
- `cloudGrey` → lighter in dark mode for legibility.
- Shadows on `SkyCard` are softened in dark.

Per-screen notes only where layout shifts: none in v1.0.

## 3.8 Sensor + Vision Threshold Reference

Pointer only. **Do not duplicate values here.** Authoritative source: `Sky_Technical_Spec.md §8.5` (`VerificationThresholds.swift`). All decisions in the verification engine pull from that file. Phase 10 manual testing will tune values; the workflow doc never repeats them to avoid drift.

## 3.9 Data Flow (text diagram)

```
Main app
  ├── reads/writes → SharedDefaults (UserDefaults @ group.com.sky.shared)
  │     · familyActivitySelection (write on S-CFG-02; read by DeviceActivityMonitor)
  │     · limitMode, combinedLimitSeconds, perAppLimitsData (write on S-CFG-03; read by DeviceActivityService)
  │     · isCurrentlyBlocked, didVerifyToday, didEmergencyUnlockToday (read on S-TODAY-01; written by extension + main)
  │
  ├── reads/writes → CloudKit private DB · UserProgress("current")
  │     · streak, badges, mascot state, lifetime counters, locations (rounded 0.01°)
  │
  ├── writes → EmergencyLogStore (App Group container; on-device only)
  │     · EmergencyUnlockEntry on S-EMG-02 submit
  │
  ├── writes → temporaryDirectory
  │     · verification_<UUID>.mov during S-VER-03; deleted after S-VER-06/07
  │
  └── observes → StoreKitService
        · isPro, products, transaction updates

DeviceActivityMonitor extension
  ├── reads → SharedDefaults (selection, limits)
  └── writes → SharedDefaults (isCurrentlyBlocked, midnight resets), ManagedSettingsStore

ShieldConfigurationExtension
  └── reads → SharedDefaults (optional theming)

ShieldActionExtension
  └── opens URL → main app (sky://verify, sky://emergency)
```

## 3.10 Phase-to-Screen Index

When building Phase N, pull only these screens from Part 1 and these journeys from Part 2.

| Phase | Title | Screens | Journeys |
|---|---|---|---|
| 0 | Foundation | (no UI) | — |
| 1 | Design System & Mascot | `S-SET-09` (DesignSystemPreviewScreen), defines components used by every later screen | — |
| 2 | Onboarding | `S-ONB-01..06` | J-01 (partial) |
| 3 | Family Controls + App Selection | `S-PERM-01..02`, `S-CFG-01..02` | J-01 (auth + selection), J-12 |
| 4 | Limit Configuration | `S-CFG-03..06` | J-01 (limits), J-13 |
| 5 | Screen Time Monitoring | `S-TODAY-02` status banners (data layer only; UI integrates in Phase 11) | J-02, J-03 (block start), J-06 |
| 6 | Custom Shield + Shield Actions | `S-SHIELD-01..03` | J-03, J-04 (shield path) |
| 7 | Video Recording UI | `S-VER-01..04`, `S-VER-08`, `S-PERM-04` | J-03 (record), J-17 |
| 8 | Sensor Fusion | (back-end for `S-VER-05`) | — |
| 9 | Vision Outdoor Classification | (back-end for `S-VER-05`) | — |
| 10 | Verification Decision + Unlock | `S-VER-05..07` | J-03, J-05 |
| 11 | Mascot Reactions + Today | `S-TODAY-01`, `S-TODAY-02`, `S-TAB-00` (Today portion), `S-CEL-02` | J-02, J-03 |
| 12 | Daily Reset, Streaks, Badges | `S-STREAK-01..03`, `S-CEL-01`, CloudKit sync | J-06, J-07, J-14 |
| 13 | Emergency Unlock | `S-EMG-01..03`, `S-STREAK-04` | J-04 |
| 14 | StoreKit + Paywall | `S-PAY-01..05`, `S-SET-07` | J-08, J-09, J-10 |
| 15 | Settings + Notifications + App Store Readiness | `S-SET-01..08`, `S-NOT-01`, `S-PERM-03` | J-11, J-15, J-16 |

---

# End of Document

This file is the workflow source of truth. When a phase ships, return here and update:
1. Any screen whose copy changed.
2. Any new state or edge case discovered during real-device testing.
3. The Phase-to-Screen Index if scope shifted.

Keep `Sky_PRD.md`, `Sky_Development_Roadmap.md`, `Sky_Technical_Spec.md`, and this file in lockstep. They are the entire spec.
