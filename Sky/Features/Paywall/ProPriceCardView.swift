// ProPriceCardView.swift
// The single price card inside PaywallView (S-PAY-01). Sky Pro is one
// non-consumable one-time purchase, so this card carries no billing period,
// no "Best Value" ribbon, and no trial badge — there is nothing to compare it
// against and nothing that renews.
// Sky_App_Workflow.md §Group G S-PAY-01; Roadmap Phase 14.
//
// Sky Pop: the whole card is one tap target, so it wears the outline + hard
// shadow (SkyPopCardButtonStyle) and sinks on press.

import StoreKit
import SwiftUI

struct ProPriceCardView: View {
    let product: Product?
    var isLoading: Bool = false
    /// Display-only price used when no live `product` is available (StoreKit absent).
    var fallback: FallbackPrice? = nil
    let action: () -> Void

    private var priceText: String {
        product?.displayPrice ?? fallback?.displayPrice ?? "—"
    }

    /// True when there is nothing to show a price for — no live product and no fallback.
    private var hasNoPrice: Bool {
        product == nil && fallback == nil
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SkySpacing.s2) {
                Text("LIFETIME")
                    .skyText(.overline, color: SkyColor.inkMuted)

                if isLoading {
                    ProgressView()
                        .frame(height: 48)
                } else {
                    Text(priceText)
                        .skyText(.numeral, color: SkyColor.ink)
                }

                Text("Pay once. No subscription, ever.")
                    .skyText(.bodyS, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SkySpacing.s6)
            .padding(.horizontal, SkySpacing.s5)
        }
        .buttonStyle(SkyPopCardButtonStyle(radius: SkyRadius.card))
        .disabled(isLoading || hasNoPrice)
        .accessibilityLabel("Sky Pro lifetime, \(priceText). One-time purchase.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Pro price card") {
    VStack(spacing: SkySpacing.s6) {
        ProPriceCardView(
            product: nil,
            fallback: FallbackPricing.price(for: AppBranding.lifetimeProductID),
            action: {}
        )
        ProPriceCardView(product: nil, isLoading: true, action: {})
    }
    .padding()
    .background(SkyColor.surface)
}

#Preview("Pro price card — dark") {
    ProPriceCardView(
        product: nil,
        fallback: FallbackPricing.price(for: AppBranding.lifetimeProductID),
        action: {}
    )
    .padding()
    .background(SkyColor.surface)
    .preferredColorScheme(.dark)
}
