// BudgetPage.swift
// Onboarding 3: Set Your Budget Preview — Sky_App_Workflow.md §S-ONB-04.
// Illustrative only. Reuses SkyProgressRing (~60% filled) with a gentle pulse;
// the pulse freezes under Reduce Motion.

import SwiftUI

struct BudgetPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        OnboardingScaffold(page: .budget) {
            SkyProgressRing(progress: 0.6, accent: SkyColor.mossGreen, lineWidth: 14)
                .frame(width: 150, height: 150)
                .scaleEffect(pulse ? 1.05 : 1.0)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        }
    }
}

#Preview("S-ONB-04 Budget") {
    BudgetPage()
        .background(SkyColor.warmCream)
}
