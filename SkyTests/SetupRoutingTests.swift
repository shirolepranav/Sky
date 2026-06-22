// SetupRoutingTests.swift
// Phase 3 automated tests (Roadmap Phase 3 → Automated Tests). Exercises the
// AppCoordinator's extended route table (§0.2): onboarding → setup → main, and
// the auto-recovery re-route when the Family Controls status changes.

import XCTest
import FamilyControls
@testable import Sky

@MainActor
final class SetupRoutingTests: XCTestCase {
    private let suiteName = "SetupRoutingTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: OnboardingViewModel.onboardingCompletedKey)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeCoordinator(
        status: AuthorizationStatus,
        hasSelection: Bool
    ) -> (AppCoordinator, FamilyControlsService, AuthorizationStub) {
        let vm = OnboardingViewModel(defaults: defaults)
        let stub = AuthorizationStub(status: status)
        let service = FamilyControlsService(center: stub)
        let coordinator = AppCoordinator(
            onboarding: vm,
            familyControls: service,
            selectionExists: { hasSelection }
        )
        return (coordinator, service, stub)
    }

    /// Onboarding done but Screen Time not granted → setup gate.
    func testUnauthorizedRoutesToSetup() {
        let (coordinator, _, _) = makeCoordinator(status: .notDetermined, hasSelection: false)
        XCTAssertEqual(coordinator.route, .setup)
    }

    /// Authorized but no apps chosen → still setup (S-CFG-01).
    func testAuthorizedNoSelectionRoutesToSetup() {
        let (coordinator, _, _) = makeCoordinator(status: .approved, hasSelection: false)
        XCTAssertEqual(coordinator.route, .setup)
    }

    /// Authorized + apps chosen → main.
    func testFullyConfiguredRoutesToMain() {
        let (coordinator, _, _) = makeCoordinator(status: .approved, hasSelection: true)
        XCTAssertEqual(coordinator.route, .main)
    }

    /// Granting Screen Time after the fact re-routes out of the explainer once a
    /// selection already exists (auto-recovery / cold-launch consistency).
    func testStatusChangeReroutes() {
        let (coordinator, service, stub) = makeCoordinator(status: .denied, hasSelection: true)
        XCTAssertEqual(coordinator.route, .setup)

        stub.authorizationStatus = .approved
        service.refreshStatus()  // publishes → coordinator recomputes

        XCTAssertEqual(coordinator.route, .main)
    }
}
