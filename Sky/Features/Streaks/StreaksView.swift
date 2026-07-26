// StreaksView.swift
// S-STREAK-01 — Streaks tab home. Shows current / longest streak, lifetime
// counters, a badge preview row, and a "This week" section (Pro gate in v1.0).
// Sky_App_Workflow.md §Group C S-STREAK-01; Roadmap Phase 12.
//
// Phase 14: Weekly insights card checks storeKit.isPro before navigating.
// Free users see S-PAY-05 (InContextProGateView).

import SwiftUI

struct StreaksView: View {
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var cloudKitSync: CloudKitSyncService
    @EnvironmentObject private var storeKit: StoreKitService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var streakDisplayed: Int = 0
    @State private var revealed = false
    @State private var showBadgesGrid = false
    @State private var showWeeklyInsights = false
    @State private var showInsightsProGate = false
    @State private var showPaywall = false

    private var progress: UserProgress { streakManager.progress }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SkySpacing.s8) {
                    streakHero.skyEntrance(0, revealed: revealed)
                    statCards.skyEntrance(1, revealed: revealed)
                    badgesSection.skyEntrance(2, revealed: revealed)
                    weeklyInsightsSection.skyEntrance(3, revealed: revealed)
                    Spacer(minLength: SkySpacing.s10)
                }
                .padding(.top, SkySpacing.s6)
            }
            .background(SkyColor.surface.ignoresSafeArea())
            .navigationTitle("Streaks")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                cloudKitSync.fetchOnLaunch()
                streakManager.refreshOnForeground()
            }
            .navigationDestination(isPresented: $showBadgesGrid) {
                BadgesGridView()
                    .environmentObject(streakManager)
            }
            .navigationDestination(isPresented: $showWeeklyInsights) {
                WeeklyInsightsView()
            }
            .sheet(isPresented: $showInsightsProGate) {
                InContextProGateView(
                    featureTitle: "Weekly insights is a Pro feature.",
                    onSeePro: {
                        showInsightsProGate = false
                        showPaywall = true
                    },
                    onDismiss: { showInsightsProGate = false }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
                    .environmentObject(storeKit)
            }
            .accessibilityIdentifier("streaks.home")
        }
        .onAppear {
            revealed = true
            animateStreakIn()
        }
    }

    // MARK: - Hero streak number

    @ViewBuilder
    private var streakHero: some View {
        VStack(spacing: SkySpacing.s2) {
            if progress.currentStreak == 0 {
                Text("Your first verification starts your streak.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: SkySpacing.s2) {
                    FlameIcon(color: SkyColor.coralStreak, size: 36)
                    Text("\(streakDisplayed)")
                        .skyText(.display, color: SkyColor.coralStreak)
                        .contentTransition(.numericText(value: Double(streakDisplayed)))
                }
                Text("day\(progress.currentStreak == 1 ? "" : "s")")
                    .skyText(.titleM, color: SkyColor.inkSoft)
            }
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            progress.currentStreak == 0
            ? "No streak yet. Your first verification starts your streak."
            : "\(progress.currentStreak) day streak"
        )
    }

    // MARK: - Stat cards row

    @ViewBuilder
    private var statCards: some View {
        HStack(spacing: SkySpacing.s3) {
            StatCardView(
                icon: "flame.fill", iconColor: SkyColor.coralStreak,
                label: "Longest", value: "\(progress.longestStreak)", unit: "days"
            )
            StatCardView(
                icon: "checkmark.seal.fill", iconColor: SkyColor.sunYellow,
                label: "Total", value: "\(progress.totalVerifications)", unit: "verified"
            )
            StatCardView(
                icon: "lock.open.fill", iconColor: SkyColor.cloudGrey,
                label: "Emergency", value: "\(progress.totalEmergencyUnlocks)", unit: "unlocks"
            )
        }
        .padding(.horizontal, SkyLayout.screenMargin)
    }

    // MARK: - Badges preview section

    @ViewBuilder
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: SkySpacing.s4) {
            HStack {
                Text("Badges")
                    .skyText(.titleM, color: SkyColor.ink)
                Spacer()
                Button("See all") { showBadgesGrid = true }
                    .skyText(.label, color: SkyColor.mossGreen)
                    .accessibilityIdentifier("streaks.seeAllBadges")
            }
            .padding(.horizontal, SkyLayout.screenMargin)

            // Horizontal preview of first 4 badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SkySpacing.s4) {
                    ForEach(BadgeID.displayOrder.prefix(4), id: \.self) { badge in
                        let isUnlocked = progress.unlockedBadges.contains(badge)
                        VStack(spacing: SkySpacing.s1) {
                            BadgeArtView(badge: badge, size: 52, locked: !isUnlocked)
                                .saturation(isUnlocked ? 1 : 0)
                            Text(badge.displayName)
                                .skyText(.caption, color: isUnlocked ? SkyColor.ink : SkyColor.inkMuted)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                }
                .padding(.horizontal, SkyLayout.screenMargin)
            }
        }
    }

    // MARK: - Weekly insights

    @ViewBuilder
    private var weeklyInsightsSection: some View {
        SkyCard {
            HStack {
                VStack(alignment: .leading, spacing: SkySpacing.s2) {
                    Text("This week")
                        .skyText(.titleM, color: SkyColor.ink)
                    Text("Your top emergency unlock reasons.")
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SkyColor.inkMuted)
            }
        }
        .onTapGesture {
            if storeKit.isPro {
                showWeeklyInsights = true
            } else {
                showInsightsProGate = true
            }
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .accessibilityLabel("This week. Your top emergency unlock reasons.")
        .accessibilityHint("View weekly insights")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Animation

    private func animateStreakIn() {
        let target = progress.currentStreak
        guard target > 0 else { return }
        guard !reduceMotion else {
            streakDisplayed = target
            return
        }
        streakDisplayed = 0
        withAnimation(.easeOut(duration: SkyMotion.countUp)) {
            streakDisplayed = target
        }
    }
}

// MARK: - Stat card component

private struct StatCardView: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        SkyCard(padding: SkySpacing.s4) {
            VStack(alignment: .leading, spacing: SkySpacing.s1) {
                HStack(spacing: SkySpacing.s1) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(iconColor)
                    Text(label.uppercased())
                        .skyText(.tabLabel, color: SkyColor.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                HStack(alignment: .lastTextBaseline, spacing: SkySpacing.s1) {
                    Text(value)
                        .skyText(.titleM, color: SkyColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(unit)
                        .skyText(.tabLabel, color: SkyColor.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

// MARK: - Previews

#Preview("S-STREAK-01 — New user") {
    StreaksView()
        .environmentObject(StreakManager())
        .environmentObject(CloudKitSyncService())
        .environmentObject(StoreKitService())
}
