// DeviceActivityServiceTests.swift
// Phase 5 automated tests (Roadmap Phase 5 → Automated Tests).
//
// DeviceActivityCenter requires the Family Controls entitlement at runtime, so
// tests inject MockDeviceActivityCenter. The schedule/event logic is tested via
// the pure static helpers makeSchedule() and makeEvents(), which need no mock at
// all — they return plain DeviceActivity value types.

import XCTest
import DeviceActivity
import FamilyControls
@testable import Sky

// MARK: - Mock

private struct MockStartError: Error {}

private final class MockDeviceActivityCenter: DeviceActivityScheduling {
    var capturedSchedule: DeviceActivitySchedule?
    var capturedEvents: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    var startCallCount = 0
    var stopCallCount  = 0

    /// Mirrors the real center: registrations persist until stopped, so the
    /// re-arm guard has something meaningful to consult.
    var activities: [DeviceActivityName] = []

    /// When set, `startMonitoring` throws instead of registering.
    var startError: Error?

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        startCallCount += 1
        if let startError { throw startError }
        capturedSchedule = schedule
        capturedEvents   = events
        if !activities.contains(activity) { activities.append(activity) }
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stopCallCount += 1
        self.activities = []
    }
}

// MARK: - Tests

// `DeviceActivityService` (and its static helpers) are @MainActor, so the test
// case must be too — otherwise every call is a cross-actor hop the compiler
// rejects under Swift 6 isolation checking.
@MainActor
final class DeviceActivityServiceTests: XCTestCase {

    // MARK: Schedule

    /// The daily schedule must run midnight-to-midnight and repeat every day
    /// (Technical Spec §7.3). Tested via the pure helper — no mock or entitlement needed.
    func testScheduleBuildsCorrectly() {
        let schedule = DeviceActivityService.makeSchedule()

        XCTAssertEqual(schedule.intervalStart.hour,   0)
        XCTAssertEqual(schedule.intervalStart.minute, 0)
        XCTAssertEqual(schedule.intervalEnd.hour,   23)
        XCTAssertEqual(schedule.intervalEnd.minute, 59)
        XCTAssertTrue(schedule.repeats)
    }

    // MARK: Events — combined mode

