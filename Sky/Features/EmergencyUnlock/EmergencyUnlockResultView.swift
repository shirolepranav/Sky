// EmergencyUnlockResultView.swift
// S-EMG-03 — Confirmation screen shown after the emergency unlock completes.
// Displays a rainy Nimbus, confirms apps are unlocked, and optionally shows a
// chip with the streak count that just ended (omitted when streak was already 0).
// Sky_App_Workflow.md S-EMG-03; Roadmap Phase 13.

import SwiftUI

struct EmergencyUnlockResultView: View {
    /// The streak value captured *before* handleEmergencyUnlock() was called.
    let previousStreak: Int
    var onDone: () -> Void

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                NimbusView(state: .rainy, size: 180)
                    .padding(.bottom, SkySpacing.s6)
                    .accessibilityHidden(true)

                Text("Apps unlocked.")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, SkySpacing.s4)

                Text("Try again tomorrow. Nimbus will be here.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                if previousStreak > 0 {
                    SkyCard {
                        HStack(spacing: SkySpacing.s3) {
                            FlameIcon(color: SkyColor.coralStreak, size: 20)
                            Text("Your \(previousStreak)-day streak ended.")
                                .skyText(.bodyS, color: SkyColor.inkSoft)
                        }
                    }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.top, SkySpacing.s6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Your \(previousStreak)-day streak ended.")
                }

                Spacer()

                SkyPrimaryButton("Done", action: onDone)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("emergency.result")
    }
}

#Preview("S-EMG-03 — streak ended") {
    EmergencyUnlockResultView(previousStreak: 7, onDone: {})
}

#Preview("S-EMG-03 — no streak") {
    EmergencyUnlockResultView(previousStreak: 0, onDone: {})
}
