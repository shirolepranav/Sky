// GoOutsidePage.swift
// Onboarding 4: Go Outside Preview — Sky_App_Workflow.md §S-ONB-05.
// Sets expectations for verification without scaring the user: a stylized phone
// pointing at a sun + cloud. Reuses SunIcon and NimbusMini (no new assets).

import SwiftUI

struct GoOutsidePage: View {
    var body: some View {
        OnboardingScaffold(page: .goOutside) {
            ZStack(alignment: .topTrailing) {
                // Sky scene the phone is "pointed at".
                HStack(alignment: .top, spacing: SkySpacing.s4) {
                    SunIcon(size: 56)
                    NimbusMini(state: .fluffyWhite, size: 96)
                        .frame(height: 96)
                }
                .padding(.trailing, SkySpacing.s10)
                .padding(.bottom, SkySpacing.s10)

                // Phone in the foreground, lower-left, framing the scene.
                StylizedPhone {
                    SunIcon(size: 28)
                }
                .scaleEffect(0.7)
                .offset(x: -SkySpacing.s10, y: SkySpacing.s6)
            }
            .frame(maxWidth: 280)
        }
    }
}

#Preview("S-ONB-05 Go Outside") {
    GoOutsidePage()
        .background(SkyColor.warmCream)
}
