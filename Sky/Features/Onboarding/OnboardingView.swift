// OnboardingView.swift
// Onboarding host — the 5-screen swipeable sequence (Sky_App_Workflow.md
// §S-ONB-02..06, §0.1 nav model). A paged TabView with custom dots; the final
// page swaps the dots for the "Let's go" CTA, which completes onboarding.

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            SkyColor.warmCream.ignoresSafeArea()

            TabView(selection: $viewModel.currentPage) {
                WelcomePage().tag(OnboardingPage.welcome)
                PickAppsPage().tag(OnboardingPage.pickApps)
                BudgetPage().tag(OnboardingPage.budget)
                GoOutsidePage().tag(OnboardingPage.goOutside)
                ReadyPage(onContinue: viewModel.completeOnboarding).tag(OnboardingPage.ready)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Pages 1–4 show the dots; the final page shows its own CTA instead.
            if viewModel.currentPage != .ready {
                PageIndicator(
                    pageCount: OnboardingPage.allCases.count,
                    currentIndex: viewModel.currentPage.rawValue
                )
                .padding(.bottom, SkyLayout.bottomSafeArea)
            }
        }
        .accessibilityIdentifier("onboarding.host")
    }
}

#Preview("Onboarding host") {
    OnboardingView(viewModel: OnboardingViewModel())
}
