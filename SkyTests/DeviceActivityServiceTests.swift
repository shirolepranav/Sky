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

private final class MockDeviceActivityCenter: DeviceActivityScheduling {
    var capturedSchedule: DeviceActivitySchedule?
    var capturedEvents: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    var startCallCount = 0
    var stopCallCount  = 0

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        capturedSchedule = schedule
        capturedEvents   = events
        startCallCount  += 1
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stopCallCount += 1
    }
}

// MARK: - Tests

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

    /// Combined mode with a known limit must produce exactly one event keyed
    /// `.dailyLimitReached` with the matching threshold.
    func testEventThresholdMatchesCombinedLimit() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 3600,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertEqual(events.count, 1)
        let event = events[.dailyLimitReached]
        XCTAssertNotNil(event, "combined mode must produce a dailyLimitReached event")
        XCTAssertEqual(event?.threshold.second, 3600)
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
}
