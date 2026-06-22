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

final class SkyDeviceActivityMonitor: DeviceActivityMonitor {

    // MARK: - App Group access

    // Raw key strings mirror SharedDefaults.Key (Technical Spec §6.1).
    private enum Key {
        static let selection          = "selection"
        static let isCurrentlyBlocked = "today_blocked"
        static let didVerifyToday     = "today_verified"
        static let didEmergencyUnlock = "today_emergency_used"
        static let todayResetToken    = "today_reset_token"
    }

    private static let suiteName = "group.com.shirolepranav.sky"

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    // MARK: - Threshold callback

    /// Called when any configured event threshold is reached (budget exhausted).
    /// Applies a shield to every app in the persisted selection and marks the
    /// day as blocked (Sky_App_Workflow.md §0.4 → `blocked` state).
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let ud = appGroupDefaults

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
    }

    // MARK: - Midnight reset

    /// Called at 00:00 local time (intervalStart of the repeating schedule).
    /// Clears all shields and resets every per-day flag so the next day starts
    /// fresh (Technical Spec §7.4, Sky_App_Workflow.md J-06).
    override func intervalDidStart(for activity: DeviceActivityName) {
        let ud = appGroupDefaults
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
