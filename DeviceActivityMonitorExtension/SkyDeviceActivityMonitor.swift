// SkyDeviceActivityMonitor.swift
// Principal class for the DeviceActivityMonitor extension target.
// Receives threshold and interval callbacks from iOS (Technical Spec §4, §7.4;
// Sky_App_Workflow.md J-03 block-start, J-06 midnight reset).
//
// This target cannot import the Sky module. App Group state is accessed directly
// via raw UserDefaults keys that mirror SharedDefaults.Key — the single source of
// truth lives in SharedDefaults.swift; update both if keys change.
//
// The midnight reset runs from two triggers here (`intervalDidStart` and, as a
// catch-up, `eventDidReachThreshold`) plus a third app-side in
// MidnightResetRecovery. All three share the `today_reset_token` day stamp and
// must stay idempotent against it.

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

final class SkyDeviceActivityMonitor: DeviceActivityMonitor {

    // MARK: - App Group access

    // Raw key strings mirror SharedDefaults.Key (Technical Spec §6.1).
    private enum Key {
        static let selection             = "selection"
        static let isCurrentlyBlocked    = "today_blocked"
        static let didVerifyToday        = "today_verified"
        static let didEmergencyUnlock    = "today_emergency_used"
        static let todayResetToken       = "today_reset_token"
        static let todayStateDay         = "today_state_day"
        static let shieldedAppTokens     = "shielded_app_tokens"
        // Diagnostic trail — mirrors ShieldAudit.key in the Sky module.
        static let shieldAuditLog        = "shield_audit_log"
        // Phase 12 — midnight-reset hand-off for StreakManager (mirrors SharedDefaults.Key)
        static let pendingMidnightReset  = "streak_pending_midnight_reset"
        static let yesterdayDidVerify    = "streak_yesterday_verified"
        static let yesterdayDidEmergency = "streak_yesterday_emergency"
        // Phase 15 — Pause + notification preference (mirrors SharedDefaults.Key)
        static let pauseStartedAt        = "pause_started_at"
        static let notifWarningEnabled   = "notif_warning_enabled"
        // Per-day notification caps (mirrors SharedDefaults.Key)
        static let notifWarningDay       = "notif_warning_day"
        static let notifBlockStartDay    = "notif_blockstart_day"
        /// JSON `[String: Int]` — highest ladder rung acted on today, keyed by
        /// "" (combined) or the app's base64 token (per-app).
        static let lastFiredRungs        = "last_fired_rungs"
    }

    /// Local-notification identifiers (event-driven; posted from this extension).
    private enum NotifID {
        static let blockStart = "sky.notif.blockStart"
        static let warning    = "sky.notif.warning"
    }

    // Event-name format mirrors DeviceActivityEvent.Name in DeviceActivityService.swift
    // (this target cannot import the Sky module). Update both if it changes.
    //
    // Names carry a trailing `_<rung>`: `sessionLimit_2`, `perAppWarn_<b64>_3`.
    // The rung is what lets a session end more than once a day — see `rung(from:)`.
    private enum EventName {
        static let sessionLimit     = "sessionLimit_"
        static let sessionWarning   = "sessionWarn_"
        static let perAppLimit      = "perApp_"
        static let perAppWarning    = "perAppWarn_"

        /// Pre-ladder names, still live on any device that has updated but not yet
        /// launched Sky (the re-arm that replaces them happens on first
        /// foreground). Kept until that window is safely behind us — dropping the
        /// legacy warning here would let it fall through to the shield branch and
        /// lock apps 30 minutes early.
        static let legacyDailyWarning = "dailyWarning"
        static let legacyDailyLimit   = "dailyLimitReached"
    }

    private static let suiteName = "group.com.shirolepranav.sky"

    /// Mirrors `AppBranding.appName` — extensions cannot import the Sky module.
    private static let appName = "Sky"

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    // MARK: - Threshold callback

