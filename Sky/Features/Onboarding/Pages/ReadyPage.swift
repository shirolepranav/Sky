// ReadyPage.swift
// Onboarding 5: Privacy + Ready — Sky_App_Workflow.md §S-ONB-06.
// Reaffirms the privacy invariants and dismisses onboarding. "Let's go" writes
// OnboardingCompleted and continues to permissions (Phase 3). Sunny Nimbus.

import SwiftUI

struct ReadyPage: View {
    /// Invoked when the user taps "Let's go". Writes the completion flag upstream.
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: SkySpacing.s8) {
            Spacer(minLength: SkySpacing.s6)

            NimbusView(state: .sunny, size: 150)
                .accessibilityHidden(true)

            VStack(spacing: SkySpacing.s6) {
                Text(OnboardingPage.ready.title)
                    .skyText(.titleXL)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.title.\(OnboardingPage.ready.screenID)")

                VStack(alignment: .leading, spacing: SkySpacing.s4) {
                    ForEach(OnboardingPage.ready.privacyBullets, id: \.self) { bullet in
                        privacyRow(bullet)
                    }
                }
            }

            Spacer(minLength: SkySpacing.s8)

            SkyPrimaryButton(OnboardingPage.continueButtonTitle, action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
                .accessibilityHint("Continues to permissions")
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func privacyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SkySpacing.s3) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(SkyColor.primarySky)
            Text(text)
                .skyText(.body, color: SkyColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("S-ONB-06 Ready") {
    ReadyPage(onContinue: {})
        .background(SkyColor.warmCream)
}
