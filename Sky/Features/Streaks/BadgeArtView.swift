// BadgeArtView.swift
// Reusable badge artwork: a circular background with an SF Symbol centered in it.
// Each BadgeID maps to a color pair and symbol. No external image assets required
// in v1.0 — all artwork is SwiftUI + SF Symbols.
// Sky_App_Workflow.md §Group C S-STREAK-02; Roadmap Phase 12.

import SwiftUI

struct BadgeArtView: View {
    let badge: BadgeID
    var size: CGFloat = 64
    var locked: Bool = false

    private var fillColor: Color {
        switch badge {
        case .firstLight:           return SkyColor.sunYellow
        case .cumulus, .stratus,
             .cirrus, .sunburst,
             .clearSky, .boundless: return SkyColor.coralStreak
        case .earlyBird:            return SkyColor.sunYellow
        case .wanderer:             return SkyColor.mossGreen
        case .comeback:             return SkyColor.primarySky
        }
    }

    private var symbolColor: Color { .white }

    var body: some View {
        ZStack {
            Circle()
                .fill(locked ? SkyColor.inkDisabled : fillColor)
                .frame(width: size, height: size)

            Image(systemName: badge.symbolName)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(locked ? SkyColor.cloudGrey : symbolColor)
        }
    }
}

#Preview("Badge art — all unlocked") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
        ForEach(BadgeID.displayOrder, id: \.self) { badge in
            VStack(spacing: 4) {
                BadgeArtView(badge: badge, size: 64)
                Text(badge.displayName).skyText(.caption, color: SkyColor.inkSoft)
            }
        }
    }
    .padding()
    .background(SkyColor.surface)
}
