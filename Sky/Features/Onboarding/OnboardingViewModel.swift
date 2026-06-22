// OnboardingViewModel.swift
// Owns onboarding state — the `OnboardingCompleted` flag and current page.
// Sky_App_Workflow.md §S-ONB-06 (writes the flag) / §0.2 (read at cold launch).
//
// The flag lives in `UserDefaults.standard` (per the Roadmap Phase 2 spec — not
// the App Group container, which is for cross-process shared state). UserDefaults
// is injectable so unit tests can use an isolated suite instead of touching the
// real defaults.

import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    static let onboardingCompletedKey = "OnboardingCompleted"

    private let defaults: UserDefaults

    /// Drives the page `TabView` selection and the page indicator.
    @Published var currentPage: OnboardingPage = .welcome

    /// Republished so observers (the coordinator) re-evaluate routing on change.
    @Published private(set) var isOnboardingCompleted: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isOnboardingCompleted = defaults.bool(forKey: Self.onboardingCompletedKey)
    }

    /// Persist completion (S-ONB-06 "Let's go") so onboarding is skipped on
    /// subsequent launches.
    func completeOnboarding() {
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        isOnboardingCompleted = true
    }

    /// Clear the flag — used only by UI tests via a launch argument.
    func resetForTesting() {
        defaults.removeObject(forKey: Self.onboardingCompletedKey)
        isOnboardingCompleted = false
        currentPage = .welcome
    }
}
