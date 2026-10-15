# Daily Lock Plan

Pivot from "time budget → lock" to **"apps lock every morning until you go outside."**
Decided 2026-10-14. Supersedes the session-ladder model (commit `ab14e9a`) and
`TIME_REMAINING_PLAN.md`.

## The new model in one paragraph

The user picks a lock time (default 9:00). At that time each day the selected apps
are shielded. One outdoor verification unlocks them **until the next lock time**.
Verifying before the lock time (early bird) skips that day's lock. If the user never
verifies, the apps **stay locked** — there is no midnight release. The emergency unlock
works the same as a verification for unlocking (until next lock time) but still
costs the streak.

No usage counting at all: no `DeviceActivityEvent`, no thresholds, no
`includesPastActivity`, no ladder. Those are the source of the random notifications.

## Verification in one paragraph

A **5-second clip**, tilting from the ground up to the sky, plus three checks:

1. **GPS** — not spoofed, horizontal accuracy ≤ 50 m (was 25 m).
2. **Steps** — ≥ 200 steps in the 15 minutes before recording, read retroactively
   from `CMPedometer.queryPedometerData(from:to:)`. The user walks first, then
   records; Sky doesn't need to be open during the walk.
3. **Outdoor scene** — ≥ 60% of sampled frames classify outdoor and the best frame
   shows ≥ 10% sky. **Waived after civil dusk**, where GPS + steps carry it alone.
   This replaces Night Mode.

Removed: daylight window, movement speed/altitude, exposure bias. All new values
live in `VerificationThresholds.swift` and are still placeholders until field-tested.

---

## Phase A — Fix the shield screen (ship first, independent)

**Files:** `ShieldConfigurationExtension/SkyShieldConfiguration.swift`,
`ShieldActionExtension/SkyShieldAction.swift`, `Sky/App/SkyApp.swift`.

1. Dynamic colors: every `UIColor` becomes `UIColor { traits in … }` with the light
   and dark token pairs from `DESIGN_SYSTEM.md`. That fixes the near-invisible title and
   secondary label in dark mode.
2. Copy: title "Apps are paused", subtitle "Nimbus is waiting outside for you ☁",
   primary "Unlock with Sky", secondary "Emergency unlock". These are short enough
   not to wrap.
3. Button taps: keep writing `pending_deep_link`, **and** post a local notification
   ("Tap to head outside with Nimbus ☁") whose `userInfo` carries the deep link, then
   return `.close`.
4. App side: a `UNUserNotificationCenterDelegate` (set in `SkyApp.init`) routes
   `didReceive` → `deepLinkDestination`. There's no delegate today.

**Verify:** on a device in light and dark mode, both buttons → notification → tap
opens the right flow.

## Phase B — Daily lock engine

**`DeviceActivityService`** (~300 lines deleted):
- Two activities, no events:
  - `.midnight`: 00:00–23:59. Runs only the streak/day rollover.
  - `.lock`: lockTime–23:59. Applies the shield.
- Delete the ladder, `makeEvents`, the per-app event names, `rung(from:)`, and
  `maxEventsPerActivity`.
- Fingerprint `v3` = selection + lockTime + OS major. Keep the no-op guard.
- Stamp `lockArmedAt` on every registration.

**`SkyDeviceActivityMonitor`** (~250 lines deleted):
- `intervalDidStart(.lock)`: skip if any of these hold:
  - paused
  - verified or emergency-unlocked since local midnight
  - `now − lockArmedAt < 60 s`. A just-registered schedule can fire immediately, so
    a lock-time change takes effect tomorrow and a re-arm never locks spuriously.

  Otherwise shield the selection, set `isCurrentlyBlocked`, and post "Apps are paused
  for the day. Nimbus is waiting outside ☁".
- `intervalDidStart(.midnight)`: the existing rollover, **minus the shield clear**.
  It snapshots yesterday's flags for streaks, then resets `didVerifyToday` and
  `didEmergencyUnlockToday`. It must not touch `isCurrentlyBlocked` or
  `ManagedSettingsStore`, so an unverified day stays locked.
- Delete `eventDidReachThreshold` and all the rung/notification-cap code.

**`MidnightResetRecovery`**: same change. It must never clear the shield.

**`ShieldService`**:
- `unlockApps` is unchanged (assigning `nil` still clears orphaned tokens).
- `tokensToRestore` / `categoriesToRestore` become "the whole selection".
- Add a missed-callback catch-up in `reconcile`: if now ≥ today's lock time, not
  unlocked today, and the shield isn't applied → apply it.

**`SharedDefaults`**:
- Add `lockTimeMinutes` (default 540) and `lockArmedAt`.
- Remove `limitMode`, `combinedLimitSeconds`, `perAppLimits`, `lastFiredRungs`,
  `notifWarning*`, `notifBlockStartDay`, and `nightModeEnabled`. Mirror these changes
  in the extension's raw keys.

**Tests:**
- Rewrite `DeviceActivityServiceTests`: two activities, no events, and the fingerprint
  changes with lockTime.
