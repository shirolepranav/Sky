# Implementation Plan — "Time left today" on the Today screen

**Status:** proposed, not started
**Screens:** `S-TODAY-01`, `S-TODAY-02`
**Touches:** `DeviceActivityService`, `SkyDeviceActivityMonitor`, `SharedDefaults`, `TodayView`

---

## 0. Correction to the original idea

The first sketch of this feature was:

> `remaining = limit − (now − intervalStart)`, ticked down with a `Timer`.

**That formula is wrong and must not be built.** `now − intervalStart` is *wall-clock*
time since midnight, but the budget is consumed only by *foreground time in the
monitored apps*. A 2-hour budget would read as exhausted by 02:00 every night.

The corrected design below produces a number that is **accurate every time the user
looks at it**, which is what "real-time" actually needs to mean here.

### Why it must not tick

There is a second, subtler reason to drop the ticking `Timer`. **While the Today
screen is on screen, the user is in Sky — not in Instagram.** No budget is being
consumed. A countdown animating downward while the user sits in Sky would be
draining a number that is, at that exact moment, frozen. It would also punish the
user visually for doing the healthy thing, which violates the "warm and truthful,
never guilt-trip" rule in `CLAUDE.md` / PRD §7.

So: the number is **stepped, not ticking**. It changes when the user comes back to
Sky after using their apps — which is precisely when they care.

---

## 1. What iOS actually gives us

`eventDidReachThreshold` is the **only** usage signal that reaches Sky. It fires
when cumulative usage of a monitored set crosses a threshold we registered in
advance. There is no polling API, and `DeviceActivityReport` runs in a sandboxed
process that cannot hand numbers back to the app.

Today we register exactly two thresholds
(`DeviceActivityService.swift:127`–`186`): a warning at `limit − 30m` and the limit
itself. So the app currently knows only "≥ limit−30m" and "≥ limit".

**The idea: register a ladder of checkpoints instead of two.** Each crossing writes
"usage was exactly *X* seconds at time *T*" into the App Group. Remaining time is
then `limit − X`, exact at the checkpoint and stale by at most one ladder step.

Checkpoints are defined in **remaining** minutes — the unit we display — so
precision automatically tightens as the user approaches the limit:

```
combined mode:  remaining = [90, 60, 45, 30, 20, 15, 10, 5]   → ≤ 8 events + limit
per-app mode:   remaining = [60, 30, 15, 5]                    → ≤ 4 events + limit, per app
```

Checkpoints whose threshold would be ≤ 0 are dropped, so a 30-minute limit yields
`[20, 15, 10, 5]`. Worst-case staleness is 5 minutes near the end and 30 minutes
early in the day, when it doesn't matter.

The existing `dailyWarning` / `perAppWarn_` events are **absorbed** by the
30-remaining checkpoint — one fewer event, one less concept. The extension keeps
posting the "30 minutes left" notification when that specific checkpoint fires.

---

## 2. ⚠️ Prerequisite — a pre-existing bug this feature will expose

`SkyApp.swift:117` re-arms monitoring on **every foreground**:

```swift
if coordinator.route == .main {
    try? deviceActivity.startMonitoring()   // → center.stopMonitoring([]) then start
}
```

`DeviceActivityEvent` counts usage **from the moment monitoring starts**, not from
the interval start, unless `includesPastActivity: true` is set (iOS 17.4+; the
default is `false` and Sky never sets it — confirmed: no occurrences in the repo).

If that is the case on device, **every launch of Sky silently grants a fresh full
budget**, and a user who opens Sky every 20 minutes is never blocked. Today this is
invisible because the UI is a binary state indicator. With a checkpoint ladder it
becomes loudly visible: the remaining number will jump back up to full.

Fix before anything else, in `DeviceActivityService.startMonitoring()`:

1. **Set `includesPastActivity: true`** on every event, behind
   `if #available(iOS 17.4, *)` (deployment target is 17.0).
2. **Stop thrashing the center.** Store a config fingerprint (hash of `selection` +
   `limitMode` + `combinedLimitSeconds` + `perAppLimitsData`) in `SharedDefaults`.
   `startMonitoring()` becomes a no-op when the fingerprint is unchanged *and*
   `isMonitoring` is already true. This also covers iOS 17.0–17.3, where
   `includesPastActivity` is unavailable — the counters simply stop being reset.

**Verify both on a real device before building the UI.** This is the single highest
-risk assumption in the plan. See §7 Spike 1.

---

## 3. Implementation

### Step 1 — Event-name encoding (self-describing thresholds)

The extension receives only a `DeviceActivityEvent.Name`, so the threshold value
must be recoverable from the name. Encode it directly rather than maintaining a
cross-process lookup table:

```
ck_<seconds>                  e.g. "ck_5400"
perAppCk_<base64Token>_<seconds>
```

New file `Sky/Core/ScreenTime/UsageCheckpointFormat.swift` — a small enum with
`makeName(seconds:)` / `parseSeconds(from:)` / `parseToken(from:)`.

