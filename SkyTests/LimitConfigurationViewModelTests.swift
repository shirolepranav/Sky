// LimitConfigurationViewModelTests.swift
// Lock-time screen (S-CFG-03; DAILY_LOCK_PLAN.md Phase D): persistence, the lock
// days Pro gate, and the option range. Isolated UserDefaults suite.

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
        super.tearDown()
    }

    func testDefaultsToNineEveryDay() {
        let vm = LimitConfigurationViewModel(store: store)
        XCTAssertEqual(vm.lockTimeMinutes, 540)
        XCTAssertEqual(vm.lockWeekdays, Set(1...7))
    }

    func testLockTimePersists() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.lockTimeMinutes = 7 * 60 + 30
        vm.save()
        XCTAssertEqual(LimitConfigurationViewModel(store: store).lockTimeMinutes, 450)
    }

    func testLockTimeIsClampedToTheLatestLegalTime() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.lockTimeMinutes = 23 * 60 + 50
        vm.save()
        XCTAssertEqual(store.lockTimeMinutes, DeviceActivityService.latestLockTimeMinutes)
    }

    func testOptionsStayInsideTheLegalRange() {
        let options = LimitConfigurationViewModel.lockTimeOptions
        XCTAssertTrue(options.contains(540), "the default must be selectable")
        XCTAssertLessThanOrEqual(options.max()!, DeviceActivityService.latestLockTimeMinutes)
    }

    func testOrderedWeekdaysCoverTheWeek() {
        XCTAssertEqual(Set(LimitConfigurationViewModel.orderedWeekdays), Set(1...7))
    }

    // MARK: Lock days (Pro)

    func testFreeUserHitsTheGateAndNothingChanges() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.toggleWeekday(1, isPro: false)
        XCTAssertTrue(vm.showsLockDaysProGate)
        XCTAssertEqual(vm.lockWeekdays, Set(1...7))
    }

    func testProUserCanTakeWeekendsOffAndItPersists() {
        let vm = LimitConfigurationViewModel(store: store)
        vm.toggleWeekday(1, isPro: true)
        vm.toggleWeekday(7, isPro: true)
        vm.save()
        XCTAssertEqual(store.lockWeekdays, Set(2...6))
        XCTAssertFalse(vm.showsLockDaysProGate)
    }

    func testCannotSwitchOffTheLastDay() {
        let vm = LimitConfigurationViewModel(store: store)
        for day in 1...6 { vm.toggleWeekday(day, isPro: true) }
        vm.toggleWeekday(7, isPro: true)
        XCTAssertEqual(vm.lockWeekdays, [7])
    }
}
