// BadgesGridView.swift
// S-STREAK-02 — 3-column grid of all 10 launch badges. Locked badges appear
// greyscale with a lock icon. Tapping a badge presents S-STREAK-03 detail sheet.
// Sky_App_Workflow.md §Group C S-STREAK-02; Roadmap Phase 12.

import SwiftUI

struct BadgesGridView: View {
    @EnvironmentObject private var streakManager: StreakManager

    @State private var selectedBadge: BadgeID? = nil

    private let columns = [
        GridItem(.flexible(), spacing: SkySpacing.s4),
        GridItem(.flexible(), spacing: SkySpacing.s4),
        GridItem(.flexible(), spacing: SkySpacing.s4)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: SkySpacing.s5) {
                ForEach(BadgeID.displayOrder, id: \.self) { badge in
                    BadgeCellView(badge: badge,
                                  unlockedBadges: streakManager.progress.unlockedBadges)
                        .onTapGesture { selectedBadge = badge }
                }
            }
            .padding(.horizontal, SkyLayout.screenMargin)
            .padding(.vertical, SkySpacing.s6)
        }
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(
                badge: badge,
                unlockedBadges: streakManager.progress.unlockedBadges,
                earnedDate: streakManager.progress.lastVerificationDate, // approximate
                progressHint: progressHint(for: badge)
            )
        }
        .accessibilityIdentifier("badges.grid")
    }

    private func progressHint(for badge: BadgeID) -> String? {
        let progress = streakManager.progress
        switch badge {
        case .wanderer:
            let count = progress.verificationLocations.count
            return count < 5 ? "\(count) of 5 places visited" : nil
        case .comeback:
            return progress.hadEmergencyUnlock
                ? "Verify \(max(0, 7 - progress.streakAfterFirstEmergency)) more days in a row"
                : "Use an emergency unlock, then verify 7 days in a row"
        default:
            return nil
        }
    }
}

// MARK: - Badge cell

private struct BadgeCellView: View {
    let badge: BadgeID
    let unlockedBadges: Set<BadgeID>

    @AppStorage private var wasViewed: Bool

    private var isUnlocked: Bool { unlockedBadges.contains(badge) }
    @State private var shimmerOpacity: Double = 0

    init(badge: BadgeID, unlockedBadges: Set<BadgeID>) {
        self.badge = badge
        self.unlockedBadges = unlockedBadges
        _wasViewed = AppStorage(wrappedValue: false, "viewedBadge_\(badge.rawValue)")
    }

    var body: some View {
        VStack(spacing: SkySpacing.s2) {
            ZStack(alignment: .bottomTrailing) {
                BadgeArtView(badge: badge, size: 64, locked: !isUnlocked)
                    .saturation(isUnlocked ? 1 : 0)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SkyColor.cloudGrey)
                        .padding(4)
                }
            }
            .overlay {
                if isUnlocked && !wasViewed {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(SkyColor.sunYellow, lineWidth: 2)
                        .opacity(shimmerOpacity)
                }
            }

            Text(badge.displayName)
                .skyText(.caption, color: isUnlocked ? SkyColor.ink : SkyColor.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SkySpacing.s2)
        .accessibilityLabel("\(badge.displayName), \(isUnlocked ? "unlocked" : "locked")")
        .accessibilityIdentifier("badge.cell.\(badge.rawValue)")
        .onAppear {
            if isUnlocked && !wasViewed {
                // 3-second shimmer then mark as viewed
                withAnimation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true)) {
                    shimmerOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    wasViewed = true
                    shimmerOpacity = 0
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("S-STREAK-02 — Mixed") {
    let manager = StreakManager()
    NavigationStack {
        BadgesGridView()
            .environmentObject(manager)
    }
}