**Add this one file to both the `Sky` and `DeviceActivityMonitorExtension` target
memberships** (a one-time `project.pbxproj` edit) so the encoder and decoder can
never drift. If that proves awkward, fall back to the existing precedent — the
duplicated-with-a-comment pattern already used for `SharedDefaults.Key` in
`SkyDeviceActivityMonitor.swift:21`.

### Step 2 — `DeviceActivityService` builds the ladder

In `Sky/Core/ScreenTime/DeviceActivityService.swift`:

- `static func checkpointThresholds(limitSeconds:remainingMinutes:) -> [Int]`
  — pure, returns ascending usage-seconds, drops non-positive values, dedupes.
- Rewrite `makeEvents(...)` and `makePerAppEvents(...)` to emit ladder events plus
  the terminal limit event. Delete `warningThresholdSeconds` and the
  `.dailyWarning` / `.perAppWarning` names once the 30-remaining checkpoint
  subsumes them.
- **Cap total events.** `maxEvents` constant (start at **20**, pending Spike 2).
  In per-app mode, if `appCount × (ladder + 1) > maxEvents`, degrade the ladder:
  `[60,30,15,5] → [30,10] → [] (limit event only)`. Never let the cap prevent the
  terminal limit event from being registered — blocking must not regress.

### Step 3 — Extension records checkpoints

In `DeviceActivityMonitorExtension/SkyDeviceActivityMonitor.swift`:

- `eventDidReachThreshold` (currently `:57`): parse the name.
  - **Checkpoint event** → write the crossing, then return without shielding.
    If the parsed seconds correspond to the 30-minutes-remaining checkpoint, post
    the existing warning notification (respecting `notifWarningEnabled`).
  - **Limit event** → existing shield path, unchanged, plus write a final
    checkpoint at `limit`.
- **Monotonic clamp:** write `max(existing, newSeconds)`. Never decreases within a
  day, so an out-of-order or duplicated callback can't move the number backwards.
- **Day-stamp every write** with the current `todayResetToken` (`YYYY-MM-DD`). The
  app discards a checkpoint whose stamp isn't today — this survives a missed
  `intervalDidStart`, which is the known-flaky callback.
- `intervalDidStart` (`:127`) additionally clears the checkpoint keys.
- Keep the pause guard (`:64`) ahead of everything, unchanged.

### Step 4 — `SharedDefaults` accessors

In `Sky/Core/Storage/SharedDefaults.swift`, add to the `Key` enum and mirror the raw
strings into the extension's `Key` enum:

| Key | Type | Meaning |
|---|---|---|
| `usage_checkpoint_seconds` | `Int` | combined mode: highest usage threshold crossed |
| `usage_checkpoint_at` | `Date` | when it was crossed |
| `usage_checkpoint_day` | `String` | `YYYY-MM-DD` stamp for staleness checks |
| `usage_checkpoint_perapp` | `Data` | per-app mode: JSON `[base64Token: Int]` |
| `monitoring_config_fingerprint` | `String` | §2 re-arm guard |

Expose two computed helpers:

```swift
/// Seconds of budget consumed as of the last checkpoint, or nil when no
/// checkpoint has been crossed today (or the stored one is stale).
var consumedSecondsToday: Int? { … }

/// Seconds remaining, floored at 0. nil when unknown.
var remainingSecondsToday: Int? { … }
```

`nil` is a first-class state, not zero — it means "under the first checkpoint",
which is genuinely different from "at the limit".

### Step 5 — `TodayView` display

In `Sky/Features/Today/TodayView.swift`:

- **Delete the stale comment at `:6`–`10`** and replace it with a note explaining
  the checkpoint model and *why the value does not tick*.
- **`ringProgress` (`:68`)** — currently binary `0.0`/`1.0`. Becomes
  `Double(consumed) / Double(limit)`, clamped `0...1`, falling back to the existing
  binary behaviour when `consumedSecondsToday == nil`. The ring finally means
  something.
- **`ringLabel` (`:333`)** — `"~45m"`, `"~1h 20m"`, `"0 left"`. When remaining is
  unknown, keep today's `"2h"` (the limit) so nothing regresses.
- **`bannerBody` `.unblocked` (`:302`)** — `"About 45m left today."`, falling back
  to the current `"Limit: 2 hours today."` when unknown. Keep the tilde/"about" —
  overstating precision we don't have would be dishonest.
- **`ringAccessibilityValue` (`:345`)** — `Sky_App_Workflow.md` S-TODAY-01 already
  specifies *"1 hour 15 minutes used of 2 hours"*; this feature is what finally
  makes that promise satisfiable. Use `DateComponentsFormatter` with
  `.spellOut`-friendly units, not a hand-rolled string.

**Refresh triggers** (no ticking timer):

1. `.onAppear` and pull-to-refresh — already re-read `SharedDefaults` at `:147`
   and `:153`.
2. `scenePhase → .active` in `SkyApp.swift:106`.
3. **A short catch-up poll.** The common case is: user crosses a checkpoint in
   Instagram, switches to Sky one second later, and the extension's callback lands
   a few seconds after that. Poll every 5s for the first 60s after foregrounding,
   then stop. Cheap, bounded, and fixes the one case the foreground read misses.
   *(Stretch: replace with a Darwin notification — `CFNotificationCenterGetDarwinNotifyCenter`
   — posted by the extension and observed by the app. Instant and pollless, but
   more moving parts; only worth it if the poll proves visibly laggy.)*

