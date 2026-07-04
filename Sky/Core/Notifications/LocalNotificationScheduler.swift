// LocalNotificationScheduler.swift
// Local-only notification scheduling — the morning reminder and the 10 PM streak
// warning. NEVER registers for remote push / APNs (privacy commitment, Tech Spec
// §14; PRD §4.11). All notifications are scheduled by the phone.
//
// Split of responsibility:
//   • Calendar-triggered notifications (fixed clock times) are scheduled HERE.
//   • Event-driven notifications (block-start, 30-minute warning) fire from the
//     DeviceActivityMonitor extension when a usage threshold is reached, because
//     the block time is dynamic and only the extension observes it.
//
// The UNUserNotificationCenter dependency is protocol-wrapped so unit tests can
// inject a fake — mirrors the DeviceActivityScheduling pattern in
// DeviceActivityService.
// Roadmap Phase 15; Sky_App_Workflow.md S-SET-04 / S-PERM-03.

import Foundation
import UserNotifications

// MARK: - Testability protocol

protocol UserNotificationScheduling {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePending(identifiers: [String])
    func pending() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: UserNotificationScheduling {
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
    func removePending(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func pending() async -> [UNNotificationRequest] {
        await pendingNotificationRequests()
    }
}

// MARK: - Scheduler

@MainActor
final class LocalNotificationScheduler: ObservableObject {

    /// Stable request identifiers so reschedules replace rather than duplicate.
    enum Identifier {
        static let morning       = "sky.notif.morning"
        static let streakWarning = "sky.notif.streakWarning"
    }

    private let center: UserNotificationScheduling

    init(center: UserNotificationScheduling = UNUserNotificationCenter.current()) {
        self.center = center
    }

    // MARK: Authorization

    /// Requests alert + sound authorization only — never `.badge`-linked remote
    /// push and never APNs registration.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.currentAuthorizationStatus()
    }

    // MARK: Reschedule

    /// Remove and re-add the calendar-triggered notifications to match current
    /// preferences. Call on foreground, after verification, and whenever a
    /// notification toggle changes.
    ///
    /// - Parameters:
    ///   - store: source of the enabled flags.
    ///   - isPro: gates the streak warning (Pro-only).
    ///   - streakAtRisk: true when the user has an active streak and hasn't yet
    ///     verified today — only then is tonight's 10 PM warning meaningful.
    func rescheduleAll(store: SharedDefaults = SharedDefaults(), isPro: Bool, streakAtRisk: Bool) async {
        center.removePending(identifiers: [Identifier.morning, Identifier.streakWarning])

        if store.notifMorningEnabled {
            await addCalendar(
                id: Identifier.morning,
                hour: 8, minute: 30, repeats: true,
                title: "Good morning",
                body: "\(AppBranding.mascotName) is ready for today's outdoor break ☁️"
            )
        }

        if isPro && store.notifStreakEnabled && streakAtRisk {
            // Non-repeating: fires the next 10 PM. Re-armed each foreground while
            // the streak stays at risk; removed once the user verifies.
            await addCalendar(
                id: Identifier.streakWarning,
                hour: 22, minute: 0, repeats: false,
                title: "Streak at risk",
                body: "One outdoor verification keeps it alive."
            )
        }
    }

    // MARK: Helpers

    private func addCalendar(
        id: String, hour: Int, minute: Int, repeats: Bool,
        title: String, body: String
    ) async {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body           // never contains screen-time / app data (Tech Spec §14)
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
