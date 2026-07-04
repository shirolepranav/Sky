// SkyDeviceActivityMonitor.swift
// Principal class for the DeviceActivityMonitor extension target.
// Receives threshold and interval callbacks from iOS (Technical Spec §4, §7.4;
// Sky_App_Workflow.md J-03 block-start, J-06 midnight reset).
//
// This target cannot import the Sky module. App Group state is accessed directly
// via raw UserDefaults keys that mirror SharedDefaults.Key — the single source of
// truth lives in SharedDefaults.swift; update both if keys change.

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
        // Phase 12 — midnight-reset hand-off for StreakManager (mirrors SharedDefaults.Key)
        static let pendingMidnightReset  = "streak_pending_midnight_reset"
        static let yesterdayDidVerify    = "streak_yesterday_verified"
        static let yesterdayDidEmergency = "streak_yesterday_emergency"
        // Phase 15 — Pause + notification preference (mirrors SharedDefaults.Key)
        static let pauseStartedAt        = "pause_started_at"
        static let notifWarningEnabled   = "notif_warning_enabled"
    }

    /// Local-notification identifiers (event-driven; posted from this extension).
    private enum NotifID {
        static let blockStart = "sky.notif.blockStart"
        static let warning    = "sky.notif.warning"
    }

    private static let suiteName = "group.com.shirolepranav.sky"

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    // MARK: - Threshold callback

    /// Called when any configured event threshold is reached. Two kinds of event
    /// arrive here (Phase 15):
    ///   • a *warning* event (30 minutes before the limit) → post a heads-up
    ///     notification only, no shield.
    ///   • a *limit* event (budget exhausted) → apply the shield, mark the day
    ///     blocked, and post the block-start notification.
    /// While a 24-hour Pause is active, both are skipped so blocking is removed.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let ud = appGroupDefaults

        // Pause (Pro): suppress all blocking + notifications for 24h.
        if isPaused(ud) { return }

        // Warning events carry a distinct name prefix; they never shield.
        let name = event.rawValue
        if name == "dailyWarning" || name.hasPrefix("perAppWarn_") {
            if ud.object(forKey: Key.notifWarningEnabled) as? Bool ?? true {
                postNotification(
                    id: NotifID.warning,
                    title: "30 minutes left",
                    body: "Your apps pause soon. A good time to head outside ☁️"
                )
            }
            return
        }

        // Limit reached — shield the selected apps.
        guard let data = ud.data(forKey: Key.selection),
              let selection = try? JSONDecoder().decode(
                  FamilyActivitySelection.self, from: data)
        else { return }

        let store = ManagedSettingsStore()
        store.shield.applications = selection.applicationTokens
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }

        ud.set(true, forKey: Key.isCurrentlyBlocked)

        // Block-start notification is always on (PRD §4.11).
        postNotification(
            id: NotifID.blockStart,
            title: "Time's up",
            body: "Selected apps are blocked. Go outside to unlock them."
        )
    }

    // MARK: - Helpers

    /// True while a 24-hour pause is still in effect.
    private func isPaused(_ ud: UserDefaults) -> Bool {
        guard let start = ud.object(forKey: Key.pauseStartedAt) as? Date else { return false }
        return Date().timeIntervalSince(start) < 24 * 60 * 60
    }

    /// Posts an immediate local notification. Bodies never contain screen-time or
    /// app-name data (privacy commitment, Technical Spec §14).
    private func postNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Midnight reset

    /// Called at 00:00 local time (intervalStart of the repeating schedule).
    /// Captures yesterday's flags for StreakManager, clears all shields, and resets
    /// every per-day flag so the next day starts fresh
    /// (Technical Spec §7.4, Sky_App_Workflow.md J-06; Phase 12 streak hand-off).
    override func intervalDidStart(for activity: DeviceActivityName) {
        let ud = appGroupDefaults

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

        ud.set(false, forKey: Key.isCurrentlyBlocked)
        ud.set(false, forKey: Key.didVerifyToday)
        ud.set(false, forKey: Key.didEmergencyUnlock)

        // todayResetToken: YYYY-MM-DD in local time, invalidates stale cached state.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        ud.set(formatter.string(from: Date()), forKey: Key.todayResetToken)
    }

    // MARK: - Interval end

    /// No-op in v1.0 — the midnight reset is handled entirely by `intervalDidStart`
    /// of the next day's schedule interval.
    override func intervalDidEnd(for activity: DeviceActivityName) {}
}
