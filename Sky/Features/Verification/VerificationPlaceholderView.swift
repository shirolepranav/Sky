// VerificationPlaceholderView.swift
// Destination for the sky://verify deep link (S-SHIELD-02 → S-VER-01).
//
// Phase 6 stub: shows Nimbus and holding copy so the deep-link round-trip is
// testable end-to-end. Phase 7 replaces this entirely with the AVCaptureSession
// recording flow, 30-second countdown, and on-screen prompts.

import SwiftUI

struct VerificationPlaceholderView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s8) {
                NimbusView(state: .cloudyGrey, size: 160)
                    .padding(.bottom, SkySpacing.s2)

                Text("Go outside to unlock")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("Hold up your phone and record 30 seconds of open sky.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                SkySecondaryButton("Back") { onDismiss() }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
            .padding(.top, SkySpacing.s10)
        }
        .accessibilityIdentifier("verification.placeholder")
    }
}

#Preview("Verification placeholder") {
    VerificationPlaceholderView(onDismiss: {})
}
