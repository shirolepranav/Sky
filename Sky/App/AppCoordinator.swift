// AppCoordinator.swift
// Top-level routing state for Sky (Technical Spec §5, Sky_App_Workflow.md §0.1/§0.2).
//
// Phase 3: extends the route table with the post-onboarding setup gate. A
// completed-onboarding user who hasn't authorized Screen Time *or* hasn't picked
// any apps is routed into the SetupFlow (S-PERM-01 → S-CFG-01); only a fully
// configured user reaches `.main`. Routing is recomputed when the onboarding flag
// flips, when the Family Controls status changes, and on every foreground (the
// user may have changed the permission in Settings — SkyApp drives that).

import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    /// The top-level destinations Sky can show (Sky_App_Workflow.md §0.2).
    enum Route: Equatable {
        case onboarding   // S-ONB-02..06
        case setup        // S-PERM-01 → S-CFG-01 (post-onboarding gate)
        case main         // temporary placeholder; main tab bar later
    }

    @Published private(set) var route: Route = .onboarding

    let onboarding: OnboardingViewModel
    let familyControls: FamilyControlsService

    /// Whether a valid non-empty app selection is persisted. Injectable because a
    /// real `FamilyActivitySelection` can't be fabricated in unit tests (opaque
    /// tokens); defaults to reading the App Group.
    private let selectionExists: () -> Bool
    private var cancellables = Set<AnyCancellable>()

    // `familyControls` has no default: `FamilyControlsService()` is main-actor
    // isolated, and default arguments are evaluated in a nonisolated context.
    // Construct it at the (main-actor) call site instead.
    init(
        onboarding: OnboardingViewModel,
        familyControls: FamilyControlsService,
        selectionExists: @escaping () -> Bool = { SharedDefaults().hasSelection }
    ) {
        self.onboarding = onboarding
        self.familyControls = familyControls
        self.selectionExists = selectionExists
        recomputeRoute()

        // Re-route when onboarding completes or the Screen Time grant changes.
        onboarding.$isOnboardingCompleted
            .sink { [weak self] _ in self?.recomputeRoute() }
            .store(in: &cancellables)
        familyControls.$status
            .sink { [weak self] _ in self?.recomputeRoute() }
            .store(in: &cancellables)
    }

    /// Resolve the destination from current state (§0.2 cold-launch route table).
    /// Also called by SkyApp on foreground after refreshing the auth status.
    func recomputeRoute() {
        let newRoute: Route
        if !onboarding.isOnboardingCompleted {
            newRoute = .onboarding
        } else if familyControls.isApproved && selectionExists() {
            newRoute = .main
        } else {
            newRoute = .setup
        }
        if newRoute != route { route = newRoute }
    }
}
