// AppBranding.swift
// ALL swappable name / mascot / color / product-ID constants live here.
// PRD §11. Renaming the app or mascot requires editing only this file.
//
// Colors reference the design-system tokens in ColorTokens.swift so there is a
// single source of truth for hex values (mirrors tokens.jsx / DESIGN_SYSTEM.md).

import SwiftUI

enum AppBranding {
    // MARK: Product
    static let appName = "Sky"
    static let appNameTagline = "Touch grass for people who actually want to quit."

    // MARK: Mascot
    static let mascotName = "Nimbus"
    static let mascotPronouns = "they" // "Nimbus is waiting" — keep singular/neutral

    // MARK: Color palette (semantic brand colors; see SkyColor for the full set)
    static let primarySky = SkyColor.primarySky
    static let warmCream = SkyColor.warmCream
    static let mossGreen = SkyColor.mossGreen
    static let coralStreak = SkyColor.coralStreak
    static let cloudGrey = SkyColor.cloudGrey
    static let sunYellow = SkyColor.sunYellow

    // MARK: Subscription product IDs (App Store Connect)
    static let monthlyProductID = "com.sky.pro.monthly"
    static let annualProductID = "com.sky.pro.annual"
    static let lifetimeProductID = "com.sky.pro.lifetime"
    static let founderLifetimeProductID = "com.sky.pro.founder"

    // MARK: About / legal (S-SET-08)
    static let privacyPolicyURL = URL(string: "https://sky.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://sky.app/terms")!
    static let supportEmail = "support@sky.app"
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}
