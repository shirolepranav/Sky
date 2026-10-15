// DeviceActivityServiceTests.swift
// Daily-lock scheduling (DAILY_LOCK_PLAN.md Phase B).
//
// DeviceActivityCenter requires the Family Controls entitlement at runtime, so
// tests inject MockDeviceActivityCenter. Schedules are plain value types.

import XCTest
import DeviceActivity
import FamilyControls
@testable import Sky

// MARK: - Mock

private struct MockStartError: Error {}

private final class MockDeviceActivityCenter: DeviceActivityScheduling {
    var schedules: [DeviceActivityName: DeviceActivitySchedule] = [:]
    var eventCounts: [DeviceActivityName: Int] = [:]
    var startCallCount = 0
    var stopCallCount  = 0
    var activities: [DeviceActivityName] = []
    var startError: Error?

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        startCallCount += 1
        if let startError { throw startError }
        schedules[activity] = schedule
        eventCounts[activity] = events.count
        if !activities.contains(activity) { activities.append(activity) }
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stopCallCount += 1
        self.activities = []
    }
}

@MainActor
final class DeviceActivityServiceTests: XCTestCase {

    private var suite = ""
    private var store: SharedDefaults!

    override func setUp() {
        super.setUp()
        suite = "sky.tests.\(UUID().uuidString)"
        store = SharedDefaults(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    // MARK: Schedules

    func testDailyScheduleRunsMidnightToMidnight() {
        let s = DeviceActivityService.makeDailySchedule()
        XCTAssertEqual(s.intervalStart.hour, 0)
        XCTAssertEqual(s.intervalStart.minute, 0)
        XCTAssertEqual(s.intervalEnd.hour, 23)
        XCTAssertEqual(s.intervalEnd.minute, 59)
        XCTAssertTrue(s.repeats)
    }

    func testLockScheduleStartsAtLockTime() {
        let s = DeviceActivityService.makeLockSchedule(lockTimeMinutes: 9 * 60 + 30)
        XCTAssertEqual(s.intervalStart.hour, 9)
        XCTAssertEqual(s.intervalStart.minute, 30)
        XCTAssertEqual(s.intervalEnd.hour, 23)
        XCTAssertTrue(s.repeats)
    }

    /// DeviceActivity rejects intervals under 15 minutes.
    func testLockScheduleIsClampedToALegalInterval() {
        let s = DeviceActivityService.makeLockSchedule(lockTimeMinutes: 23 * 60 + 55)
        XCTAssertEqual(s.intervalStart.hour, 23)
        XCTAssertEqual(s.intervalStart.minute, 0)
    }

    // MARK: Registration

    /// The whole point of the pivot: no usage thresholds at all.
    func testRegistersBothSchedulesWithNoEvents() throws {
        store.selection = FamilyActivitySelection()
        let mock = MockDeviceActivityCenter()
        try DeviceActivityService(center: mock, store: store).startMonitoring()

        XCTAssertEqual(Set(mock.activities), [.daily, .lock])
        XCTAssertEqual(mock.eventCounts[.daily], 0)
        XCTAssertEqual(mock.eventCounts[.lock], 0)
        XCTAssertEqual(mock.schedules[.lock]?.intervalStart.hour, 9, "default lock is 9 AM")
    }

    func testNoSelectionStopsMonitoring() throws {
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)
        try service.startMonitoring()
        XCTAssertEqual(mock.startCallCount, 0)
        XCTAssertFalse(service.isMonitoring)
    }

    func testRepeatedStartWithUnchangedConfigDoesNotReArm() throws {
        store.selection = FamilyActivitySelection()
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        let starts = mock.startCallCount
        try service.startMonitoring()
        try DeviceActivityService(center: mock, store: store).startMonitoring()

        XCTAssertEqual(mock.startCallCount, starts)
        XCTAssertTrue(service.isMonitoring)
    }

    func testChangingLockTimeReArms() throws {
        store.selection = FamilyActivitySelection()
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)
        try service.startMonitoring()

        store.lockTimeMinutes = 7 * 60
        try service.startMonitoring()

        XCTAssertEqual(mock.schedules[.lock]?.intervalStart.hour, 7)
    }

    func testFailedStartLeavesNoFingerprint() {
        store.selection = FamilyActivitySelection()
        let mock = MockDeviceActivityCenter()
        mock.startError = MockStartError()
        let service = DeviceActivityService(center: mock, store: store)

        XCTAssertThrowsError(try service.startMonitoring())
        XCTAssertNil(store.monitoringConfigFingerprint)
        XCTAssertFalse(service.isMonitoring)
    }

    func testStopMonitoringCallsCenter() {
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)
        service.stopMonitoring()
        XCTAssertGreaterThanOrEqual(mock.stopCallCount, 1)
        XCTAssertFalse(service.isMonitoring)
    }

    // MARK: Arm stamps

    func testRegistrationStampsArmedAt() throws {
        store.selection = FamilyActivitySelection()
        let now = at(8)
        try DeviceActivityService(center: MockDeviceActivityCenter(), store: store)
            .startMonitoring(now: now)
        XCTAssertEqual(store.lockArmedAt, now)
    }

    /// Finishing setup at 10 AM with a 9 AM lock must not lock the user out on the spot.
    func testFirstArmAfterLockTimeWaivesToday() throws {
        store.selection = FamilyActivitySelection()
        let now = at(10)
        try DeviceActivityService(center: MockDeviceActivityCenter(), store: store)
            .startMonitoring(now: now)
        XCTAssertEqual(store.lockSkipDay, MidnightResetRecovery.dayStamp(for: now))
    }

    func testFirstArmBeforeLockTimeKeepsToday() throws {
        store.selection = FamilyActivitySelection()
        try DeviceActivityService(center: MockDeviceActivityCenter(), store: store)
            .startMonitoring(now: at(7))
        XCTAssertEqual(store.lockSkipDay, "")
    }

    /// Moving the lock to an hour already past must not be a way to dodge the day.
    func testLaterReArmDoesNotWaiveToday() throws {
        store.selection = FamilyActivitySelection()
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)
        try service.startMonitoring(now: at(7))

        store.lockTimeMinutes = 8 * 60
        try service.startMonitoring(now: at(10))

        XCTAssertEqual(store.lockSkipDay, "")
    }

    // MARK: Fingerprint

    func testFingerprintIsStable() {
        let a = DeviceActivityService.configFingerprint(selectionData: Data([1]), lockTimeMinutes: 540, osMajorVersion: 26)
        let b = DeviceActivityService.configFingerprint(selectionData: Data([1]), lockTimeMinutes: 540, osMajorVersion: 26)
        XCTAssertEqual(a, b)
    }

    func testFingerprintChangesWithLockTimeSelectionAndOS() {
        let base = DeviceActivityService.configFingerprint(selectionData: Data([1]), lockTimeMinutes: 540, osMajorVersion: 26)
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(selectionData: Data([1]), lockTimeMinutes: 600, osMajorVersion: 26))
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(selectionData: Data([2]), lockTimeMinutes: 540, osMajorVersion: 26))
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(selectionData: Data([1]), lockTimeMinutes: 540, osMajorVersion: 27))
    }
}
