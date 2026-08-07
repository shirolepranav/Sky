// MidnightResetRecoveryTests.swift
// Covers the app-side safety net for a missed midnight reset (J-06).
//
// The stakes are asymmetric: failing to recover leaves the user shielded past
// midnight, but recovering when it wasn't needed hands StreakManager a bogus
// "yesterday" and zeroes a live streak. Both directions are pinned here.

import XCTest
@testable import Sky

final class MidnightResetRecoveryTests: XCTestCase {

    private var suiteName = ""
    private var store = SharedDefaults()

    override func setUp() {
        super.setUp()
        suiteName = "sky.tests.\(UUID().uuidString)"
        store = SharedDefaults(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// 2026-08-07 12:00 UTC — midday, so the local calendar day is unambiguous
    /// in the simulator's time zone whatever it happens to be.
    private let noon = Date(timeIntervalSince1970: 1_786_104_000)

    private func stamp(_ date: Date) -> String {
        MidnightResetRecovery.dayStamp(for: date, timeZone: .current)
    }

    // MARK: Day stamp

    /// The stamp must follow the *local* calendar day, because
    /// DeviceActivitySchedule starts its interval at local midnight. Formatting in
    /// UTC (the previous behaviour) is off by one for much of the world.
    func testDayStampUsesLocalCalendarDay() {
        // 2026-08-07 13:00 UTC. Auckland (UTC+12 in August) is already into the
        // 8th; Los Angeles (UTC-7) is still on the 7th.
        let instant = Date(timeIntervalSince1970: 1_786_107_600)
        let auckland = MidnightResetRecovery.dayStamp(
            for: instant, timeZone: TimeZone(identifier: "Pacific/Auckland")!)
        let losAngeles = MidnightResetRecovery.dayStamp(
            for: instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!)

        XCTAssertNotEqual(auckland, losAngeles)
        XCTAssertEqual(auckland.count, 10, "YYYY-MM-DD")
    }

    /// Format must be fixed regardless of device locale — a Gregorian yyyy-MM-dd.
    func testDayStampFormatIsLocaleIndependent() {
        let s = MidnightResetRecovery.dayStamp(for: noon, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(s, "2026-08-07")
    }

    // MARK: Recovery decision

    /// Stamp already today: the extension did its job, do nothing at all.
    func testUpToDateStampIsLeftAlone() {
        store.todayResetToken = stamp(noon)
        store.didVerifyToday = true
        store.isCurrentlyBlocked = true

        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .upToDate)
        XCTAssertFalse(cleared)
        XCTAssertTrue(store.didVerifyToday, "today's state must survive")
        XCTAssertTrue(store.isCurrentlyBlocked)
        XCTAssertFalse(store.pendingMidnightReset, "no hand-off — would zero the streak")
    }

    /// Fresh install: adopt the stamp but never invent a yesterday, or the first
    /// launch after restoring a backup would break the restored streak.
    func testFirstRunAdoptsStampWithoutStreakHandoff() {
        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .adoptedFirstStamp)
        XCTAssertEqual(store.todayResetToken, stamp(noon))
        XCTAssertFalse(cleared)
        XCTAssertFalse(store.pendingMidnightReset)
    }

    /// The bug this exists for: extension missed midnight, so the user is still
    /// shielded. Recovery must clear the shield and today's flags.
    func testStaleStampRunsTheResetAndUnshields() {
        store.todayResetToken = "2026-08-01"
        store.isCurrentlyBlocked = true
        store.didVerifyToday = false

        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .recovered)
        XCTAssertTrue(cleared, "user would stay shielded past midnight")
        XCTAssertFalse(store.isCurrentlyBlocked)
        XCTAssertEqual(store.todayResetToken, stamp(noon))
    }

    /// A verification from the previous day must not leak into today, or the apps
    /// stay unlocked for a second day.
    func testStaleStampClearsYesterdaysVerification() {
        store.todayResetToken = "2026-08-05"
        store.didVerifyToday = true

        MidnightResetRecovery.runIfNeeded(store: store, now: noon, clearShields: {})

        XCTAssertFalse(store.didVerifyToday)
        XCTAssertFalse(store.didEmergencyUnlockToday)
    }

    /// Yesterday's flags must reach StreakManager intact — that hand-off is the
    /// only record of whether the streak survives.
    func testRecoverySnapshotsYesterdayForStreakManager() {
        store.todayResetToken = "2026-08-05"
        store.didVerifyToday = true
        store.didEmergencyUnlockToday = false

        MidnightResetRecovery.runIfNeeded(store: store, now: noon, clearShields: {})

        XCTAssertTrue(store.pendingMidnightReset)
        XCTAssertTrue(store.yesterdayDidVerify, "a kept streak would be wrongly broken")
        XCTAssertFalse(store.yesterdayDidEmergency)
    }

    /// An emergency unlock yesterday must be reported as such, not as a verification.
    func testRecoverySnapshotsYesterdayEmergency() {
        store.todayResetToken = "2026-08-05"
        store.didEmergencyUnlockToday = true

        MidnightResetRecovery.runIfNeeded(store: store, now: noon, clearShields: {})

        XCTAssertTrue(store.yesterdayDidEmergency)
        XCTAssertFalse(store.yesterdayDidVerify)
    }

    /// Idempotence: the second call in the same day must not queue another
    /// hand-off over the now-cleared flags.
    func testSecondRunSameDayDoesNothing() {
        store.todayResetToken = "2026-08-05"
        store.didVerifyToday = true

        MidnightResetRecovery.runIfNeeded(store: store, now: noon, clearShields: {})
        store.pendingMidnightReset = false      // simulate StreakManager consuming it
        store.yesterdayDidVerify = false

        let second = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: {})

        XCTAssertEqual(second, .upToDate)
        XCTAssertFalse(store.pendingMidnightReset, "a second hand-off would zero the streak")
    }

    /// A multi-day absence collapses to a single hand-off; StreakManager's own
    /// day-delta arithmetic handles the rest.
    func testMultiDayGapProducesOneHandoff() {
        store.todayResetToken = "2026-07-20"
        store.didVerifyToday = false

        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: {})

        XCTAssertEqual(outcome, .recovered)
        XCTAssertTrue(store.pendingMidnightReset)
        XCTAssertEqual(store.todayResetToken, stamp(noon))
    }
}
