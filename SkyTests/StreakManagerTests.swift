// StreakManagerTests.swift
// Unit tests for StreakManager streak arithmetic.
// Roadmap Phase 12 — StreakManagerTests.

import XCTest
@testable import Sky

@MainActor
final class StreakManagerTests: XCTestCase {

    // Each test gets a StreakManager backed by an isolated UserDefaults suite so
    // tests don't pollute each other or the real app's stored progress.
    private func makeManager() -> StreakManager {
        let suiteName = "test.streak.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        // StreakManager calls UserProgress.load() from UserDefaults.standard —
        // override via a subclass approach is not possible, so we reset standard
        // and restore it. Instead, we accept testing on .standard with cleanup.
        UserDefaults.standard.removeObject(forKey: "userProgress")
        return StreakManager()
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "userProgress")
    }

    // MARK: - Streak arithmetic

    func testFirstVerificationStartsStreakAt1() {
        let manager = makeManager()
        let (streak, _) = manager.handleVerificationSuccess(locationTag: nil, time: Date())
        XCTAssertEqual(streak, 1)
        XCTAssertEqual(manager.progress.currentStreak, 1)
    }

    func testConsecutiveDaysIncrementStreak() {
        let manager = makeManager()
        let day1 = Date()
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!
        let day3 = Calendar.current.date(byAdding: .day, value: 2, to: day1)!

        manager.handleVerificationSuccess(locationTag: nil, time: day1)
        manager.handleVerificationSuccess(locationTag: nil, time: day2)
        let (streak, _) = manager.handleVerificationSuccess(locationTag: nil, time: day3)

        XCTAssertEqual(streak, 3)
    }

    func testMissedDayResetsStreakToOne() {
        let manager = makeManager()
        let day1 = Date()
        let day3 = Calendar.current.date(byAdding: .day, value: 2, to: day1)! // skipped day 2

        manager.handleVerificationSuccess(locationTag: nil, time: day1)
        let (streak, _) = manager.handleVerificationSuccess(locationTag: nil, time: day3)

        XCTAssertEqual(streak, 1, "Skipping a day should reset the streak to 1")
    }

    func testEmergencyUnlockResetsStreak() {
        let manager = makeManager()
        let day1 = Date()
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!

        manager.handleVerificationSuccess(locationTag: nil, time: day1)
        manager.handleVerificationSuccess(locationTag: nil, time: day2)
        XCTAssertEqual(manager.progress.currentStreak, 2)

        manager.handleEmergencyUnlock()
        XCTAssertEqual(manager.progress.currentStreak, 0)
    }

    func testLongestStreakUpdatesWhenExceeded() {
        let manager = makeManager()
        let base = Date()
        for i in 0..<5 {
            let day = Calendar.current.date(byAdding: .day, value: i, to: base)!
            manager.handleVerificationSuccess(locationTag: nil, time: day)
        }
        XCTAssertEqual(manager.progress.longestStreak, 5)

        // Reset then build a shorter streak — longest should not decrease
        manager.handleEmergencyUnlock()
        let restart = Calendar.current.date(byAdding: .day, value: 6, to: base)!
        manager.handleVerificationSuccess(locationTag: nil, time: restart)
        XCTAssertEqual(manager.progress.longestStreak, 5, "Longest streak must never decrease")
    }

    func testSameDayVerificationIsIdempotent() {
        let manager = makeManager()
        let now = Date()

        manager.handleVerificationSuccess(locationTag: nil, time: now)
        let (streak, _) = manager.handleVerificationSuccess(locationTag: nil, time: now)

        XCTAssertEqual(streak, 1, "Two verifications on the same day should keep streak at 1")
        XCTAssertEqual(manager.progress.totalVerifications, 2, "But total count should still increment")
    }

    func testMidnightResetWithNoVerificationResetsStreak() {
        let manager = makeManager()
        let day1 = Date()
        manager.handleVerificationSuccess(locationTag: nil, time: day1)
        XCTAssertEqual(manager.progress.currentStreak, 1)

        // Simulate midnight: user did NOT verify yesterday
        manager.handleMidnightReset(didVerifyYesterday: false, didEmergencyYesterday: false)
        XCTAssertEqual(manager.progress.currentStreak, 0)
    }

    func testMidnightResetWithVerificationPreservesStreak() {
        let manager = makeManager()
        let day1 = Date()
        manager.handleVerificationSuccess(locationTag: nil, time: day1)
        XCTAssertEqual(manager.progress.currentStreak, 1)

        // Simulate midnight: user DID verify yesterday
        manager.handleMidnightReset(didVerifyYesterday: true, didEmergencyYesterday: false)
        XCTAssertEqual(manager.progress.currentStreak, 1, "Streak should be preserved when yesterday had a verification")
    }

    // MARK: - Milestone detection

    func testIsMilestoneStreak() {
        let manager = makeManager()
        XCTAssertTrue(manager.isMilestoneStreak(3))
        XCTAssertTrue(manager.isMilestoneStreak(7))
        XCTAssertTrue(manager.isMilestoneStreak(14))
        XCTAssertTrue(manager.isMilestoneStreak(30))
        XCTAssertTrue(manager.isMilestoneStreak(60))
        XCTAssertTrue(manager.isMilestoneStreak(100))
        XCTAssertFalse(manager.isMilestoneStreak(1))
        XCTAssertFalse(manager.isMilestoneStreak(5))
        XCTAssertFalse(manager.isMilestoneStreak(99))
    }

    // MARK: - Persistence

    func testProgressPersistsAcrossManagerReinit() {
        do {
            let manager = makeManager()
            let base = Date()
            manager.handleVerificationSuccess(locationTag: nil, time: base)
            let day2 = Calendar.current.date(byAdding: .day, value: 1, to: base)!
            manager.handleVerificationSuccess(locationTag: nil, time: day2)
            XCTAssertEqual(manager.progress.currentStreak, 2)
        }
        // Create a new manager (simulating re-launch) — progress should survive
        let reloaded = StreakManager()
        XCTAssertEqual(reloaded.progress.currentStreak, 2)
        XCTAssertEqual(reloaded.progress.totalVerifications, 2)
    }
}
