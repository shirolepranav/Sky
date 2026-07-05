// TierCardView.swift
// Reusable tier card for one subscription option inside PaywallView (S-PAY-01).
// Annual is highlighted (bigger, sky-blue tint, "Best Value" ribbon).
// Sky_App_Workflow.md §Group G S-PAY-01; Roadmap Phase 14.

import StoreKit
import SwiftUI

struct TierCardView: View {
    let product: Product?
    let tierName: String
    let isHighlighted: Bool
    var ribbonText: String? = nil
    var badgeText: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    private var cardBackground: Color {
        isHighlighted ? SkyColor.primarySky.opacity(0.18) : SkyColor.surfaceCard
    }

    private var borderColor: Color {
        isHighlighted ? SkyColor.primarySkyDeep : SkyColor.divider
    }

    private var borderWidth: CGFloat {
        isHighlighted ? 2 : 1
    }

    private var internalPadding: CGFloat {
        isHighlighted ? SkySpacing.s6 : SkySpacing.s5
    }

    private var priceText: String {
        product?.displayPrice ?? "—"
    }

    private var periodText: String? {
        guard let period = product?.subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .month: return "/ month"
        case .year:  return "/ year"
        default:     return nil
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SkySpacing.s2) {
                Text(tierName)
                    .skyText(.label, color: SkyColor.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)

                if isLoading || product == nil {
                    ProgressView()
                        .frame(height: 40)
                } else {
                    Group {
                        Text(priceText)
                            .skyText(.titleM, color: SkyColor.ink)

                        if let period = periodText {
                            Text(period)
                                .skyText(.caption, color: SkyColor.inkSoft)
                        }
                    }
                }

                if let badge = badgeText, !isLoading {
                    Text(badge)
                        // Fixed dark ink — the yellow capsule stays bright in dark
                        // mode, so adaptive `ink` would flip near-white and vanish.
                        .skyText(.caption, color: SkyColor.inkOnAccent)
                        .padding(.horizontal, SkySpacing.s3)
                        .padding(.vertical, SkySpacing.s1)
                        .background(SkyColor.sunYellow.opacity(0.6), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(internalPadding)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading || product == nil)
        .accessibilityLabel("\(tierName), \(priceText)\(periodText.map { " \($0)" } ?? "")")
        .overlay(alignment: .topTrailing) {
            if let ribbon = ribbonText, !isLoading {
                Text(ribbon)
                    .skyText(.caption, color: .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SkyColor.coralStreak, in: Capsule())
                    .offset(x: 4, y: -8)
            }
        }
    }
}

#Preview("Tier cards — all states") {
    HStack(alignment: .top, spacing: SkySpacing.s3) {
        TierCardView(
            product: nil,
            tierName: "Monthly",
            isHighlighted: false,
            action: {}
        )
        TierCardView(
            product: nil,
            tierName: "Annual",
            isHighlighted: true,
            ribbonText: "Best Value",
            badgeText: "7-day free trial",
            action: {}
        )
        TierCardView(
            product: nil,
            tierName: "Lifetime",
            isHighlighted: false,
            action: {}
        )
    }
    .padding()
    .background(SkyColor.surface)
}
