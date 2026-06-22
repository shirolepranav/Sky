// OnboardingViewModelTests.swift
// Phase 2 automated tests (Roadmap Phase 2 → Automated Tests).
// Verifies the OnboardingCompleted flag drives routing: first launch shows
// onboarding, completing it persists the flag, and a completed flag routes to
// the main destination. Uses an isolated UserDefaults suite so tests never touch
// the real `.standard` defaults.

import XCTest
@testable import Sky

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private let suiteName = "OnboardingViewModelTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// Fresh install (no flag) → onboarding not completed → coordinator routes to onboarding.
    func testFirstLaunchShowsOnboarding() {
        let vm = OnboardingViewModel(defaults: defaults)
        XCTAssertFalse(vm.isOnboardingCompleted)

        let coordinator = AppCoordinator(
            onboarding: vm,
            familyControls: FamilyControlsService(center: AuthorizationStub()),
            selectionExists: { false }
        )
        XCTAssertEqual(coordinator.route, .onboarding)
    }

    /// Completing onboarding sets and persists the flag.
    func testCompletingOnboardingSetsFlag() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.completeOnboarding()

        XCTAssertTrue(vm.isOnboardingCompleted)
        XCTAssertTrue(defaults.bool(forKey: OnboardingViewModel.onboardingCompletedKey))

        // A fresh view model reading the same defaults sees the persisted flag.
        let reopened = OnboardingViewModel(defaults: defaults)
        XCTAssertTrue(reopened.isOnboardingCompleted)
    }

    /// A pre-seeded completed flag routes past onboarding. Since Phase 3, an
    /// unauthorized / unconfigured user lands on the setup gate, not main.
    func testCompletedOnboardingRoutesToSetup() {
        defaults.set(true, forKey: OnboardingViewModel.onboardingCompletedKey)

        let vm = OnboardingViewModel(defaults: defaults)
        let coordinator = AppCoordinator(
            onboarding: vm,
            familyControls: FamilyControlsService(center: AuthorizationStub(status: .notDetermined)),
            selectionExists: { false }
        )
        XCTAssertEqual(coordinator.route, .setup)
    }

    /// Completing onboarding while live re-routes the coordinator out of onboarding
    /// into the setup gate.
    func testCompletingOnboardingReroutesCoordinator() {
        let vm = OnboardingViewModel(defaults: defaults)
        let coordinator = AppCoordinator(
            onboarding: vm,
            familyControls: FamilyControlsService(center: AuthorizationStub(status: .notDetermined)),
            selectionExists: { false }
        )
        XCTAssertEqual(coordinator.route, .onboarding)

        vm.completeOnboarding()
        XCTAssertEqual(coordinator.route, .setup)
    }
}
