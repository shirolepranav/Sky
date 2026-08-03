// StreaksView.swift
// S-STREAK-01 — Streaks tab home. Hero streak card with Nimbus and a last-seven-
// days strip, progress toward the next milestone, lifetime counters, a badge
// preview row, and a "This week" section (Pro gate in v1.0).
// Sky_App_Workflow.md §Group C S-STREAK-01; Roadmap Phase 12.
//
// Phase 14: Weekly insights card checks storeKit.isPro before navigating.
// Free users see S-PAY-05 (InContextProGateView).
//
// Sharing (S-STREAK-05) is intentionally NOT Pro-gated — it is the app's only
// organic growth surface.
//
// All derived values (hero state, milestone progress, the day strip) come from
// StreakInsights, which computes them from the existing UserProgress fields.

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
    @State private var showShareSheet = false

    private var progress: UserProgress { streakManager.progress }
    private var heroState: StreakInsights.HeroState { StreakInsights.heroState(progress) }
    private var canShare: Bool { progress.totalVerifications > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SkySpacing.s6) {
                    streakHero.skyEntrance(0, revealed: revealed)
                    milestoneSection.skyEntrance(1, revealed: revealed)
                    statCards.skyEntrance(2, revealed: revealed)
                    badgesSection.skyEntrance(3, revealed: revealed)
                    weeklyInsightsSection.skyEntrance(4, revealed: revealed)
                    Spacer(minLength: SkySpacing.s10)
                }
                .padding(.top, SkySpacing.s6)
            }
            .background(SkyColor.surface.ignoresSafeArea())
            .navigationTitle("Streaks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if canShare {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .foregroundStyle(SkyColor.mossGreen)
                        .accessibilityLabel("Share your streak")
                        .accessibilityIdentifier("streaks.share")
                    }
                }
            }
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
            .sheet(isPresented: $showShareSheet) {
                StreakShareSheetView(progress: progress) {
                    showShareSheet = false
                }
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

    // MARK: - Hero streak card

    private var streakHero: some View {
        SkyCard {
            VStack(spacing: SkySpacing.s4) {
                NimbusView(state: heroMascotState, size: 108)

                switch heroState {
                case .firstTime:
                    Text("Your first verification starts your streak.")
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                case .broken:
                    VStack(spacing: SkySpacing.s1) {
                        Text("Streak ended. Today's a new start.")
                            .skyText(.body, color: SkyColor.ink)
                            .multilineTextAlignment(.center)
                        Text("Your best was \(progress.longestStreak) day\(progress.longestStreak == 1 ? "" : "s").")
                            .skyText(.bodyS, color: SkyColor.inkSoft)
                    }
                case .active:
                    VStack(spacing: SkySpacing.s1) {
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

                dayStrip
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroMascotState: MascotState {
        switch heroState {
        case .firstTime, .broken: return .cloudyGrey
        case .active:
            return streakManager.isMilestoneStreak(progress.currentStreak) ? .rainbow : .sunny
        }
    }

    private var heroAccessibilityLabel: String {
        switch heroState {
        case .firstTime: return "No streak yet. Your first verification starts your streak."
        case .broken:    return "Streak ended. Today's a new start. Your best was \(progress.longestStreak) days."
        case .active:    return "\(progress.currentStreak) day streak"
        }
    }

    // MARK: - Last seven days

    private var dayStrip: some View {
        let marks = StreakInsights.lastSevenDays(progress: progress)
        return HStack(spacing: SkySpacing.s2) {
            ForEach(marks) { mark in
                VStack(spacing: SkySpacing.s1) {
                    Circle()
                        .fill(mark.isVerified ? SkyColor.coralStreak : SkyColor.inkDisabled)
                        .frame(width: 12, height: 12)
                        .overlay {
                            if mark.isToday {
                                Circle()
                                    .strokeBorder(SkyColor.inkSoft, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .frame(height: 18)
                    Text(StreakInsights.weekdayInitial(for: mark.date))
                        .skyText(.tabLabel, color: SkyColor.inkMuted)
                }
            }
        }
        .padding(.top, SkySpacing.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last seven days: \(marks.filter(\.isVerified).count) verified.")
    }

    // MARK: - Next milestone

    @ViewBuilder
    private var milestoneSection: some View {
        if heroState == .active,
           let milestone = StreakInsights.nextMilestone(after: progress.currentStreak) {
            SkyCard(padding: SkySpacing.s4) {
                VStack(alignment: .leading, spacing: SkySpacing.s2) {
                    HStack {
                        Text(milestoneHeadline(milestone))
                            .skyText(.label, color: SkyColor.ink)
                        Spacer()
                        if let badge = milestone.badge {
                            BadgeArtView(badge: badge, size: 24, locked: true)
                                .saturation(0)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(SkyColor.inkDisabled.opacity(0.5))
                            Capsule()
                                .fill(SkyColor.coralStreak)
                                .frame(width: geo.size.width * milestone.fraction)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.horizontal, SkyLayout.screenMargin)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(milestoneHeadline(milestone))
        }
    }

    private func milestoneHeadline(_ milestone: StreakInsights.MilestoneProgress) -> String {
        let days = milestone.daysRemaining
        let unit = days == 1 ? "day" : "days"
        if let badge = milestone.badge {
            return "\(days) \(unit) to \(badge.displayName)"
        }
        return "\(days) \(unit) to \(milestone.target)"
    }

    // MARK: - Stat cards row

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SkySpacing.s4) {
                    ForEach(previewBadges, id: \.self) { badge in
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

    /// Earned badges first, then the next ones still to earn — so the row always
    /// reflects real progress. (Previously this was a flat `prefix(4)`, which
    /// showed the same four badges no matter what the user had unlocked.)
    /// "Most recently unlocked" is not available: `unlockedBadges` is an
    /// unordered Set with no per-badge date.
    private var previewBadges: [BadgeID] {
        let unlocked = BadgeID.displayOrder.filter { progress.unlockedBadges.contains($0) }
        let locked = BadgeID.displayOrder.filter { !progress.unlockedBadges.contains($0) }
        return Array((unlocked + locked).prefix(4))
    }

    // MARK: - Weekly insights

    private var weeklyInsightsSection: some View {
        SkyCard {
            HStack {
                VStack(alignment: .leading, spacing: SkySpacing.s2) {
                    Text("This week")
                        .skyText(.titleM, color: SkyColor.ink)
                    Text(insightsSubtitle)
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: storeKit.isPro ? "chevron.right" : "lock.fill")
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
        .accessibilityLabel("This week. \(insightsSubtitle)")
        .accessibilityHint(storeKit.isPro ? "View weekly insights" : "Pro feature. Tap to see Pro.")
        .accessibilityAddTraits(.isButton)
    }

    private var insightsSubtitle: String {
        storeKit.isPro
        ? "Your top emergency unlock reasons."
        : "Weekly insights help you spot patterns. Available in Sky Pro."
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
