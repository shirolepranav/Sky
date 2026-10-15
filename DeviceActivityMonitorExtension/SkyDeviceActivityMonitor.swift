// SkyDeviceActivityMonitor.swift
// Principal class for the DeviceActivityMonitor extension target.
// Receives the two daily interval-start callbacks registered by
// DeviceActivityService (DAILY_LOCK_PLAN.md Phase B; Technical Spec §7.4;
// Sky_App_Workflow.md J-03 lock, J-06 midnight rollover).
//
//   • `daily` at 00:00 → the midnight rollover (streak hand-off, per-day flags).
//     It never touches the shield: an unverified day stays locked.
//   • `lock` at the user's lock time → shield the selection unless the user
//     already went outside today.
//
// No usage thresholds — see DeviceActivityService's header for why.
//
// This target cannot import the Sky module. App Group state is accessed directly
// via raw UserDefaults keys that mirror SharedDefaults.Key — the single source of
// truth lives in SharedDefaults.swift; update both if keys change.
//
// The midnight rollover runs from two triggers here (both interval starts) plus a
// third app-side in MidnightResetRecovery. All three share the
// `today_reset_token` day stamp and must stay idempotent against it.

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
        static let lockWeekdays          = "lock_weekdays"
        static let lockArmedAt           = "lock_armed_at"
        static let lockSkipDay           = "lock_skip_day"
        static let isCurrentlyBlocked    = "today_blocked"
        static let didVerifyToday        = "today_verified"
        static let didEmergencyUnlock    = "today_emergency_used"
        static let todayResetToken       = "today_reset_token"
        static let todayStateDay         = "today_state_day"
        // Diagnostic trail — mirrors ShieldAudit.key in the Sky module.
        static let shieldAuditLog        = "shield_audit_log"
        // Phase 12 — midnight-reset hand-off for StreakManager (mirrors SharedDefaults.Key)
        static let pendingMidnightReset  = "streak_pending_midnight_reset"
        static let yesterdayDidVerify    = "streak_yesterday_verified"
        static let yesterdayDidEmergency = "streak_yesterday_emergency"
        // Phase 15 — Pause (mirrors SharedDefaults.Key)
        static let pauseStartedAt        = "pause_started_at"
    }

    /// Mirror `DeviceActivityName.daily` / `.lock` in DeviceActivityService.
    private enum Activity {
        static let lock = DeviceActivityName("lock")
    }

    /// Mirrors `LockPolicy.armGraceSeconds`.
    private static let armGraceSeconds: TimeInterval = 60

    private static let suiteName = "group.com.shirolepranav.sky"

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    // MARK: - Interval start

    override func intervalDidStart(for activity: DeviceActivityName) {
        let ud = appGroupDefaults
        // Always roll the day over first, so the lock below reads today's flags and
        // stamps today's state against a current day stamp.
        performMidnightResetIfNeeded(ud)
        if activity == Activity.lock { applyLock(ud) }
    }

    /// No-op — the interval end at 23:59 has no meaning in the daily-lock model.
    override func intervalDidEnd(for activity: DeviceActivityName) {}

    // MARK: - Lock

    /// Shields the whole selection, unless `LockPolicy.shouldLock` says not to.
    ///
    /// ⚠️ The skip conditions mirror `LockPolicy.shouldLock` in the Sky module, plus
    /// the arm grace window — a start right after registration is iOS announcing
    /// the schedule, and the app-side catch-up handles that case.
    private func applyLock(_ ud: UserDefaults) {
        let now = Date()
        let weekdays = Set(ud.array(forKey: Key.lockWeekdays) as? [Int] ?? Array(1...7))
        let armedAt = ud.object(forKey: Key.lockArmedAt) as? Date

        let skip = isPaused(ud)
            || ud.bool(forKey: Key.didVerifyToday)
            || ud.bool(forKey: Key.didEmergencyUnlock)
            || !weekdays.contains(Calendar.current.component(.weekday, from: now))
            || ud.string(forKey: Key.lockSkipDay) == Self.dayStamp(for: now)
            || armedAt.map { now.timeIntervalSince($0) < Self.armGraceSeconds } ?? false
        if skip {
            audit("skipped", source: "monitor.lock", appCount: 0, in: ud)
            return
        }

        guard let data = ud.data(forKey: Key.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        let store = ManagedSettingsStore()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        audit("applied", source: "monitor.lock", appCount: selection.applicationTokens.count, in: ud)

        ud.set(true, forKey: Key.isCurrentlyBlocked)
        ud.set(Self.dayStamp(for: now), forKey: Key.todayStateDay)

        postLockNotification(ud)
    }

    /// One a day by construction — the lock interval starts once a day, and the
    /// re-arm replay is filtered out by the grace check above.
    private func postLockNotification(_ ud: UserDefaults) {
        let content = UNMutableNotificationContent()
        content.title = "Apps are paused"
        content.body = "Nimbus is waiting outside for you ☁ A short walk unlocks them for the day."
        content.sound = .default
        // Opens the verification flow when tapped (SkyNotificationRouter).
        content.userInfo = ["sky_deep_link": "verify"]
        let request = UNNotificationRequest(identifier: "sky.notif.lock", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        audit("notified", source: "notif.lock", appCount: 0, in: ud)
    }

    // MARK: - Helpers

    /// Appends one line to the shield audit trail.
    ///
    /// ⚠️ Mirrors `ShieldAudit.record` in the Sky module, which this target cannot
    /// import — the `"<epoch>|<action>|<source>|<count>"` shape, the `|` separator
    /// and the 60-entry cap must match, or the app-side reader drops the line.
    ///
    /// Privacy: count and source only, never app names or tokens.
    private func audit(_ action: String, source: String, appCount: Int, in ud: UserDefaults) {
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

    // MARK: - Midnight rollover

    /// Captures yesterday's flags for StreakManager and resets the per-day flags.
    /// (Technical Spec §7.4, Sky_App_Workflow.md J-06; Phase 12 streak hand-off.)
    ///
    /// ⚠️ Never touches the shield or `today_blocked` — an unverified day stays
    /// locked until the user goes outside.
    ///
    /// No-ops unless the stored day stamp is behind today. Mirrors
    /// `MidnightResetRecovery.runIfNeeded`.
    private func performMidnightResetIfNeeded(_ ud: UserDefaults) {
        let today = Self.dayStamp(for: Date())
        let stored = ud.string(forKey: Key.todayResetToken) ?? ""

        // Idempotence guard. MidnightResetRecovery performs this same reset
        // app-side when this callback is missed. If it already ran for today,
        // repeating the hand-off would snapshot the *already-cleared* flags as
        // "yesterday" and StreakManager would zero a live streak.
        guard stored != today else { return }

        // Fresh install (or a wipe): adopt today without inventing a yesterday.
        guard !stored.isEmpty else {
            ud.set(today, forKey: Key.todayResetToken)
            return
        }

        // A stamp *ahead* of today means the clock moved backwards — adopt it and
        // clear nothing. `yyyy-MM-dd` sorts chronologically.
        guard stored <= today else {
            ud.set(today, forKey: Key.todayResetToken)
            return
        }

        // State already written today (mirrors `.stampOnly`): advance the stamp only.
        guard ud.string(forKey: Key.todayStateDay) != today else {
            ud.set(today, forKey: Key.todayResetToken)
            return
        }

        // Snapshot yesterday's flags BEFORE clearing — StreakManager reads these on
        // the next main-app foreground.
        ud.set(ud.bool(forKey: Key.didVerifyToday),     forKey: Key.yesterdayDidVerify)
        ud.set(ud.bool(forKey: Key.didEmergencyUnlock), forKey: Key.yesterdayDidEmergency)
        ud.set(true,                                    forKey: Key.pendingMidnightReset)

        ud.set(false, forKey: Key.didVerifyToday)
        ud.set(false, forKey: Key.didEmergencyUnlock)

        ud.set(today, forKey: Key.todayStateDay)
        ud.set(today, forKey: Key.todayResetToken)
    }

    /// `YYYY-MM-DD` in **local** time.
    ///
    /// ⚠️ Mirrors `MidnightResetRecovery.dayStamp(for:timeZone:)` in the Sky module;
    /// both must produce byte-identical strings.
    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
