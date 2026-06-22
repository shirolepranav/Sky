// OnboardingPage.swift
// The five onboarding pages and their copy — Sky_App_Workflow.md §S-ONB-02..06.
//
// Copy lives here (one place) so the screens stay layout-only and the strings
// match the workflow catalog verbatim. Brand voice: friendly but honest, never
// guilt-trip (PRD §7).

import Foundation

/// The ordered onboarding pages, swiped through in `OnboardingView`.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome    // S-ONB-02
    case pickApps   // S-ONB-03
    case budget     // S-ONB-04
    case goOutside  // S-ONB-05
    case ready      // S-ONB-06

    var id: Int { rawValue }

    /// Workflow catalog ID, used in headers/comments and as a stable a11y id base.
    var screenID: String {
        switch self {
        case .welcome: "S-ONB-02"
        case .pickApps: "S-ONB-03"
        case .budget: "S-ONB-04"
        case .goOutside: "S-ONB-05"
        case .ready: "S-ONB-06"
        }
    }

    var title: String {
        switch self {
        case .welcome: "Hi, I'm \(AppBranding.mascotName)."
        case .pickApps: "Pick the apps that pull you in."
        case .budget: "Decide how much is enough."
        case .goOutside: "Touch grass, then come back."
        case .ready: "Your videos stay on your phone."
        }
    }

    /// Body copy. The `ready` page uses `privacyBullets` instead.
    var body: String? {
        switch self {
        case .welcome:
            "I'll help you spend less time scrolling and more time outside. It's going to take a little work — but you've got this."
        case .pickApps:
            "You'll choose from your phone's apps. Sky never sees their names — only you do."
        case .budget:
            "One hour. Two. Three. When you hit your limit, the apps pause until you take a break outside."
        case .goOutside:
            "To unlock the apps, head outside and record a short video. Sky checks the sky, the light, and your steps — all on your phone."
        case .ready:
            nil
        }
    }

    /// Privacy reassurances shown on the final page (S-ONB-06).
    var privacyBullets: [String] {
        guard self == .ready else { return [] }
        return [
            "Verification runs on-device. Videos are deleted right after.",
            "No screen-time data ever leaves your phone.",
            "Your reasons for emergency unlocks stay private to you.",
        ]
    }

    /// CTA title on the final page.
    static let continueButtonTitle = "Let's go"
}
