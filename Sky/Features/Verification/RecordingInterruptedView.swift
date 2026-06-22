// RecordingInterruptedView.swift
// S-VER-08 — Graceful recovery screen shown when AVCaptureSession is
// interrupted by a phone call, audio session takeover, or backgrounding.
// Sky_App_Workflow.md §Part 2 S-VER-08.

import SwiftUI

struct RecordingInterruptedView: View {
    var onTryAgain: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s5) {
                Spacer()

                NimbusView(state: .fluffyWhite, size: 180)

                Text("Recording got interrupted.")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("That's OK. Let's start over when you're ready.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                VStack(spacing: SkySpacing.s3) {
                    SkyPrimaryButton("Try again", action: onTryAgain)
                    SkySecondaryButton("Not now", action: onDismiss)
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.interrupted")
    }
}

#Preview("S-VER-08") {
    RecordingInterruptedView(onTryAgain: {}, onDismiss: {})
}

#Preview("S-VER-08 dark") {
    RecordingInterruptedView(onTryAgain: {}, onDismiss: {})
        .preferredColorScheme(.dark)
}
