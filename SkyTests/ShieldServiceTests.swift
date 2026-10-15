// ShieldServiceTests.swift
// The decision half of the daily lock (DAILY_LOCK_PLAN.md Phase B):
// `ShieldService.shouldBeBlocked`, the missed-callback catch-up, and LockPolicy.
//
// The apply/clear half writes to ManagedSettingsStore, which needs the Family
// Controls entitlement and a real device, so it is not exercised here.

import XCTest
import FamilyControls
@testable import Sky

final class ShieldServiceTests: XCTestCase {

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

    private func at(_ hour: Int, _ minute: Int = 0, daysFromNow: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    /// A store as it looks after setup finished yesterday: armed, 9 AM lock, today's
    /// day stamp current so no rollover interferes.
    private func armedStore(now: Date) {
        store.lockTimeMinutes = 9 * 60
        store.lockArmedAt = at(8, daysFromNow: -1)
        store.todayResetToken = MidnightResetRecovery.dayStamp(for: now)
    }

    // MARK: shouldBeBlocked

    func testBlockedShouldBeBlocked() {
        store.isCurrentlyBlocked = true
        XCTAssertTrue(ShieldService.shouldBeBlocked(store: store))
    }

    func testNotBlockedShouldNotBeBlocked() {
        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    func testActivePauseShouldNotBeBlocked() {
        store.isCurrentlyBlocked = true
        store.pauseStartedAt = Date().addingTimeInterval(-60)
        XCTAssertFalse(ShieldService.shouldBeBlocked(store: store))
    }

    func testExpiredPauseShouldBeBlocked() {
        store.isCurrentlyBlocked = true
        store.pauseStartedAt = Date().addingTimeInterval(-25 * 60 * 60)
        XCTAssertTrue(ShieldService.shouldBeBlocked(store: store))
    }

    // MARK: Catch-up for a missed lock callback

    func testOverdueLockIsCaughtUp() {
        let now = at(10)
        armedStore(now: now)
        XCTAssertTrue(ShieldService.catchUpMissedLock(store: store, now: now))
        XCTAssertTrue(store.isCurrentlyBlocked)
    }

    func testNoCatchUpBeforeLockTime() {
        let now = at(8, 59)
        armedStore(now: now)
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
        XCTAssertFalse(store.isCurrentlyBlocked)
    }

    /// Early bird: went outside before the lock time, so today's lock never lands.
    func testVerifiedTodaySkipsTheLock() {
        let now = at(10)
        armedStore(now: now)
        store.didVerifyToday = true
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    func testEmergencyUnlockTodaySkipsTheLock() {
        let now = at(10)
        armedStore(now: now)
        store.didEmergencyUnlockToday = true
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    /// Yesterday's verification must not carry over: the catch-up rolls the day
    /// over before reading the flags.
    func testYesterdaysVerificationDoesNotSkipTodaysLock() {
        let now = at(10)
        armedStore(now: now)
        store.todayResetToken = MidnightResetRecovery.dayStamp(for: at(10, daysFromNow: -1))
        store.todayStateDay = store.todayResetToken
        store.didVerifyToday = true

        XCTAssertTrue(ShieldService.catchUpMissedLock(store: store, now: now))
        XCTAssertFalse(store.didVerifyToday)
        XCTAssertTrue(store.yesterdayDidVerify)
    }

    func testNeverArmedNeverLocks() {
        let now = at(10)
        armedStore(now: now)
        store.lockArmedAt = nil
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    func testSkipDayIsHonoured() {
        let now = at(10)
        armedStore(now: now)
        store.lockSkipDay = MidnightResetRecovery.dayStamp(for: now)
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    func testDayOffIsHonoured() {
        let now = at(10)
        armedStore(now: now)
        let today = Calendar.current.component(.weekday, from: now)
        store.lockWeekdays = Set(1...7).subtracting([today])
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    func testPauseSkipsTheLock() {
        let now = at(10)
        armedStore(now: now)
        store.pauseStartedAt = now.addingTimeInterval(-60)
        XCTAssertFalse(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    /// Re-arming inside the grace window does not stop the app-side catch-up —
    /// that is exactly the case the extension hands over.
    func testRecentReArmStillCatchesUp() {
        let now = at(10)
        armedStore(now: now)
        store.lockArmedAt = now.addingTimeInterval(-5)
        XCTAssertTrue(ShieldService.catchUpMissedLock(store: store, now: now))
    }

    // MARK: Midnight never unlocks

    /// An unverified day stays locked through midnight.
    func testMidnightRolloverLeavesTheLockInPlace() {
        store.isCurrentlyBlocked = true
        store.todayResetToken = "2000-01-01"
        store.todayStateDay = "2000-01-01"

        XCTAssertEqual(MidnightResetRecovery.runIfNeeded(store: store), .recovered)
        XCTAssertTrue(store.isCurrentlyBlocked)
        XCTAssertTrue(ShieldService.shouldBeBlocked(store: store))
    }

    // MARK: LockPolicy

    func testLockInstantUsesWallClockTime() {
        let instant = LockPolicy.lockInstant(on: Date(), lockTimeMinutes: 9 * 60 + 30)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: instant)
        XCTAssertEqual(parts.hour, 9)
        XCTAssertEqual(parts.minute, 30)
    }

    /// The 2026 US spring-forward day: startOfDay + 9h would land at 10 AM.
    func testLockInstantOnDSTDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let dstDay = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let instant = LockPolicy.lockInstant(on: dstDay, lockTimeMinutes: 9 * 60, calendar: cal)
        XCTAssertEqual(cal.component(.hour, from: instant), 9)
    }
}
