// WelcomePage.swift
// Onboarding 1: Welcome — Sky_App_Workflow.md §S-ONB-02.
// Greets the user and introduces Nimbus. Fluffy-white (idle, friendly) mascot
// with its built-in idle bob; copy sets a warm, honest tone (PRD §7).

import SwiftUI

struct WelcomePage: View {
    var body: some View {
        OnboardingScaffold(page: .welcome) {
            NimbusView(state: .fluffyWhite, size: 200)
        }
    }
}

#Preview("S-ONB-02 Welcome") {
    WelcomePage()
        .background(SkyColor.warmCream)
}
