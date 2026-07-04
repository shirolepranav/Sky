// LocalNotificationSchedulerTests.swift
// Phase 15 automated tests (Roadmap Phase 15 → Automated Tests). Uses a fake
// UNUserNotificationCenter (protocol-wrapped) to assert the morning reminder is
// scheduled, the streak warning is Pro-gated, and only LOCAL authorization is
// requested (no remote push / APNs).

import XCTest
import UserNotifications
@testable import Sky

// MARK: - Fake center

private final class FakeNotificationCenter: UserNotificationScheduling, @unchecked Sendable {
    var added: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var requestedOptions: UNAuthorizationOptions?
    var statusToReturn: UNAuthorizationStatus = .authorized

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        return true
    }
    func currentAuthorizationStatus() async -> UNAuthorizationStatus { statusToReturn }
    func add(_ request: UNNotificationRequest) async throws { added.append(request) }
    func removePending(identifiers: [String]) { removedIdentifiers.append(contentsOf: identifiers) }
    func pending() async -> [UNNotificationRequest] { added }
}

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {
    private let suiteName = "LocalNotificationSchedulerTests"
    private var defaults: UserDefaults!
    private var store: SharedDefaults!
    private var fake: FakeNotificationCenter!
    private var scheduler: LocalNotificationScheduler!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedDefaults(defaults: defaults)
        fake = FakeNotificationCenter()
        scheduler = LocalNotificationScheduler(center: fake)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMorningReminderScheduled() async {
        await scheduler.rescheduleAll(store: store, isPro: false, streakAtRisk: false)

        let morning = fake.added.first { $0.identifier == LocalNotificationScheduler.Identifier.morning }
        XCTAssertNotNil(morning, "morning reminder should be scheduled when enabled")

        let trigger = morning?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 8)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
        XCTAssertEqual(trigger?.repeats, true)
    }

    func testMorningReminderRemovedWhenDisabled() async {
        store.notifMorningEnabled = false
        await scheduler.rescheduleAll(store: store, isPro: false, streakAtRisk: false)

        XCTAssertTrue(fake.removedIdentifiers.contains(LocalNotificationScheduler.Identifier.morning))
        XCTAssertNil(fake.added.first { $0.identifier == LocalNotificationScheduler.Identifier.morning })
    }

    func testStreakWarningOnlyForProUsers() async {
        // Free user, streak at risk → no streak warning.
        await scheduler.rescheduleAll(store: store, isPro: false, streakAtRisk: true)
        XCTAssertNil(fake.added.first { $0.identifier == LocalNotificationScheduler.Identifier.streakWarning })

        // Pro user, streak at risk → warning scheduled.
        fake.added.removeAll()
        await scheduler.rescheduleAll(store: store, isPro: true, streakAtRisk: true)
        XCTAssertNotNil(fake.added.first { $0.identifier == LocalNotificationScheduler.Identifier.streakWarning })
    }

    func testStreakWarningSuppressedWhenNotAtRisk() async {
        await scheduler.rescheduleAll(store: store, isPro: true, streakAtRisk: false)
        XCTAssertNil(fake.added.first { $0.identifier == LocalNotificationScheduler.Identifier.streakWarning })
    }

    func testNoRemotePushRequested() async {
        _ = await scheduler.requestAuthorization()
        // Only local alert + sound — never .badge-driven remote push or provisional.
        XCTAssertEqual(fake.requestedOptions, [.alert, .sound])
    }
}
