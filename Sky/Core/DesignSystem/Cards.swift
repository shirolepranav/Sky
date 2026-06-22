// Cards.swift
// Sky container components — DESIGN_SYSTEM.md §7.
// Cards lean on a hairline border, not heavy shadows (calm, soft, low-spread).

import SwiftUI

/// Primary card: white fill, 24 radius, 1px divider border, 20 padding.
/// Pass `secondary: true` for inner cards (20 radius).
struct SkyCard<Content: View>: View {
    var secondary = false
    var padding: CGFloat = SkySpacing.s5
    @ViewBuilder var content: () -> Content

    var body: some View {
        let radius = secondary ? SkyRadius.cardSecondary : SkyRadius.card
        content()
            .padding(padding)
            .background(SkyColor.surfaceCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SkyColor.divider, lineWidth: 1)
            )
    }
}

/// Status pill: pill-shaped, cream or white fill, 14/bold label, often led by an
/// 8×8 dot whose color signals state (e.g. coral = paused).
struct SkyStatusPill: View {
    let text: String
    var dotColor: Color? = nil
    var fill: Color = SkyColor.warmCream

    var body: some View {
        HStack(spacing: SkySpacing.s2) {
            if let dotColor {
                Circle().fill(dotColor).frame(width: 8, height: 8)
            }
            Text(text).skyText(.label, color: SkyColor.ink)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(fill, in: Capsule())
    }
}

/// Streak chip: cream rounded tile with a flame icon and "N day streak".
struct SkyStreakChip: View {
    let days: Int

    var body: some View {
        HStack(spacing: SkySpacing.s2) {
            FlameIcon(color: SkyColor.coralStreak, size: 20)
            Text("\(days) day streak").skyText(.headline, color: SkyColor.ink)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SkyColor.warmCream, in: RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous))
    }
}

#Preview("Cards & chips") {
    VStack(spacing: 16) {
        SkyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card title").skyText(.titleM)
                Text("A calm container with a hairline border, not a heavy shadow.")
                    .skyText(.body, color: SkyColor.inkSoft)
            }
        }
        HStack {
            SkyStatusPill(text: "Apps paused", dotColor: SkyColor.coralStreak)
            SkyStreakChip(days: 12)
        }
    }
    .padding(24)
    .background(SkyColor.surface)
}
