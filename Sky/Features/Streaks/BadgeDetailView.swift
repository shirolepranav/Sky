// BadgeDetailView.swift
// S-STREAK-03 — Badge detail sheet. Shown when the user taps a badge in the
// grid. Explains what the badge means and shows the earned date if unlocked.
// Sky_App_Workflow.md §Group C S-STREAK-03; Roadmap Phase 12.

import SwiftUI

struct BadgeDetailView: View {
    let badge: BadgeID
    let unlockedBadges: Set<BadgeID>
    let earnedDate: Date?
    /// Progress hint for badges with visible progress (Wanderer).
    let progressHint: String?

    private var isUnlocked: Bool { unlockedBadges.contains(badge) }

    var body: some View {
        ScrollView {
            VStack(spacing: SkySpacing.s6) {
                BadgeArtView(badge: badge, size: 120, locked: !isUnlocked)
                    .padding(.top, SkySpacing.s8)

                Text(badge.displayName)
                    .skyText(.titleL, color: SkyColor.ink)

                Text(badge.description)
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                if isUnlocked, let date = earnedDate {
                    Text("Earned \(date, style: .date)")
                        .skyText(.caption, color: SkyColor.inkMuted)
                } else if let hint = progressHint {
                    Text(hint)
                        .skyText(.caption, color: SkyColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                Spacer(minLength: SkySpacing.s8)
            }
            .frame(maxWidth: .infinity)
        }
        .background(SkyColor.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("badge.detail.\(badge.rawValue)")
    }
}

// MARK: - Preview

#Preview("S-STREAK-03 — Unlocked") {
    BadgeDetailView(
        badge: .cumulus,
        unlockedBadges: [.cumulus],
        earnedDate: Date(),
        progressHint: nil
    )
}

#Preview("S-STREAK-03 — Locked (Wanderer)") {
    BadgeDetailView(
        badge: .wanderer,
        unlockedBadges: [],
        earnedDate: nil,
        progressHint: "2 of 5 places visited"
    )
}
