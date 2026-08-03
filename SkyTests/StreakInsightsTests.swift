// StreakInsightsTests.swift
// Unit tests for the pure derivations behind the Streaks tab (S-STREAK-01):
// hero state, next-milestone progress, and the last-seven-days strip.
//
// These are deliberately pure functions over a `UserProgress` value, so unlike
// StreakManagerTests there is no UserDefaults involvement and nothing to clean
// up between tests.
//
// Roadmap Phase 12.

import XCTest
@testable import Sky

final class StreakInsightsTests: XCTestCase {

    /// Fixed calendar so the tests don't drift with the runner's locale.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Noon on an arbitrary fixed day, to keep away from DST/midnight edges.
    private lazy var now: Date = calendar.date(
        from: DateComponents(year: 2026, month: 3, day: 18, hour: 12)
    )!

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    // MARK: - Hero state

    func testHeroStateIsFirstTimeForBrandNewUser() {
        let p = UserProgress()
        XCTAssertEqual(StreakInsights.heroState(p), .firstTime)
    }

    func testHeroStateIsActiveDuringAStreak() {
        var p = UserProgress()
        p.currentStreak = 4
        p.totalVerifications = 4
        XCTAssertEqual(StreakInsights.heroState(p), .active)
    }

    /// The bug this fixes: a veteran with a lapsed streak previously saw the
    /// brand-new-user copy ("Your first verification starts your streak").
    func testHeroStateIsBrokenAfterALapseNotFirstTime() {
        var p = UserProgress()
        p.currentStreak = 0
        p.totalVerifications = 50
        p.longestStreak = 21
        XCTAssertEqual(StreakInsights.heroState(p), .broken)
    }

    // MARK: - Next milestone

    func testNextMilestoneFromZero() {
        let m = StreakInsights.nextMilestone(after: 0)
        XCTAssertEqual(m?.target, 3)
        XCTAssertEqual(m?.daysRemaining, 3)
        XCTAssertEqual(m?.fraction ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(m?.badge, .cumulus)
    }

    func testNextMilestoneMidwayBetweenTwoMilestones() {
        // 10 days: past 7 (Stratus), working toward 14 (Cirrus).
        let m = StreakInsights.nextMilestone(after: 10)
        XCTAssertEqual(m?.target, 14)
        XCTAssertEqual(m?.daysRemaining, 4)
        XCTAssertEqual(m?.fraction ?? -1, 3.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(m?.badge, .cirrus)
    }

    /// Landing exactly on a milestone should advance to the next one, not report
    /// the one just earned.
    func testNextMilestoneOnAnExactMilestoneAdvances() {
        let m = StreakInsights.nextMilestone(after: 7)
        XCTAssertEqual(m?.target, 14)
        XCTAssertEqual(m?.daysRemaining, 7)
        XCTAssertEqual(m?.fraction ?? -1, 0, accuracy: 0.0001)
    }

    func testNextMilestoneIsNilPastTheFinalMilestone() {
        XCTAssertNil(StreakInsights.nextMilestone(after: 100))
        XCTAssertNil(StreakInsights.nextMilestone(after: 137))
    }

    func testEveryMilestoneMapsToABadge() {
        for milestone in StreakInsights.milestones {
            XCTAssertNotNil(StreakInsights.badge(forMilestone: milestone),
                            "Milestone \(milestone) has no badge")
        }
    }

    // MARK: - Last seven days

    func testLastSevenDaysReturnsSevenDaysOldestFirst() {
        let marks = StreakInsights.lastSevenDays(progress: UserProgress(),
                                                 now: now,
                                                 calendar: calendar)
        XCTAssertEqual(marks.count, 7)
        XCTAssertEqual(marks.map(\.date), (0..<7).map { daysAgo(6 - $0) }.map(calendar.startOfDay(for:)))
        XCTAssertTrue(marks.last?.isToday == true)
        XCTAssertEqual(marks.filter(\.isToday).count, 1)
    }

    func testNoDaysFilledWhenUserHasNeverVerified() {
        let marks = StreakInsights.lastSevenDays(progress: UserProgress(),
                                                 now: now,
                                                 calendar: calendar)
        XCTAssertTrue(marks.allSatisfy { !$0.isVerified })
    }

    func testStreakWindowFillsTheMostRecentDays() {
        var p = UserProgress()
        p.currentStreak = 3
        p.totalVerifications = 3
        p.lastVerificationDate = now   // verified today

        let marks = StreakInsights.lastSevenDays(progress: p, now: now, calendar: calendar)
        // Oldest four unfilled, most recent three filled.
        XCTAssertEqual(marks.map(\.isVerified), [false, false, false, false, true, true, true])
    }

    /// A streak that ended yesterday should leave today unfilled.
    func testStreakEndingYesterdayLeavesTodayUnfilled() {
        var p = UserProgress()
        p.currentStreak = 2
        p.totalVerifications = 9
        p.lastVerificationDate = daysAgo(1)

        let marks = StreakInsights.lastSevenDays(progress: p, now: now, calendar: calendar)
        // Index 0...6 maps to 6-days-ago ... today. The 2-day streak covers
        // 2-days-ago and yesterday, so only indices 4 and 5 are filled.
        XCTAssertEqual(marks.map(\.isVerified), [false, false, false, false, true, true, false])
        XCTAssertFalse(marks[6].isVerified, "Today must be unfilled")
    }

    /// A streak longer than the window fills every dot rather than overflowing.
    func testStreakLongerThanTheWindowFillsAllSevenDays() {
        var p = UserProgress()
        p.currentStreak = 100
        p.totalVerifications = 143
        p.lastVerificationDate = now

        let marks = StreakInsights.lastSevenDays(progress: p, now: now, calendar: calendar)
        XCTAssertTrue(marks.allSatisfy(\.isVerified))
    }

    /// Defensive: a non-zero streak with no recorded date must not fill anything.
    func testMissingLastVerificationDateFillsNothing() {
        var p = UserProgress()
        p.currentStreak = 5
        p.lastVerificationDate = nil

        let marks = StreakInsights.lastSevenDays(progress: p, now: now, calendar: calendar)
        XCTAssertTrue(marks.allSatisfy { !$0.isVerified })
    }

    /// A stale streak (last verified well before the window) fills nothing.
    func testStaleStreakOutsideTheWindowFillsNothing() {
        var p = UserProgress()
        p.currentStreak = 2
        p.totalVerifications = 30
        p.lastVerificationDate = daysAgo(20)

        let marks = StreakInsights.lastSevenDays(progress: p, now: now, calendar: calendar)
        XCTAssertTrue(marks.allSatisfy { !$0.isVerified })
    }
}
