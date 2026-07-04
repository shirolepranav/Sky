// SettingsLogicTests.swift
// Phase 15 automated tests (Roadmap Phase 15 → Automated Tests). Covers the
// once-per-week Pause gate and the Night Mode toggle persistence, exercised
// through the SharedDefaults-backed logic they read/write on an isolated suite.

import XCTest
@testable import Sky

final class SettingsLogicTests: XCTestCase {
    private let suiteName = "SettingsLogicTests"
    private var defaults: UserDefaults!
    private var store: SharedDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedDefaults(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Pause weekly gate

    func testPauseBlockedAfterRecentUse() {
        // No prior pause → allowed.
        XCTAssertTrue(store.canPauseNow)
        XCTAssertNil(store.nextPauseAvailableDate)

        // Paused just now → blocked, with a future availability date.
        store.lastPauseDate = Date()
        XCTAssertFalse(store.canPauseNow)
        XCTAssertNotNil(store.nextPauseAvailableDate)

        // A full week later → allowed again.
        store.lastPauseDate = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        XCTAssertTrue(store.canPauseNow)
        XCTAssertNil(store.nextPauseAvailableDate)
    }

    func testPauseActiveWindow() {
        XCTAssertFalse(store.isPaused)
        store.pauseStartedAt = Date()
        XCTAssertTrue(store.isPaused)
        XCTAssertNotNil(store.pauseEndsAt)

        // 25 hours ago → expired.
        store.pauseStartedAt = Date().addingTimeInterval(-25 * 60 * 60)
        XCTAssertFalse(store.isPaused)
        XCTAssertNil(store.pauseEndsAt)
    }

    // MARK: - Night Mode

    func testNightModeToggle() {
        XCTAssertFalse(store.nightModeEnabled, "defaults off")
        store.nightModeEnabled = true
        XCTAssertTrue(SharedDefaults(defaults: defaults).nightModeEnabled, "persists across reads")
        store.nightModeEnabled = false
        XCTAssertFalse(SharedDefaults(defaults: defaults).nightModeEnabled)
    }

    // MARK: - Notification preference defaults

    func testNotificationTogglesDefaultOn() {
        XCTAssertTrue(store.notifMorningEnabled)
        XCTAssertTrue(store.notifWarningEnabled)
        XCTAssertTrue(store.notifStreakEnabled)
    }
}
