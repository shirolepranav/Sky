// VerificationFailureView.swift
// S-VER-07 — Shows failure-specific copy with friendly framing and next steps.
// After 3 consecutive failures, surfaces a troubleshooting tip.
// Sky_App_Workflow.md §Part 2 S-VER-07.

import SwiftUI

struct VerificationFailureView: View {
    let reason: FailureReason
    let consecutiveFailures: Int
    var onTryAgain: () -> Void
    var onEmergency: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SkyColor.surface.ignoresSafeArea()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SkyColor.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, SkySpacing.s5)
            .padding(.trailing, SkySpacing.s4)
            .accessibilityLabel("Close")

            // Main content
            VStack(spacing: SkySpacing.s5) {
                Spacer()

                NimbusView(state: .rainy, size: 180)

                Text(reason.title)
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text(reason.body)
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                if consecutiveFailures >= 3 {
                    troubleshootingTip
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                Spacer()

                VStack(spacing: SkySpacing.s3) {
                    SkyPrimaryButton("Try again", action: onTryAgain)
                    SkySecondaryButton("I can't go outside", action: onEmergency)
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.failure")
    }

    private var troubleshootingTip: some View {
        SkyCard {
            HStack(spacing: SkySpacing.s3) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 17))
                    .foregroundColor(SkyColor.sunYellow)
                Text("Trouble verifying? Make sure you're outside with open sky visible.")
                    .skyText(.bodyS, color: SkyColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("S-VER-07 — GPS spoofing") {
    VerificationFailureView(
        reason: .gpsSpoofingDetected,
        consecutiveFailures: 0,
        onTryAgain: {},
        onEmergency: {},
        onClose: {}
    )
}

#Preview("S-VER-07 — tip shown (3 failures)") {
    VerificationFailureView(
        reason: .notBrightEnough,
        consecutiveFailures: 3,
        onTryAgain: {},
        onEmergency: {},
        onClose: {}
    )
}

#Preview("S-VER-07 — no sky") {
    VerificationFailureView(
        reason: .noSkyVisible,
        consecutiveFailures: 1,
        onTryAgain: {},
        onEmergency: {},
        onClose: {}
    )
}