**Per-app mode UI.** Step 5 above ships combined mode only. Per-app remaining times
need a new list component under the ring and should be a **follow-up** — the ladder
data model (Steps 1–4) already supports it, so the second half is UI-only.

---

## 4. Copy

Honest hedging is deliberate; the number is genuinely approximate.

| State | Ring | Banner |
|---|---|---|
| Unknown (no checkpoint yet) | `2h` | "Limit: 2 hours today." *(unchanged)* |
| Remaining ≥ 1h | `~1h 20m` | "About 1h 20m left today." |
| Remaining < 1h | `~25m` | "About 25m left today." |
| Remaining ≤ 5m | `~5m` | "About 5 minutes left. Good time to head outside ☁️" |
| Blocked | `0 left` | *(unchanged)* |

Reviewed against PRD §7: states a fact, offers a warm suggestion, never scolds.

---

## 5. Tests

Everything load-bearing is a pure function, so this is cheap to cover in
`SkyTests/DeviceActivityServiceTests.swift` (extend the existing
`MockDeviceActivityCenter` at `:16`):

- `checkpointThresholds` — 2h limit, 30m limit, 5m limit, 0 limit; ascending,
  deduped, all positive.
- Ladder + limit event count stays ≤ `maxEvents` for 1, 5, and 20 selected apps;
  the terminal limit event is always present after degradation.
- `UsageCheckpointFormat` name round-trip, including a token whose base64 contains
  `_`.
- Monotonic clamp: writing 600 after 1800 leaves 1800.
- Day-stamp invalidation: yesterday's stamp ⇒ `consumedSecondsToday == nil`.
- `remainingSecondsToday` floors at 0 and never returns negative.
- Config-fingerprint guard: unchanged config ⇒ `startMonitoring` doesn't call
  through to the center; changed limit ⇒ it does.
- Label formatting: 4500s → `"~1h 15m"`, 300s → `"~5m"`, 0 → `"0 left"`.

Baseline per `CLAUDE.md` is **175 tests / 8 known failures** on iOS 26.2. Clean means
no *new* failures. Note the existing `SharedDefaults` test-pollution gotcha — the new
keys must be written through an injected suite, never `.standard`.

**Debug menu.** `DebugMenuView.swift` already has a "State" section (`:27`). Add
**"Simulate checkpoint crossing"** (steps the stored checkpoint to the next rung)
and **"Clear usage checkpoints"**. Without these the feature is close to untestable
in the simulator, since real threshold events need real foreground app usage.

---

## 6. Sequence

| # | Work | Gate |
|---|---|---|
| 0 | Spikes 1 + 2 on a real device (§7) | **Blocks everything** |
| 1 | `includesPastActivity` + config fingerprint (§2) | Ship-worthy on its own — it's a real bug fix |
| 2 | `UsageCheckpointFormat` + ladder in `DeviceActivityService` | Unit tests green |
| 3 | Extension writes checkpoints; `SharedDefaults` accessors | Debug-menu simulation works |
| 4 | `TodayView` ring + label + banner + a11y | On-device check against Settings → Screen Time |
| 5 | *(follow-up)* per-app remaining list | — |

Steps 1–4 are the shippable unit. Step 1 is worth landing by itself even if the
rest is deferred.

---

## 7. Risks and open questions

**Spike 1 — `includesPastActivity` semantics (blocking).** Does setting it `true`
make a mid-day `startMonitoring` count usage from midnight? Does a re-arm without
it really reset accumulation? Everything in §2 rests on this and it must be
measured, not assumed.

**Spike 2 — maximum event count (blocking).** Apple does not document a per-activity
`DeviceActivityEvent` limit. Register 5 / 10 / 20 / 30 / 50 events on device and
find where `startMonitoring` throws. `maxEvents = 20` is a conservative placeholder,
not a known value. If the real ceiling is low, the combined ladder shrinks to
`[60, 30, 15, 5]` and per-app remaining may be limit-event-only.

**Event latency and reliability.** `DeviceActivity` callbacks are historically
delayed or occasionally dropped. Mitigated by design — monotonic clamping, the
day-stamp, and "about" phrasing — but measure typical latency during Spike 1.

**Extension memory.** `DeviceActivityMonitor` runs under a tight memory cap (~6 MB).
Our additions are a few `UserDefaults` writes and a string parse; no risk, but do
not let this path grow.

**Combined mode with category tokens.** A selection may contain category tokens as
well as app tokens. The ladder is attached to the whole event, so this works
unchanged — but verify a category-only selection still fires checkpoints.

**Accuracy ceiling.** Sky's number can never exactly match Settings → Screen Time.
The "about" framing is load-bearing, not a hedge to be polished away later.

---

## 8. What this is not

Not a live per-second countdown — Apple's APIs cannot support one, and §0 explains
why one would be actively misleading even if they could. What ships is a
**checkpoint-accurate remaining figure**, correct to within one ladder step every
time the user looks at it, on a ring that finally reflects real usage.
