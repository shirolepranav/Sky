// FounderCardView.swift
// Founder's Lifetime tier card for PaywallView (S-PAY-01).
// Shows "only N seats left" when available; shows the S-PAY-02 sold-out
// variant when seatsRemaining reaches 0.
// Sky_App_Workflow.md §Group G S-PAY-01/S-PAY-02; Roadmap Phase 14.

import StoreKit
import SwiftUI

struct FounderCardView: View {
    let product: Product?
    let seatsRemaining: Int
    var isLoading: Bool = false
    let action: () -> Void

    private var isSoldOut: Bool { seatsRemaining <= 0 }

    private var priceText: String {
        product?.displayPrice ?? "$39"
    }

    var body: some View {
        if isSoldOut {
            soldOutCard
        } else {
            availableCard
        }
    }

    // MARK: - Available

    private var availableCard: some View {
        Button(action: action) {
            HStack(spacing: SkySpacing.s4) {
                VStack(alignment: .leading, spacing: SkySpacing.s2) {
                    Text("Founder's Lifetime")
                        .skyText(.headline, color: SkyColor.ink)

                    Text("One-time purchase. Forever.")
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: SkySpacing.s1) {
                    if isLoading || product == nil {
                        ProgressView()
                    } else {
                        Text(priceText)
                            .skyText(.titleM, color: SkyColor.ink)
                    }

                    if !isSoldOut {
                        HStack(spacing: SkySpacing.s1) {
                            Circle()
                                .fill(SkyColor.coralStreak)
                                .frame(width: 6, height: 6)
                            Text("only \(seatsRemaining) left")
                                .skyText(.caption, color: SkyColor.coralStreak)
                        }
                    }
                }
            }
            .padding(SkySpacing.s5)
            .background(SkyColor.warmCream, in: RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous)
                    .strokeBorder(SkyColor.sunYellowDeep.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading || product == nil)
        .accessibilityLabel("Founder's Lifetime, \(priceText), only \(seatsRemaining) seats left")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Sold out (S-PAY-02 variant)

    private var soldOutCard: some View {
        VStack(alignment: .leading, spacing: SkySpacing.s2) {
            Text("Founder's seats are gone.")
                .skyText(.headline, color: SkyColor.inkMuted)

            Text("All 500 founder spots have been claimed. The Lifetime tier is still available.")
                .skyText(.bodyS, color: SkyColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SkySpacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SkyColor.surfaceCard, in: RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous)
                .strokeBorder(SkyColor.divider, lineWidth: 1)
        )
        .accessibilityLabel("Founder's Lifetime is sold out. The Lifetime tier is still available.")
    }
}

#Preview("Founder card — available") {
    FounderCardView(product: nil, seatsRemaining: 147, action: {})
        .padding()
        .background(SkyColor.surface)
}

#Preview("Founder card — sold out (S-PAY-02)") {
    FounderCardView(product: nil, seatsRemaining: 0, action: {})
        .padding()
        .background(SkyColor.surface)
}
