// InContextProGateView.swift
// S-PAY-05 · In-context Pro gate — a compact mid-screen sheet shown when a
// free user taps a Pro-only feature inline (per-app limits, weekly insights,
// pause, streak warning notification).
// Sky_App_Workflow.md §Group G S-PAY-05; Roadmap Phase 14.

import SwiftUI

struct InContextProGateView: View {
    /// Feature-specific headline, e.g. "Per-app limits is a Pro feature."
    let featureTitle: String
    let onSeePro: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: SkySpacing.s5) {
            Capsule()
                .fill(SkyColor.inkDisabled)
                .frame(width: 36, height: 4)
                .padding(.top, SkySpacing.s3)

            NimbusView(state: .fluffyWhite, size: 80)
                .padding(.top, SkySpacing.s2)

            VStack(spacing: SkySpacing.s3) {
                Text(featureTitle)
                    .skyText(.titleM)
                    .multilineTextAlignment(.center)

                Text("Sky Pro unlocks per-app limits, the full insight set, all badges, and supports development.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SkyLayout.screenMargin)

            VStack(spacing: SkySpacing.s3) {
                SkyPrimaryButton("See Pro", action: onSeePro)
                SkySecondaryButton("Maybe later", action: onDismiss)
            }
            .padding(.horizontal, SkyLayout.screenMargin)
            .padding(.bottom, SkySpacing.s6)
        }
        .frame(maxWidth: .infinity)
        .background(SkyColor.surface)
        .accessibilityIdentifier("proGate.sheet")
    }
}

#Preview("S-PAY-05 Per-app gate") {
    Color.black.opacity(0.3).ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            InContextProGateView(
                featureTitle: "Per-app limits is a Pro feature.",
                onSeePro: {},
                onDismiss: {}
            )
            .presentationDetents([.medium])
        }
}

#Preview("S-PAY-05 Weekly insights gate") {
    Color.black.opacity(0.3).ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            InContextProGateView(
                featureTitle: "Weekly insights is a Pro feature.",
                onSeePro: {},
                onDismiss: {}
            )
            .presentationDetents([.medium])
        }
}
