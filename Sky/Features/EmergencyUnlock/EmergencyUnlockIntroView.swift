// EmergencyUnlockIntroView.swift
// S-EMG-01 — Soft on-ramp before the typed-reason screen. Shows a cloudyGrey
// Nimbus, explains the streak consequence, and offers to route back to
// verification instead of proceeding.
// Sky_App_Workflow.md S-EMG-01; Roadmap Phase 13.

import SwiftUI

struct EmergencyUnlockIntroView: View {
    var onContinue:   () -> Void
    var onTryOutside: () -> Void

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                NimbusView(state: .cloudyGrey, size: 160)
                    .padding(.bottom, SkySpacing.s6)
                    .accessibilityHidden(true)

                Text("Are you sure?")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, SkySpacing.s4)

                Text("If you can't go outside right now, Nimbus understands — life happens. But using this resets your streak. If you'd rather try outside again, that's still an option.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                VStack(spacing: SkySpacing.s3) {
                    SkyPrimaryButton("Yes, I need to unlock", action: onContinue)
                        .accessibilityHint("Proceeds to the typed-reason screen. Your streak will reset.")
                    SkySecondaryButton("Try outside again", action: onTryOutside)
                        .accessibilityHint("Returns to the outdoor video verification")
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("emergency.intro")
    }
}

#Preview("S-EMG-01") {
    EmergencyUnlockIntroView(onContinue: {}, onTryOutside: {})
}