    /// Called when any configured event threshold is reached. Two kinds of event
    /// arrive here (Phase 15):
    ///   • a *warning* event (30 minutes before the limit) → post a heads-up
    ///     notification only, no shield.
    ///   • a *limit* event (session exhausted) → apply the shield, mark the day
    ///     blocked, and post the block-start notification.
    /// While a 24-hour Pause is active, both are skipped so blocking is removed.
    ///
    /// Every event belongs to a rung of the session ladder (see
    /// DeviceActivityService). Rung 1 is the day's first block; rung 2 fires after
    /// the user has verified and burned another session's worth of usage, and so
    /// on. `lastFiredRungs` makes that monotonic, which is also what makes a
    /// replayed threshold — the kind iOS produces when monitoring re-arms — a
    /// no-op instead of a shield over apps the user just earned back.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let ud = appGroupDefaults

        // Roll the day over first if `intervalDidStart` was missed, so the day
        // stamp is current *before* any of today's state is written below.
        // Without this the reset lands later, on the first main-app foreground —
        // which is exactly the "Go outside to unlock" tap — and lifts a shield
        // that was applied minutes earlier, today.
        //
        // Deliberately above the pause check: the warning branch returns early,
        // and a paused day still has to roll over.
        performMidnightResetIfNeeded(ud)

        // Pause (Pro): suppress all blocking + notifications for 24h.
        if isPaused(ud) { return }

        // An emergency unlock buys the whole day — unlike a verification, which
        // buys one session. Re-locking someone who already told us they can't get
        // outside, and making them retype a reason to get back in, is punishment
        // rather than friction.
        if ud.bool(forKey: Key.didEmergencyUnlock) { return }

        let name = event.rawValue

        // A rung at or below the highest one already acted on today is a replay,
        // not new usage. iOS re-evaluates crossed thresholds whenever monitoring
        // re-arms with `includesPastActivity: true` (any limit or app-selection
        // edit), and without this guard that re-shields apps the user just
        // unlocked by walking outside.
        //
        // A name with no rung suffix is a pre-ladder registration that has not been
        // replaced yet; treat it as rung 1 rather than discarding it. Failing
        // closed (a block that may be redundant) is the right direction — failing
        // open would leave the user unblocked all day.
        let rung = Self.rung(from: name) ?? 1
        let ladderKey = Self.ladderKey(forEvent: name)
        guard rung > lastFiredRung(ladderKey, in: ud) else { return }

        // Warning events carry a distinct name prefix; they never shield, and they
        // must not advance the rung — the limit event for the same rung still has
        // to get through.
        if name.hasPrefix(EventName.sessionWarning)
            || name.hasPrefix(EventName.perAppWarning)
            || name == EventName.legacyDailyWarning {
            guard ud.object(forKey: Key.notifWarningEnabled) as? Bool ?? true else { return }
            // Nothing to warn about once the apps are already shut — this fires
            // when iOS replays a crossed threshold after the block landed.
            guard !ud.bool(forKey: Key.isCurrentlyBlocked) else {
                auditNotification("suppressed", source: "notif.warning", in: ud)
                return
            }
            postNotificationOncePerDay(
                id: NotifID.warning,
                dayKey: Key.notifWarningDay,
                source: "notif.warning",
                title: "30 minutes left",
                body: "Your apps pause soon. A good time to head outside ☁️",
                in: ud
            )
            return
        }

        let store = ManagedSettingsStore()