- `ShieldServiceTests`: catch-up apply; midnight never unlocks.
- `MidnightResetRecoveryTests`: shield untouched.
- Add one test pinning "early-bird verify skips today's lock".

## Phase C — Notifications

- **Delete:** "30 minutes left", "Time's up", and the warning toggle in
  `NotificationTogglesView`.
- **Keep:** the streak-at-risk calendar notification.
- **New:** only the lock notification (Phase B) and the shield-tap notification (Phase A).

## Phase D — UI and copy

| Screen | Change |
|---|---|
| `LimitConfigurationView/ViewModel` | Becomes a lock-time picker: "When should your apps pause each day?" Combined/per-app modes deleted. |
| `SettingsAppsAndLimitsView` | Shows the lock time instead of the session length. |
| `TodayView` | Time-remaining ring → status card: "Locked — Nimbus is waiting outside" / "Unlocked until tomorrow, 9:00". |
| Onboarding pages | Copy: "Your apps pause every morning. Step outside to get them back." |
| `PaywallView` | The "Per-app session limits" Pro row goes. Replace it with **lock days** (e.g. weekends off, Pro); the extension checks the weekday. |
| `DebugMenuView` / `DebugSeeder` | Drop limit seeding; add "fire lock now". |
| Docs | PRD, `Sky_App_Workflow.md` (J-02/J-03/J-06, S-CFG, S-TODAY), Tech Spec §7.3–7.4, the CLAUDE.md "session ladder" paragraph. Mark `TIME_REMAINING_PLAN.md` and `NIGHT_VERIFICATION_DECISION.md` as superseded. |

**Tests:** `LimitConfigurationViewModelTests` and `GatingTests` rewritten for lock time
and lock days.

## Phase E — Verification: 3 checks + 5 s clip

- `VideoRecordingViewModel`: 30 s → 5 s. One prompt: "Tilt from the ground up to the sky."
- `VerificationIntroView`: "Take a short walk outside first (about 200 steps), then
  record." Show a live step count from the pedometer.
- `SensorRecorder`: add a pedometer query; drop the speed/altitude/exposure collection.
- `VerificationDecisionEngine`: spoof → accuracy → steps → (daylight ? scene : pass).
- `FailureReason`:
  - remove `outsideDaylightWindow`, `notEnoughMovement`, `notBrightEnough`
  - add `notEnoughSteps`: "A few more steps — Nimbus wants a little walk ☁"
  - merge `sceneNotOutdoor` and `noSkyVisible` into one kind message
- `PermissionPreflightView`: Motion & Fitness permission. `NSMotionUsageDescription`
  already exists. Denied → fail with a Settings link.
- Delete `NightModeView`, the Night Mode setting, and the `VisionAnalysis/Debug/` spike.

**Tests:** rewrite `VerificationDecisionEngineTests` around the four gates and the
dusk waiver.

## Phase F — Sky card (optional, needs a privacy decision)

Keep the clip's best frame as one JPEG in the app container (the video is still deleted
immediately). Show it as "today's sky" on Today, with a share sheet and a streak collage.
This changes the PRD privacy invariant from "nothing kept" to "one still, on-device,
user-deletable", so update `PRIVACY_POLICY.md` too.

---

## Order and done-ness

A → B + C (one commit, since they share the extension) → D → E → F.

After each phase:
- iOS build with `DEVELOPER_DIR=…`, plus a Release build
- tests at the 2-failure baseline
- `graphify update .`

**Exit criterion:** three real days on a device. The apps lock exactly at lock time,
there are zero unexplained notifications, and a real walk passes verification first
try at least 9/10 times. Check the debug audit trail for every lock and notification.

## Defaults I picked (say if you want different)

- Default lock time is 9:00 AM.
- An unverified day stays locked (no midnight release).
- After dark, the camera check is waived and GPS + steps decide.
- Lock days (weekends off) is the new Pro feature replacing per-app limits.

---

## Status — 2026-10-14

Phases A–E are implemented and uncommitted. Phase F is not started; it needs the
privacy decision above.

Changes from the plan made during implementation:
- **Lock-time changes apply immediately.** Only the very first arming after setup
  waives a lock time already past (`lock_skip_day`). Otherwise, moving the lock to
  an hour already gone would be a free way to skip the day.
- **Arm grace window.** The extension ignores a `.lock` start within 60 s of
  registration. The app-side catch-up (`ShieldService.reconcile`) applies the lock
  instead when it is really due.
- **Lock notification.** A tap opens verification directly (`sky_deep_link`).
- **Removed:**
  - `shieldedAppTokens`; the whole selection is always shielded
  - the Night Mode screen and the depth/texture debug spike, with their tests
- **Motion & Fitness** joins the verification permission preflight. A device that
  can't count steps has the step check waived.

Not verifiable in the simulator; needs a real device:
- the shield itself (colours, both buttons → notification → correct screen)
- the 9 AM `intervalDidStart`
- pedometer counts
- GPS within the 5 s clip + 6 s grace

Use the debug menu's Shield history to read every lock, skip and notification.
