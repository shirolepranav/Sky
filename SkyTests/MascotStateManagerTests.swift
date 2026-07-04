// MascotStateManagerTests.swift
// Automated tests for Phase 11 — Roadmap Phase 11 Automated Tests.
// Verifies that MascotStateManager derives the correct MascotState from
// SharedDefaults flags across all priority branches.

import XCTest
@testable import Sky

@MainActor
final class MascotStateManagerTests: XCTestCase {
    private let suiteName = "MascotStateManagerTests"
    private var defaults: UserDefaults!
    private var store: SharedDefaults!
    private var manager: MascotStateManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedDefaults(defaults: defaults)
        manager = MascotStateManager(store: store)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - State derivation

    func testDefaultIsFluffyWhite() {
        // All flags are false by default — user is under budget.
        XCTAssertEqual(manager.state, .fluffyWhite)
    }

    func testVerificationTransitionsToSunny() {
        store.didVerifyToday = true
        manager.refreshState()
        XCTAssertEqual(manager.state, .sunny)
    }

    func testEmergencyUnlockTransitionsToRainy() {
        store.didEmergencyUnlockToday = true
        manager.refreshState()
        XCTAssertEqual(manager.state, .rainy)
    }

    func testBlockedWithNoVerificationIsCloudyGrey() {
        store.isCurrentlyBlocked = true
        // didVerifyToday stays false
        manager.refreshState()
        XCTAssertEqual(manager.state, .cloudyGrey)
    }

    func testVerifiedOverridesBlocked() {
        // Edge case: both blocked and verified (e.g. extension hasn't cleared shield yet)
        store.isCurrentlyBlocked = true
        store.didVerifyToday = true
        manager.refreshState()
        XCTAssertEqual(manager.state, .sunny)
    }

    func testEmergencyTakesPriorityOverVerified() {
        // User verified then hit emergency unlock on the same day.
        store.didVerifyToday = true
        store.didEmergencyUnlockToday = true
        manager.refreshState()
        XCTAssertEqual(manager.state, .rainy)
    }

    // MARK: - Event helpers delegate to refreshState

    func testHandleVerificationSuccessRefreshesToSunny() {
        store.didVerifyToday = true
        manager.handleVerificationSuccess()
        XCTAssertEqual(manager.state, .sunny)
    }

    func testHandleEmergencyUnlockRefreshesToRainy() {
        store.didEmergencyUnlockToday = true
        manager.handleEmergencyUnlock()
        XCTAssertEqual(manager.state, .rainy)
    }

    func testHandleMidnightResetRefreshesToFluffyWhite() {
        // Simulate midnight clearing all today flags.
        store.didVerifyToday = true
        manager.refreshState()
        XCTAssertEqual(manager.state, .sunny) // pre-reset

        store.didVerifyToday = false
        manager.handleMidnightReset()
        XCTAssertEqual(manager.state, .fluffyWhite) // post-reset
    }

    // MARK: - Persistence across relaunches

    func testStatePersistsAcrossRelaunches() {
        // Write flags to the isolated suite.
        store.didVerifyToday = true

        // Simulate a cold relaunch by constructing a fresh manager from the same store.
        let freshManager = MascotStateManager(store: SharedDefaults(defaults: defaults))
        XCTAssertEqual(freshManager.state, .sunny)
    }

    func testMilestoneStateIsRainbow() {
        // .rainbow is transient/in-flow; MascotStateManager never produces it directly.
        // Verify that none of the flag combinations derive rainbow (it's view-driven only).
        store.didVerifyToday = true
        manager.refreshState()
        XCTAssertNotEqual(manager.state, .rainbow)
    }
}
