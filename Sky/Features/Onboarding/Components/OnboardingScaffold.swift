// OnboardingScaffold.swift
// Shared layout for the standard onboarding pages (illustration + title + body)
// — Sky_App_Workflow.md §S-ONB-02..05. Keeps the four content pages visually
// consistent: a top illustration zone, then title and body, vertically centered
// with room for the page indicator the host pins below.

import SwiftUI

/// Standard onboarding page: an illustration on top, then title + optional body.
/// `illustration` is decorative and hidden from VoiceOver; the copy is the page.
struct OnboardingScaffold<Illustration: View>: View {
    let page: OnboardingPage
    @ViewBuilder var illustration: () -> Illustration

    var body: some View {
        VStack(spacing: SkySpacing.s8) {
            Spacer(minLength: SkySpacing.s6)

            illustration()
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            VStack(spacing: SkySpacing.s4) {
                Text(page.title)
                    .skyText(.titleXL)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.title.\(page.screenID)")

                if let body = page.body {
                    Text(body)
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Spacer(minLength: SkySpacing.s10)
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
