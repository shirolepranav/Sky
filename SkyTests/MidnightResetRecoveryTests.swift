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

    // MARK: Late reset must not undo today's state

    /// The "Go outside to unlock" bug. The extension shielded the apps *today*
    /// but the reset token was still yesterday's, so the first foreground — which
    /// is the tap on the shield button — ran the reset and opened the apps with
    /// no verification. `todayStateDay` is what tells the two apart.
    func testStaleStampDoesNotUnshieldABlockAppliedToday() {
        store.todayResetToken = "2026-08-06"          // yesterday: reset is due
        store.todayStateDay = stamp(noon)             // but the block is today's
        store.isCurrentlyBlocked = true

        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .stampOnly)
        XCTAssertFalse(cleared, "a late reset must never lift a live shield")
        XCTAssertTrue(store.isCurrentlyBlocked)
        XCTAssertEqual(store.todayResetToken, stamp(noon), "stamps must still converge")
        XCTAssertFalse(store.pendingMidnightReset, "no day boundary was crossed here")
    }

    /// Same guard, other direction: a verification completed today survives a
    /// late reset, so the user isn't asked to go outside twice.
    func testStaleStampPreservesAVerificationDoneToday() {
        store.todayResetToken = "2026-08-06"
        store.todayStateDay = stamp(noon)
        store.didVerifyToday = true

        MidnightResetRecovery.runIfNeeded(store: store, now: noon, clearShields: {})

        XCTAssertTrue(store.didVerifyToday)
    }

    /// The guard must not swallow a genuine day rollover: state stamped yesterday
    /// still gets cleared.
    func testStateStampedYesterdayStillTriggersFullReset() {
        store.todayResetToken = "2026-08-06"
        store.todayStateDay = "2026-08-06"
        store.isCurrentlyBlocked = true

        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .recovered)
        XCTAssertTrue(cleared)
        XCTAssertFalse(store.isCurrentlyBlocked)
        XCTAssertEqual(store.todayStateDay, stamp(noon), "cleared flags now describe today")
    }

    /// Clock moved backwards, or the user flew west across the date line. A stamp
    /// ahead of today is not stale, and treating it as stale would unshield.
    func testFutureStampIsAdoptedWithoutClearing() {
        store.todayResetToken = "2026-09-01"
        store.isCurrentlyBlocked = true

        var cleared = false
        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: { cleared = true })

        XCTAssertEqual(outcome, .adoptedFutureStamp)
        XCTAssertFalse(cleared, "going back in time must not open the apps")
        XCTAssertTrue(store.isCurrentlyBlocked)
        XCTAssertEqual(store.todayResetToken, stamp(noon))
    }

    // MARK: Rolling the day over before writing today's state

    /// The `.stampOnly` trap: an app-side writer (a verification, an emergency
    /// unlock, a pause) that stamps `todayStateDay` while `todayResetToken` still
    /// holds yesterday leaves the recovery unable to tell yesterday's flags from
    /// today's. It then returns `.stampOnly` forever, never writes the streak
    /// hand-off, and the previous day is never evaluated — a streak survives a day
    /// it should have broken.
    ///
    /// Every such writer now rolls the day over first. This pins that the roll-over
    /// produces a real reset with the hand-off intact.
    func testRollingOverBeforeWritingTodayStateEvaluatesYesterday() {
        let yesterday = noon.addingTimeInterval(-24 * 60 * 60)
        store.todayResetToken = stamp(yesterday)
        store.todayStateDay = stamp(yesterday)
        store.didVerifyToday = true          // yesterday's verification
        store.isCurrentlyBlocked = true

        MidnightResetRecovery.rollDayOverBeforeWritingTodayState(store: store, now: noon)

        XCTAssertTrue(store.pendingMidnightReset, "yesterday must be handed to StreakManager")
        XCTAssertTrue(store.yesterdayDidVerify, "yesterday's verification must be preserved")
        XCTAssertFalse(store.didVerifyToday, "today starts unverified")
        XCTAssertEqual(store.todayResetToken, stamp(noon))
    }

    /// Without the roll-over, writing today's state on a stale token is exactly
    /// what strands the recovery. This documents the failure it prevents.
    func testWritingTodayStateOnAStaleTokenStrandsTheRecovery() {
        let yesterday = noon.addingTimeInterval(-24 * 60 * 60)
        store.todayResetToken = stamp(yesterday)

        // A verification at 00:05 that skipped the roll-over.
        store.didVerifyToday = true
        store.stampTodayState(now: noon)

        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: {})

        XCTAssertEqual(outcome, .stampOnly)
        XCTAssertFalse(
            store.pendingMidnightReset,
            "this is the gap: yesterday is never evaluated once today's state is written"
        )
    }

    /// Called twice in a row, the roll-over is a no-op the second time — it must be
    /// safe to sprinkle at the top of every writer.
    func testRollingOverTwiceIsIdempotent() {
        let yesterday = noon.addingTimeInterval(-24 * 60 * 60)
        store.todayResetToken = stamp(yesterday)
        store.todayStateDay = stamp(yesterday)

        MidnightResetRecovery.rollDayOverBeforeWritingTodayState(store: store, now: noon)
        store.pendingMidnightReset = false   // simulate StreakManager consuming it

        MidnightResetRecovery.rollDayOverBeforeWritingTodayState(store: store, now: noon)

        XCTAssertFalse(
            store.pendingMidnightReset,
            "a second roll-over must not hand off an already-cleared day and zero a live streak"
        )
    }

    // MARK: Notification budget

    /// The per-day notification caps are day-stamped, so the reset has to re-open
    /// them or the new day's first genuine threshold event stays silent.
    func testResetReopensTheNotificationBudget() {
        let yesterday = noon.addingTimeInterval(-24 * 60 * 60)
        store.todayResetToken = stamp(yesterday)
        store.todayStateDay = stamp(yesterday)
        store.notifWarningDay = stamp(yesterday)
        store.notifBlockStartDay = stamp(yesterday)

        let outcome = MidnightResetRecovery.runIfNeeded(
            store: store, now: noon, clearShields: {})

        XCTAssertEqual(outcome, .recovered)
        XCTAssertEqual(store.notifWarningDay, "")
        XCTAssertEqual(store.notifBlockStartDay, "")
    }
}
