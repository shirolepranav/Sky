// SetupFlowView.swift
// Post-onboarding setup host (Sky_App_Workflow.md §0.1 PermissionHost). Sequences
// the setup gates in a NavigationStack:
//   S-PERM-01 (explainer) → (deny) S-PERM-02 → (grant) S-CFG-01 → S-CFG-03 → done.
//
// Auto-recovery: if the user grants Screen Time in Settings and returns, the
// published auth status flips (refreshed on scenePhase → active by SkyApp) and
// this view advances to S-CFG-01 without user action.

import SwiftUI

struct SetupFlowView: View {
    @ObservedObject var familyControls: FamilyControlsService
    /// Invoked when setup completes (authorized + ≥1 app selected + limit saved).
    let onComplete: () -> Void

    @StateObject private var selectionViewModel = AppSelectionViewModel()
    @StateObject private var limitViewModel = LimitConfigurationViewModel()
    @State private var path: [SetupStep] = []

    enum SetupStep: Hashable {
        case denied             // S-PERM-02
        case appSelection       // S-CFG-01
        case limitConfiguration // S-CFG-03
    }

    var body: some View {
        NavigationStack(path: $path) {
            AuthorizationExplainerView(
                familyControls: familyControls,
                onApproved: { goToAppSelection() },
                onDenied: { path = [.denied] }
            )
            .navigationDestination(for: SetupStep.self) { step in
                switch step {
                case .denied:
                    AuthorizationDeniedView(onTryAgain: { path = [] })
                case .appSelection:
                    AppSelectionView(
                        viewModel: selectionViewModel,
                        onContinue: { path.append(.limitConfiguration) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .limitConfiguration:
                    LimitConfigurationView(viewModel: limitViewModel, onSave: onComplete)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        // Auto-recover when the grant lands (e.g. user returned from Settings).
        .onChange(of: familyControls.status) { _, _ in
            if familyControls.isApproved { goToAppSelection() }
        }
    }

    private func goToAppSelection() {
        if path != [.appSelection] { path = [.appSelection] }
    }
}
