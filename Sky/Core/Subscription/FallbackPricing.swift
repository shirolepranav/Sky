// FallbackPricing.swift
// Display-only fallback price for the paywall. When StoreKit fails to return
// products (no network, StoreKit config not applied, App Store Connect not yet
// populated), the paywall renders this instead of spinning forever.
//
// SINGLE SOURCE OF TRUTH for the fallback string — it mirrors the price declared
// in `Sky/Resources/Sky.storekit` and configured in App Store Connect. It is
// never used to complete a purchase (purchases always run against a real
// `StoreKit.Product`); it only keeps the UI legible when live metadata is absent.
//
// Sky_App_Workflow.md §Group G S-PAY-01; Roadmap Phase 14.

import Foundation

/// A pre-formatted price to display when a live `Product` is unavailable.
struct FallbackPrice: Equatable {
    /// Localized-looking display string, e.g. "$19.99".
    let displayPrice: String
}

enum FallbackPricing {

    /// Returns the fallback price for the Sky Pro product ID, or nil if unknown.
    /// Keep in lock-step with `Sky.storekit` / App Store Connect.
    ///
    /// This is the US price only — real regional pricing always comes from
    /// StoreKit. This string is a last resort for when no metadata loaded.
    static func price(for productID: String) -> FallbackPrice? {
        guard productID == AppBranding.lifetimeProductID else { return nil }
        return FallbackPrice(displayPrice: "$19.99")
    }
}
