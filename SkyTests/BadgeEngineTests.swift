// BadgeEngineTests.swift
// Unit tests for BadgeEngine badge condition evaluation.
// Roadmap Phase 12 — BadgeEngineTests.

import XCTest
@testable import Sky

final class BadgeEngineTests: XCTestCase {

    // MARK: - Helpers

    private func progress(
        totalVerifications: Int = 1,
        currentStreak: Int = 1,
        unlockedBadges: Set<BadgeID> = [],
        verificationLocations: [String] = [],
        hadEmergencyUnlock: Bool = false,
        streakAfterFirstEmergency: Int = 0
    ) -> UserProgress {
        var p = UserProgress()
        p.totalVerifications = totalVerifications
        p.currentStreak = currentStreak
        p.unlockedBadges = unlockedBadges
        p.verificationLocations = verificationLocations
        p.hadEmergencyUnlock = hadEmergencyUnlock
        p.streakAfterFirstEmergency = streakAfterFirstEmergency
        return p
    }

    private func time(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    // MARK: - First Light

    func testFirstLightUnlocksOnFirstVerification() {
        let p = progress(totalVerifications: 1)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertTrue(badges.contains(.firstLight))
    }

    func testFirstLightDoesNotUnlockOnSubsequentVerifications() {
        let p = progress(totalVerifications: 2)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertFalse(badges.contains(.firstLight))
    }

    // MARK: - Streak badges

    func testStreakBadgesUnlockAtCorrectThresholds() {
        let thresholds: [(BadgeID, Int)] = [
            (.cumulus, 3), (.stratus, 7), (.cirrus, 14),
            (.sunburst, 30), (.clearSky, 60), (.boundless, 100)
        ]
        for (badge, threshold) in thresholds {
            let p = progress(currentStreak: threshold)
            let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
            XCTAssertTrue(badges.contains(badge),
                          "\(badge.rawValue) should unlock at streak \(threshold)")
        }
    }

    func testStreakBadgesDoNotUnlockBelowThreshold() {
        let p = progress(currentStreak: 2) // below Cumulus (3)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertFalse(badges.contains(.cumulus))
    }

    // MARK: - Early Bird

    func testEarlyBirdRequiresVerificationBefore8AM() {
        let p = progress()
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 7))
        XCTAssertTrue(badges.contains(.earlyBird))
    }

    func testEarlyBirdDoesNotUnlockAt8AM() {
        let p = progress()
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 8))
        XCTAssertFalse(badges.contains(.earlyBird), "Early Bird requires strictly before 8 AM")
    }

    func testEarlyBirdDoesNotUnlockAfter8AM() {
        let p = progress()
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 10))
        XCTAssertFalse(badges.contains(.earlyBird))
    }

    // MARK: - Wanderer

    func testWandererRequires5DistinctLocations() {
        let locations = ["37.12_-122.00", "40.71_-74.00", "51.50_-0.13", "48.85_2.35", "35.68_139.69"]
        let p = progress(verificationLocations: locations)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertTrue(badges.contains(.wanderer))
    }

    func testWandererDoesNotUnlockWith4Locations() {
        let locations = ["37.12_-122.00", "40.71_-74.00", "51.50_-0.13", "48.85_2.35"]
        let p = progress(verificationLocations: locations)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertFalse(badges.contains(.wanderer))
    }

    // MARK: - Comeback

    func testComebackRequires7DaysAfterEmergency() {
        let p = progress(hadEmergencyUnlock: true, streakAfterFirstEmergency: 7)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertTrue(badges.contains(.comeback))
    }

    func testComebackDoesNotUnlockWithoutEmergency() {
        let p = progress(hadEmergencyUnlock: false, streakAfterFirstEmergency: 7)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertFalse(badges.contains(.comeback))
    }

    func testComebackDoesNotUnlockWith6DaysAfterEmergency() {
        let p = progress(hadEmergencyUnlock: true, streakAfterFirstEmergency: 6)
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 12))
        XCTAssertFalse(badges.contains(.comeback))
    }

    // MARK: - Already-unlocked badges are never returned

    func testAlreadyEarnedBadgesAreNotReturned() {
        let allBadges = Set(BadgeID.allCases)
        let p = progress(
            totalVerifications: 1,
            currentStreak: 100,
            unlockedBadges: allBadges,
            verificationLocations: Array(repeating: "", count: 5),
            hadEmergencyUnlock: true,
            streakAfterFirstEmergency: 7
        )
        let badges = BadgeEngine.evaluate(progress: p, verificationTime: time(hour: 7))
        XCTAssertTrue(badges.isEmpty, "No badges should be returned when all are already unlocked")
    }
}
