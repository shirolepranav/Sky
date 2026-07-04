// TrialStartConfirmationView.swift
// S-PAY-04 · Trial Start Confirmation — shown after a successful annual
// purchase that includes a 7-day free trial.
// Sky_App_Workflow.md §Group G S-PAY-04; Roadmap Phase 14.

import SwiftUI

struct TrialStartConfirmationView: View {
    let trialEndDate: Date
    let onDone: () -> Void

    private var formattedEndDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: trialEndDate)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SkyColor.surface, SkyColor.warmCream],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                NimbusView(state: .sunny, size: 160)

                VStack(spacing: SkySpacing.s4) {
                    Text("7 days free, on us.")
                        .skyText(.titleL)
                        .multilineTextAlignment(.center)

                    Text("You're on Sky Pro Annual. Your trial ends \(formattedEndDate). You can cancel anytime in App Store settings.")
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                Spacer()

                SkyPrimaryButton("Got it", action: onDone)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("trialConfirmation")
    }
}

#Preview("S-PAY-04 Trial start") {
    TrialStartConfirmationView(
        trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        onDone: {}
    )
}
