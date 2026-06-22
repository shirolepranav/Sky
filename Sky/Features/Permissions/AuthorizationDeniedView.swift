// AuthorizationDeniedView.swift
// S-PERM-02 · Family Controls Denied (Sky_App_Workflow.md §S-PERM-02). Recover
// from a denied Screen Time grant by deep-linking to Settings. If the user fixes
// it there and returns, the host auto-advances to S-CFG-01 (the published auth
// status flips on the foreground refresh) — no action needed here.

import SwiftUI

struct AuthorizationDeniedView: View {
    /// Pop back to S-PERM-01 to re-trigger the prompt.
    let onTryAgain: () -> Void

    var body: some View {
        VStack(spacing: SkySpacing.s8) {
            Spacer(minLength: SkySpacing.s6)

            NimbusView(state: .cloudyGrey, size: 150)
                .accessibilityHidden(true)

            VStack(spacing: SkySpacing.s6) {
                Text("Sky needs that permission.")
                    .skyText(.titleXL)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("perm.title.S-PERM-02")

                Text("Without Screen Time access, Sky can't pause apps for you. Open Settings → Screen Time and toggle Sky on, then come back.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: SkySpacing.s8)

            VStack(spacing: SkySpacing.s3) {
                SkyPrimaryButton("Open Settings", action: openSettings)
                    .accessibilityIdentifier("perm.openSettings")
                SkySecondaryButton("Try again", action: onTryAgain)
                    .accessibilityIdentifier("perm.tryAgain")
            }
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("S-PERM-02 Denied") {
    AuthorizationDeniedView(onTryAgain: {})
}