        if let token = Self.applicationToken(fromPerAppLimitEvent: name) {
            // Per-app mode: shield ONLY the app that exhausted its own budget.
            // Shielding the whole selection here would defeat the feature — one
            // app hitting 15 minutes would lock an app budgeted for 4 hours.
            //
            // Union with what is already shielded so apps blocked by their own
            // earlier events stay blocked. Categories carry no per-app budget
            // (makePerAppEvents only emits events for individual app tokens), so
            // they are deliberately left untouched.
            var shielded = store.shield.applications ?? []
            shielded.insert(token)
            store.shield.applications = shielded
            persistShieldedTokens(shielded, in: ud)
            auditShield("applied", source: "monitor.threshold", appCount: shielded.count, in: ud)
        } else {
            // Combined mode: one budget across everything in the selection.
            guard let data = ud.data(forKey: Key.selection),
                  let selection = try? JSONDecoder().decode(
                      FamilyActivitySelection.self, from: data)
            else { return }

            store.shield.applications = selection.applicationTokens
            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
            }
            persistShieldedTokens(selection.applicationTokens, in: ud)
            auditShield(
                "applied",
                source: "monitor.threshold",
                appCount: selection.applicationTokens.count,
                in: ud
            )
        }

        // The session that just ended is spent. Recording it here — after the
        // shield lands, not before — means a crash mid-callback retries rather
        // than silently skipping a block.
        setLastFiredRung(rung, for: ladderKey, in: ud)

        ud.set(true, forKey: Key.isCurrentlyBlocked)
        // A new session's block gets its own notification, so re-open the daily
        // cap. The cap exists to swallow *replays*, which the rung guard above has
        // already filtered out by the time we reach here.
        ud.removeObject(forKey: Key.notifBlockStartDay)
        ud.removeObject(forKey: Key.notifWarningDay)
        // Marks the block as belonging to *today*, so a late midnight reset in the
        // main app knows not to undo it (MidnightResetRecovery).
        ud.set(Self.dayStamp(for: Date()), forKey: Key.todayStateDay)

        // Block-start notification is always on (PRD §4.11) — but still capped at
        // one per day, so a replayed threshold can't announce the same block twice.
        postNotificationOncePerDay(
            id: NotifID.blockStart,
            dayKey: Key.notifBlockStartDay,
            source: "notif.blockStart",
            title: "Time's up",
            body: "Selected apps are blocked. Open \(Self.appName) to unlock them.",
            in: ud
        )
    }

    // MARK: - Helpers

    /// Recovers the app token embedded in a per-app limit event name, or nil when
    /// this isn't a per-app limit event (combined mode, or a warning).
    ///
    /// Mirrors `DeviceActivityEvent.Name.applicationToken(fromPerAppLimit:)` in
    /// DeviceActivityService.swift — this target cannot import the Sky module, so
    /// the two must be kept in sync. The app-side copy carries the unit tests.
    private static func applicationToken(fromPerAppLimitEvent name: String) -> ApplicationToken? {
        guard name.hasPrefix(EventName.perAppLimit) else { return nil }
        guard let encoded = base64Body(ofPerAppEvent: name),
              let data = Data(base64Encoded: encoded),
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data)
        else { return nil }
        return token
    }

    /// The base64 token portion of a per-app event name, with the `<prefix>_` and
    /// the trailing `_<rung>` stripped. Splitting at the *last* underscore is safe
    /// because base64 (`A–Z a–z 0–9 + / =`) contains none — which also means a body
    /// with no underscore at all is a pre-ladder name that is already just the
    /// token, so it is returned whole rather than rejected.
    private static func base64Body(ofPerAppEvent name: String) -> String? {
        guard let underscore = name.firstIndex(of: "_") else { return nil }
        let body = name[name.index(after: underscore)...]
        guard let separator = body.lastIndex(of: "_") else { return String(body) }
        return String(body[body.startIndex..<separator])
    }

    // MARK: - Session ladder

    /// The rung index encoded in an event name, or nil if it carries none.
    /// Mirrors `DeviceActivityEvent.Name.rung(from:)`.
    private static func rung(from name: String) -> Int? {
        guard let separator = name.lastIndex(of: "_") else { return nil }
        return Int(name[name.index(after: separator)...])
    }

    /// Which ladder an event belongs to: `""` for the combined ladder, or the
    /// app's base64 token in per-app mode, where each app climbs its own.
    private static func ladderKey(forEvent name: String) -> String {
        guard name.hasPrefix(EventName.perAppLimit) || name.hasPrefix(EventName.perAppWarning)
        else { return "" }
        return base64Body(ofPerAppEvent: name) ?? ""
    }

    private func lastFiredRungs(in ud: UserDefaults) -> [String: Int] {
        guard let data = ud.data(forKey: Key.lastFiredRungs),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded
    }

    private func lastFiredRung(_ key: String, in ud: UserDefaults) -> Int {
        lastFiredRungs(in: ud)[key] ?? 0
    }

    private func setLastFiredRung(_ rung: Int, for key: String, in ud: UserDefaults) {
        var rungs = lastFiredRungs(in: ud)
        rungs[key] = max(rungs[key] ?? 0, rung)
        guard let data = try? JSONEncoder().encode(rungs) else { return }
        ud.set(data, forKey: Key.lastFiredRungs)
    }

    /// Records the exact token set now shielded, so `ShieldService.reconcile` in
    /// the main app can restore it without guessing. In per-app mode that set is
    /// a subset of the selection, and re-shielding the whole selection would lock
    /// apps that are still inside their own budget.
    private func persistShieldedTokens(_ tokens: Set<ApplicationToken>, in ud: UserDefaults) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        ud.set(data, forKey: Key.shieldedAppTokens)
    }

    /// Appends one line to the shield audit trail.
    ///
    /// ⚠️ Mirrors `ShieldAudit.record` in the Sky module, which this target cannot
    /// import — the `"<epoch>|<action>|<source>|<count>"` shape, the `|` separator
    /// and the 60-entry cap must match, or the app-side reader drops the line.
    ///
    /// Privacy: count and source only, never app names or tokens.
    private func auditShield(_ action: String, source: String, appCount: Int, in ud: UserDefaults) {
        let line = "\(Int(Date().timeIntervalSince1970))|\(action)|\(source)|\(appCount)"
        var lines = ud.stringArray(forKey: Key.shieldAuditLog) ?? []
        lines.append(line)
        if lines.count > 60 { lines.removeFirst(lines.count - 60) }
        ud.set(lines, forKey: Key.shieldAuditLog)
    }

    /// True while a 24-hour pause is still in effect.
    private func isPaused(_ ud: UserDefaults) -> Bool {
        guard let start = ud.object(forKey: Key.pauseStartedAt) as? Date else { return false }
        return Date().timeIntervalSince(start) < 24 * 60 * 60
    }

    /// Posts a notification at most once per local day, and records both outcomes
    /// in the audit trail.
    ///
    /// ⚠️ A `DeviceActivityEvent` threshold is documented as firing once per
    /// interval, but that is not the whole story: iOS re-evaluates *already
    /// crossed* thresholds whenever monitoring is re-armed with
    /// `includesPastActivity: true`, which happens on any limit edit or
    /// app-selection change (see DeviceActivityService.makeEvent). The replay
    /// arrives here indistinguishable from real usage, and without this guard it
    /// posts "30 minutes left" and "Time's up" at an arbitrary hour on a day the
    /// user never opened the apps. The stable notification identifier doesn't
    /// help — a replacement still buzzes the phone.
    ///
    /// The day stamps are cleared by `performMidnightResetIfNeeded`, so the first
    /// genuine event of each new day always gets through.
    private func postNotificationOncePerDay(
        id: String,
        dayKey: String,
        source: String,
        title: String,
        body: String,
        in ud: UserDefaults
    ) {
        let today = Self.dayStamp(for: Date())
        guard ud.string(forKey: dayKey) != today else {
            auditNotification("suppressed", source: source, in: ud)
            return
        }
        ud.set(today, forKey: dayKey)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body           // never contains screen-time / app data (Tech Spec §14)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        auditNotification("notified", source: source, in: ud)
    }

    /// Notification entries share the shield audit trail so the debug menu shows
    /// one chronological story. `appCount` is unused here and always 0.
    private func auditNotification(_ action: String, source: String, in ud: UserDefaults) {
        auditShield(action, source: source, appCount: 0, in: ud)
    }

    // MARK: - Midnight reset

    /// Called at 00:00 local time (intervalStart of the repeating schedule), and
    /// again whenever monitoring is re-armed inside the interval.
    /// (Technical Spec §7.4, Sky_App_Workflow.md J-06; Phase 12 streak hand-off.)
    override func intervalDidStart(for activity: DeviceActivityName) {
        performMidnightResetIfNeeded(appGroupDefaults)
    }

    /// Captures yesterday's flags for StreakManager, clears all shields, and
    /// resets every per-day flag so the next day starts fresh.
    ///
    /// Callable from both `intervalDidStart` (the intended 00:00 trigger) and
    /// `eventDidReachThreshold` (the catch-up trigger). The catch-up call is what
    /// keeps the reset *ahead* of today's state rather than behind it: when the
    /// 00:00 callback is missed, the day's first threshold event rolls the day
    /// over before writing `today_blocked`. Otherwise the reset falls to
    /// `MidnightResetRecovery` on the next main-app foreground — which is the tap
    /// on "Go outside to unlock" — and lifts a shield applied minutes earlier.
    ///
    /// No-ops unless the stored day stamp is behind today.
    private func performMidnightResetIfNeeded(_ ud: UserDefaults) {
        let today = Self.dayStamp(for: Date())
        let stored = ud.string(forKey: Key.todayResetToken) ?? ""

        // 0. Idempotence guard. MidnightResetRecovery performs this same reset
        //    app-side when this callback is missed. If it already ran for today,
        //    repeating the hand-off would snapshot the *already-cleared* flags as
        //    "yesterday" and StreakManager would zero a live streak.
        guard stored != today else { return }

        // Fresh install (or a wipe): adopt today without inventing a yesterday,
        // mirroring MidnightResetRecovery.Outcome.adoptedFirstStamp. Handing off
        // flags that were never set would evaluate a day that did not happen.
        guard !stored.isEmpty else {
            ud.set(today, forKey: Key.todayResetToken)
            return
        }

        // A stamp *ahead* of today means the clock moved backwards, not that a day
        // has passed — adopt it and clear nothing, or winding a device back would
        // lift a live shield. `yyyy-MM-dd` sorts chronologically, so a string
        // comparison is enough here; the app-side twin parses dates for the same
        // check (MidnightResetRecovery.Outcome.adoptedFutureStamp).
        guard stored <= today else {
            ud.set(today, forKey: Key.todayResetToken)
            return
        }

        // 1. Snapshot yesterday's flags BEFORE clearing — StreakManager reads
        //    these on the next main-app foreground (the extension runs in a separate
        //    process and can't call @MainActor code directly).
        let didVerifyYesterday    = ud.bool(forKey: Key.didVerifyToday)
        let didEmergencyYesterday = ud.bool(forKey: Key.didEmergencyUnlock)
        ud.set(didVerifyYesterday,    forKey: Key.yesterdayDidVerify)
        ud.set(didEmergencyYesterday, forKey: Key.yesterdayDidEmergency)
        ud.set(true,                  forKey: Key.pendingMidnightReset)

        // 2. Clear shields and today's state flags.
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        ud.removeObject(forKey: Key.shieldedAppTokens)
        auditShield("cleared", source: "monitor.intervalStart", appCount: 0, in: ud)

        ud.set(false, forKey: Key.isCurrentlyBlocked)
        ud.set(false, forKey: Key.didVerifyToday)
        ud.set(false, forKey: Key.didEmergencyUnlock)

        // Re-open the notification budget. A stamp holding yesterday would already
        // fail the equality check, so this is belt-and-braces — but it keeps
        // "everything per-day is cleared here" true by inspection.
        ud.removeObject(forKey: Key.notifWarningDay)
        ud.removeObject(forKey: Key.notifBlockStartDay)

        // Back to the bottom of the session ladder. Without this the new day's
        // rung 1 would be below yesterday's high-water mark and be discarded as a
        // replay, and the user would never be blocked again.
        ud.removeObject(forKey: Key.lastFiredRungs)

        // The cleared flags now describe today, not yesterday.
        ud.set(today, forKey: Key.todayStateDay)
        ud.set(today, forKey: Key.todayResetToken)
    }

    /// `YYYY-MM-DD` in **local** time, matching the interval start of the
    /// DeviceActivitySchedule.
    ///
    /// Mirrors `MidnightResetRecovery.dayStamp(for:timeZone:)` in the Sky module,
    /// which this target cannot import — both must produce identical strings.
    /// (Previously this used `ISO8601DateFormatter`, which formats in UTC and so
    /// stamped the wrong calendar day for time zones far from GMT. Nothing read
    /// the value then, so changing the format breaks no existing consumer.)
    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Interval end

    /// No-op in v1.0 — the midnight reset is handled entirely by `intervalDidStart`
    /// of the next day's schedule interval.
    override func intervalDidEnd(for activity: DeviceActivityName) {}
}
