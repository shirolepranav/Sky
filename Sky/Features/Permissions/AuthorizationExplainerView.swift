// AuthorizationExplainerView.swift
// S-PERM-01 · Family Controls Authorization Explainer (Sky_App_Workflow.md
// §S-PERM-01). Justifies the Screen Time permission, then triggers the iOS
// system prompt. Routes to S-CFG-01 on grant, S-PERM-02 on denial.

import SwiftUI

struct AuthorizationExplainerView: View {
    @ObservedObject var familyControls: FamilyControlsService
    /// Called after the system prompt resolves to approved.
    let onApproved: () -> Void
    /// Called after the system prompt resolves to anything other than approved.
    let onDenied: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: SkySpacing.s8) {
            Spacer(minLength: SkySpacing.s6)

            NimbusView(state: .fluffyWhite, size: 150)
                .accessibilityHidden(true)

            VStack(spacing: SkySpacing.s6) {
                Text("Sky needs Screen Time access.")
                    .skyText(.titleXL)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("perm.title.S-PERM-01")

                Text("This is the permission that lets Sky pause apps when you hit your daily limit. We use it for your phone only — never for monitoring anyone else.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: SkySpacing.s8)

            Button(action: requestAuthorization) {
                if isRequesting {
                    ProgressView().tint(.white)
                } else {
                    Text("Allow Screen Time access")
                }
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(isRequesting)
            .accessibilityIdentifier("perm.allow")
            .accessibilityHint("Opens the system Screen Time prompt")
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SkyColor.surface.ignoresSafeArea())
        // Rare reinstall where the OS grant already exists: skip straight ahead.
        .task {
            familyControls.refreshStatus()
            if familyControls.isApproved { onApproved() }
        }
    }

    private func requestAuthorization() {
        Task {
            isRequesting = true
            await familyControls.requestAuthorization()
            isRequesting = false
            if familyControls.isApproved { onApproved() } else { onDenied() }
        }
    }
}

#Preview("S-PERM-01 Explainer") {
    AuthorizationExplainerView(
        familyControls: FamilyControlsService(),
        onApproved: {},
        onDenied: {}
    )
}