    /// Combined mode with a known limit must produce a `.dailyLimitReached` event
    /// at the limit plus a paired `.dailyWarning` event 30 minutes earlier.
    func testEventThresholdMatchesCombinedLimit() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 3600,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertEqual(events.count, 2, "limit event + 30-min warning event")
        XCTAssertEqual(events[.dailyLimitReached]?.threshold.second, 3600)
        XCTAssertEqual(events[.dailyWarning]?.threshold.second, 1800, "warning fires 30 min before")
    }

    /// A limit ≤ 30 minutes leaves no room for a distinct earlier warning, so only
    /// the limit event is emitted.
    func testShortLimitEmitsNoWarning() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 20 * 60,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[.dailyLimitReached])
        XCTAssertNil(events[.dailyWarning])
    }

    /// The warning-threshold helper subtracts 30 minutes, or returns nil when the
    /// limit is 30 minutes or less.
    func testWarningThresholdSeconds() {
        XCTAssertEqual(DeviceActivityService.warningThresholdSeconds(for: 7200), 5400)
        XCTAssertEqual(DeviceActivityService.warningThresholdSeconds(for: 1801), 1)
        XCTAssertNil(DeviceActivityService.warningThresholdSeconds(for: 1800))
        XCTAssertNil(DeviceActivityService.warningThresholdSeconds(for: 600))
    }

    // MARK: Events — per-app mode

    /// Per-app mode must NOT emit a combined event.
    ///
    /// Note: `ApplicationToken` is an opaque system type that cannot be
    /// instantiated in unit tests without a real Family Controls session.
    /// This test therefore exercises the per-app code path with nil
    /// `perAppLimitsData`, verifying zero per-app events are produced and
    /// that the combined `.dailyLimitReached` event is absent.
    /// Non-zero per-app event counts are verified during on-device testing
    /// (Roadmap Phase 5 manual tests).
    func testPerAppModeCreatesOneEventPerApp() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "perApp",
            combinedLimitSeconds: 7200,  // irrelevant in per-app mode
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertFalse(
            events.keys.contains(.dailyLimitReached),
            "per-app mode must not emit a combined dailyLimitReached event"
        )
        XCTAssertTrue(
            events.isEmpty,
            "nil perAppLimitsData should produce no per-app events"
        )
    }

    // MARK: Stop monitoring

    /// `stopMonitoring()` must delegate to the underlying center exactly once.
    func testStopMonitoringCallsCenter() {
        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(
            center: mock,
            store: SharedDefaults(defaults: UserDefaults())
        )

        service.stopMonitoring()

        XCTAssertGreaterThanOrEqual(mock.stopCallCount, 1)
        XCTAssertFalse(service.isMonitoring)
    }

    // MARK: - Budget-reset invariant (TIME_REMAINING_PLAN.md §2)
    //
    // A DeviceActivityEvent counts usage from when monitoring starts unless
    // `includesPastActivity: true` is set, and SkyApp re-arms on every foreground.
    // Without the two defences covered below, opening Sky would hand the user a
    // fresh full budget and they would never be blocked.

    /// Isolated suite so these tests never touch the App Group or `.standard`
    /// (stale shared state is a known source of spurious failures — see CLAUDE.md).
    private func makeIsolatedStore() -> (SharedDefaults, String) {
        let name = "sky.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (SharedDefaults(defaults: defaults), name)
    }

    private func destroy(suite name: String) {
        UserDefaults().removePersistentDomain(forName: name)
    }

    /// Every registered event must count usage accumulated since midnight, not
    /// since the call — otherwise re-arming restarts the day's budget.
    func testEventsIncludePastActivity() throws {
        guard #available(iOS 17.4, *) else {
            throw XCTSkip("includesPastActivity requires iOS 17.4")
        }
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 7200,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertFalse(events.isEmpty)
        for (name, event) in events {
            XCTAssertTrue(
                event.includesPastActivity,
                "\(name.rawValue) would restart the day's usage count on re-arm"
            )
        }
    }

    /// The every-foreground call must not re-register when nothing changed.
    func testRepeatedStartWithUnchangedConfigDoesNotReArm() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()
        store.combinedLimitSeconds = 7200

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        let stopsAfterFirst = mock.stopCallCount
        try service.startMonitoring()
        try service.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 1, "re-arming resets the usage counter")
        XCTAssertEqual(mock.stopCallCount, stopsAfterFirst, "center must not be touched at all")
        XCTAssertTrue(service.isMonitoring)
    }

    /// A fresh `DeviceActivityService` (cold launch) must also skip the re-arm —
    /// the guard reads the center's registrations, not an in-memory flag.
    func testColdLaunchWithUnchangedConfigDoesNotReArm() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        try DeviceActivityService(center: mock, store: store).startMonitoring()

        // Same persisted config + same center, brand-new service instance.
        let relaunched = DeviceActivityService(center: mock, store: store)
        try relaunched.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 1)
        XCTAssertTrue(relaunched.isMonitoring, "state must be recovered from the center")
    }

    /// Editing the limit must still re-arm, or the new budget never takes effect.
    func testChangedLimitReArms() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()
        store.combinedLimitSeconds = 7200

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        store.combinedLimitSeconds = 3600
        try service.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 2)
        XCTAssertEqual(mock.capturedEvents[.dailyLimitReached]?.threshold.second, 3600)
    }

    /// Switching limit mode changes the event set, so it must re-arm too.
    func testChangedLimitModeReArms() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        store.limitMode = "perApp"
        try service.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 2)
    }

    /// If the system dropped our activity (entitlement revoked and re-granted,
    /// iOS upgrade), an unchanged fingerprint must not stop us re-registering.
    func testDroppedActivityReArmsDespiteMatchingFingerprint() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        mock.activities = []          // system forgot us; fingerprint still matches
        try service.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 2)
    }

    /// `force: true` is the escape hatch for the debug menu and repair paths.
    func testForceAlwaysReArms() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)

        try service.startMonitoring()
        try service.startMonitoring(force: true)

        XCTAssertEqual(mock.startCallCount, 2)
    }

    /// A failed registration must not leave a fingerprint claiming the current
    /// configuration is armed — the next attempt has to actually retry.
    func testFailedStartClearsFingerprintSoNextCallRetries() {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        mock.startError = MockStartError()
        let service = DeviceActivityService(center: mock, store: store)

        XCTAssertThrowsError(try service.startMonitoring())
        XCTAssertNil(store.monitoringConfigFingerprint)
        XCTAssertFalse(service.isMonitoring)

        XCTAssertThrowsError(try service.startMonitoring())
        XCTAssertEqual(mock.startCallCount, 2, "a throw must not be cached as success")
    }

    /// No selection means nothing to monitor: tear down and forget the fingerprint.
    func testNoSelectionStopsMonitoringAndClearsFingerprint() throws {
        let (store, suite) = makeIsolatedStore()
        defer { destroy(suite: suite) }
        store.selection = FamilyActivitySelection()

        let mock = MockDeviceActivityCenter()
        let service = DeviceActivityService(center: mock, store: store)
        try service.startMonitoring()

        store.familyActivitySelection = nil
        try service.startMonitoring()

        XCTAssertEqual(mock.startCallCount, 1)
        XCTAssertFalse(service.isMonitoring)
        XCTAssertNil(store.monitoringConfigFingerprint)
    }

    /// The fingerprint must be stable across calls (Swift's seeded `hashValue`
    /// would change every launch) and sensitive to each configuration field.
    func testConfigFingerprintIsStableAndFieldSensitive() {
        let base = DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 3]),
            limitMode: "combined",
            combinedLimitSeconds: 7200,
            perAppLimitsData: nil
        )

        XCTAssertEqual(base, DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 3]),
            limitMode: "combined",
            combinedLimitSeconds: 7200,
            perAppLimitsData: nil
        ))

        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 4]),
            limitMode: "combined",
            combinedLimitSeconds: 7200,
            perAppLimitsData: nil
        ))
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 3]),
            limitMode: "perApp",
            combinedLimitSeconds: 7200,
            perAppLimitsData: nil
        ))
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 3]),
            limitMode: "combined",
            combinedLimitSeconds: 3600,
            perAppLimitsData: nil
        ))
        XCTAssertNotEqual(base, DeviceActivityService.configFingerprint(
            selectionData: Data([1, 2, 3]),
            limitMode: "combined",
            combinedLimitSeconds: 7200,
            perAppLimitsData: Data([9])
        ))

        // nil and empty Data are different configurations, not the same one.
        XCTAssertNotEqual(
            DeviceActivityService.configFingerprint(
                selectionData: nil, limitMode: "combined",
                combinedLimitSeconds: 7200, perAppLimitsData: nil),
            DeviceActivityService.configFingerprint(
                selectionData: Data(), limitMode: "combined",
                combinedLimitSeconds: 7200, perAppLimitsData: nil)
        )
    }
}
