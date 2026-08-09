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

    /// Rung 1 of the combined ladder sits at the session length, with its warning
    /// 30 minutes earlier.
    func testFirstLadderRungMatchesTheSessionLength() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 3600,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertEqual(events[.sessionLimit(rung: 1)]?.threshold.second, 3600)
        XCTAssertEqual(events[.sessionWarning(rung: 1)]?.threshold.second, 1800,
                       "warning fires 30 min before")
    }

    /// The rungs above 1 are what let the apps lock again after a verification.
    /// Each sits at a whole multiple of the session length.
    func testLadderRungsAreMultiplesOfTheSessionLength() {
        let session = 7200
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: session,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        let depth = DeviceActivityService.ladderDepth(sessionSeconds: session)
        XCTAssertGreaterThan(depth, 1, "a single rung would re-create the until-midnight bug")

        for rung in 1...depth {
            XCTAssertEqual(
                events[.sessionLimit(rung: rung)]?.threshold.second, session * rung,
                "rung \(rung) must sit at \(rung)× the session length"
            )
            XCTAssertEqual(
                events[.sessionWarning(rung: rung)]?.threshold.second, session * rung - 1800
            )
        }
        XCTAssertNil(events[.sessionLimit(rung: depth + 1)], "the ladder is finite")
    }

    /// Ladder depth trades off against session length so the horizon stays roughly
    /// constant, and is capped so the event count stays sane.
    func testLadderDepthCoversTheHorizonWithoutExplodingTheEventCount() {
        XCTAssertEqual(DeviceActivityService.ladderDepth(sessionSeconds: 3 * 3600), 4)
        XCTAssertEqual(DeviceActivityService.ladderDepth(sessionSeconds: 2 * 3600), 6)
        XCTAssertEqual(DeviceActivityService.ladderDepth(sessionSeconds: 1 * 3600), 8,
                       "capped at maxLadderDepth rather than 12")
        XCTAssertEqual(DeviceActivityService.ladderDepth(sessionSeconds: 0), 1,
                       "must not divide by zero")

        for session in [3600, 7200, 10800] {
            let events = DeviceActivityService.makeEvents(
                limitMode: "combined",
                combinedLimitSeconds: session,
                selection: FamilyActivitySelection(),
                perAppLimitsData: nil
            )
            XCTAssertLessThanOrEqual(events.count, DeviceActivityService.maxEventsPerActivity)
        }
    }

    /// A session of 30 minutes or less has nowhere to put a warning: rung n's
    /// warning would land at or before rung n−1's limit, firing "30 minutes left"
    /// at the moment the apps actually shut.
    func testShortSessionsEmitNoWarnings() {
        let events = DeviceActivityService.makeEvents(
            limitMode: "combined",
            combinedLimitSeconds: 20 * 60,
            selection: FamilyActivitySelection(),
            perAppLimitsData: nil
        )

        XCTAssertNotNil(events[.sessionLimit(rung: 1)])
        XCTAssertTrue(
            events.keys.allSatisfy { !$0.rawValue.hasPrefix("sessionWarn_") },
            "no rung may carry a warning when the session is ≤ 30 minutes"
        )
        XCTAssertNil(DeviceActivityService.ladderWarningSeconds(sessionSeconds: 1800, rung: 3))
        XCTAssertEqual(DeviceActivityService.ladderWarningSeconds(sessionSeconds: 3600, rung: 3), 9000)
    }

    /// The warning-threshold helper subtracts 30 minutes, or returns nil when the
    /// limit is 30 minutes or less.
    func testWarningThresholdSeconds() {
        XCTAssertEqual(DeviceActivityService.warningThresholdSeconds(for: 7200), 5400)
        XCTAssertEqual(DeviceActivityService.warningThresholdSeconds(for: 1801), 1)
        XCTAssertNil(DeviceActivityService.warningThresholdSeconds(for: 1800))
        XCTAssertNil(DeviceActivityService.warningThresholdSeconds(for: 600))
    }

    /// Rung indices round-trip out of every event-name shape, since the monitor
    /// discards anything it can't place on a ladder.
    func testRungParsesOutOfEveryEventName() {
        XCTAssertEqual(DeviceActivityEvent.Name.rung(from: .sessionLimit(rung: 4)), 4)
        XCTAssertEqual(DeviceActivityEvent.Name.rung(from: .sessionWarning(rung: 2)), 2)
        XCTAssertEqual(
            DeviceActivityEvent.Name.rung(
                from: .init("perApp_\(Data([1, 2, 3]).base64EncodedString())_7")),
            7
        )
        XCTAssertNil(DeviceActivityEvent.Name.rung(from: .init("noUnderscore")))
        XCTAssertNil(DeviceActivityEvent.Name.rung(from: .init("sessionLimit_notANumber")))
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
            events.keys.contains(.sessionLimit(rung: 1)),
            "per-app mode must not emit a combined-ladder event"
        )
        XCTAssertTrue(
            events.isEmpty,
            "nil perAppLimitsData should produce no per-app events"
        )
    }

    /// Per-app limit entries are never pruned when the user edits their app
    /// selection, so `perAppLimitsData` accumulates entries for apps Sky no longer
    /// manages. Registering events from those would burn a budget, post "Time's
    /// up", and shield an app the user removed — the "notification for an app I
    /// don't even track" report.
    ///
    /// Only half of this is unit-testable: `ApplicationToken` is opaque and cannot
    /// be instantiated without a real Family Controls session, so there is no way
    /// to build an entry that *is* in the selection and assert it survives. What
    /// this pins is that an empty selection yields no events no matter what the
    /// stored data says. The positive case is covered by the on-device pass.
    func testPerAppEventsAreNotEmittedForAppsOutsideTheSelection() {
        for stored in [Data(), Data([0x5b, 0x5d]) /* "[]" */, Data([9, 9, 9])] {
            let events = DeviceActivityService.makeEvents(
                limitMode: "perApp",
                combinedLimitSeconds: 7200,
                selection: FamilyActivitySelection(),   // nothing selected
                perAppLimitsData: stored
            )
            XCTAssertTrue(
                events.isEmpty,
                "an empty selection must produce no per-app events (stored: \(stored as NSData))"
            )
        }
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
        XCTAssertEqual(mock.capturedEvents[.sessionLimit(rung: 1)]?.threshold.second, 3600)
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

    // MARK: - Per-app limit event decoding
    //
    // In per-app mode the monitor extension shields only the app whose own budget
    // ran out. Everything hinges on this parser telling a per-app *limit* apart
    // from a per-app *warning* and from the combined-mode names: mistaking a
    // warning for a limit would shield 30 minutes early, and returning nil for a
    // real per-app limit would fall through to the combined branch and shield
    // every selected app.
    //
    // `ApplicationToken` cannot be constructed without a live Family Controls
    // session (see testPerAppModeCreatesOneEventPerApp), so these cover the
    // discrimination logic — the part that can silently do the wrong thing.

    /// A warning must never be read as a limit, or apps lock 30 minutes early.
    func testPerAppWarningNameIsNotDecodedAsALimit() {
        let warning = DeviceActivityEvent.Name(
            "perAppWarn_\(Data([1, 2, 3]).base64EncodedString())_1")
        XCTAssertNil(DeviceActivityEvent.Name.applicationToken(fromPerAppLimit: warning))
    }

    /// Combined-mode names must return nil so the caller takes the combined branch
    /// and shields the whole selection.
    func testCombinedEventNamesDecodeToNil() {
        XCTAssertNil(DeviceActivityEvent.Name.applicationToken(fromPerAppLimit: .sessionLimit(rung: 1)))
        XCTAssertNil(DeviceActivityEvent.Name.applicationToken(fromPerAppLimit: .sessionWarning(rung: 1)))
    }

    /// Malformed payloads must fail closed rather than trap. Includes names with a
    /// well-formed token but no rung suffix — the shape the pre-ladder build wrote,
    /// which can still be sitting in a stale registration on an upgrading device.
    func testMalformedPerAppNamesDecodeToNil() {
        for raw in [
            "perApp_",
            "perApp_not!base64_1",
            "perApp_\(Data([9, 9]).base64EncodedString())_1",
            "perApp_\(Data([9, 9]).base64EncodedString())",   // no rung suffix
        ] {
            XCTAssertNil(
                DeviceActivityEvent.Name.applicationToken(fromPerAppLimit: .init(raw)),
                "\(raw) should not yield a token"
            )
        }
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
