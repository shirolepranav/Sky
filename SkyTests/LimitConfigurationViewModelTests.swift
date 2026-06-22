// LimitConfigurationViewModelTests.swift
// Phase 4 automated tests (Roadmap Phase 4 → Automated Tests). Verifies limit
// persistence, mode-switching value preservation, and the 15–240 minute clamp.
// Uses an isolated UserDefaults suite so tests never touch the App Group.

import XCTest
@testable import Sky

@MainActor
final class LimitConfigurationViewModelTests: XCTestCase {
    private let suiteName = "LimitConfigurationViewModelTests"
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

    // MARK: testCombinedLimitPersists

    /// Setting combined mode and 1 h limit, then saving, should round-trip through
    /// SharedDefaults so a freshly-created ViewModel reads the same values back.
    func testCombinedLimitPersists() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.limitMode = .combined
        vm.combinedLimitSeconds = 3600
        vm.save()

        let restored = LimitConfigurationViewModel(store: store)
        XCTAssertEqual(restored.limitMode, .combined)
        XCTAssertEqual(restored.combinedLimitSeconds, 3600)
    }

    // MARK: testPerAppLimitsPersist

    /// Switching to per-app mode and saving should persist the mode flag; the
    /// per-app minutes map (empty here — no apps in the test store) round-trips
    /// cleanly without crash or data loss.
    func testPerAppLimitsPersist() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.limitMode = .perApp
        vm.save()

        let restored = LimitConfigurationViewModel(store: store)
        XCTAssertEqual(restored.limitMode, .perApp)
        // No app tokens in the isolated store, so perAppMinutes stays empty.
        XCTAssertTrue(restored.perAppMinutes.isEmpty)
    }

    // MARK: testSwitchingModesPreservesPreviousValues

    /// Toggling between modes must not wipe the other mode's values — the spec
    /// says "switching modes preserves previously entered values" (S-CFG-03).
    func testSwitchingModesPreservesPreviousValues() {
        let vm = LimitConfigurationViewModel(store: store)

        // Set a non-default combined limit, then switch to per-app and back.
        vm.combinedLimitSeconds = 3600
        vm.limitMode = .perApp
        vm.limitMode = .combined
        XCTAssertEqual(vm.combinedLimitSeconds, 3600,
                       "Combined limit should survive a round-trip through per-app mode")

        // Switch to per-app and then back to combined — combined still intact.
        vm.limitMode = .perApp
        vm.limitMode = .combined
        XCTAssertEqual(vm.combinedLimitSeconds, 3600)
    }

    // MARK: testMinimumLimitIs15Minutes

    /// The clamping helper enforces 15 minutes as the floor — mirrors what the
    /// Stepper's `in: 15...240` range enforces at the UI level.
    func testMinimumLimitIs15Minutes() {
        let vm = LimitConfigurationViewModel(store: store)
        XCTAssertEqual(vm.clampedMinutes(0),   15)
        XCTAssertEqual(vm.clampedMinutes(-60), 15)
        XCTAssertEqual(vm.clampedMinutes(14),  15)
        XCTAssertEqual(vm.clampedMinutes(15),  15) // exact boundary
    }

    // MARK: testMaximumLimitIs4Hours

    /// The clamping helper enforces 240 minutes (4 hours) as the ceiling.
    func testMaximumLimitIs4Hours() {
        let vm = LimitConfigurationViewModel(store: store)
        XCTAssertEqual(vm.clampedMinutes(500), 240)
        XCTAssertEqual(vm.clampedMinutes(241), 240)
        XCTAssertEqual(vm.clampedMinutes(240), 240) // exact boundary
        XCTAssertEqual(vm.clampedMinutes(239), 239) // just inside
    }
}
