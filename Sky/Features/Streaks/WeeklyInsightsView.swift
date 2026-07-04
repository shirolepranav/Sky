// WeeklyInsightsView.swift
// S-STREAK-04 — Shows the user their top emergency-unlock reasons from the
// current calendar week, read from EmergencyLogStore (on-device only).
// Empty state shown when no unlocks occurred this week.
//
// Pro gating is intentionally absent in Phase 13 — the paywall and gating
// logic are Phase 14 work. Phase 14 will wrap this view with a Pro-check before
// allowing navigation.
// Sky_App_Workflow.md S-STREAK-04; Roadmap Phase 13.

import SwiftUI

struct WeeklyInsightsView: View {
    @State private var reasons: [(reason: String, count: Int)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkySpacing.s6) {
                // Intro copy
                Text("These are the reasons you typed when you used an emergency unlock. They never leave your phone.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.top, SkySpacing.s2)

                if reasons.isEmpty {
                    emptyState
                } else {
                    reasonsList
                }

                // Privacy footer
                Text("Stored only on this phone.")
                    .skyText(.caption, color: SkyColor.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
            .padding(.top, SkySpacing.s4)
        }
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("This week")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReasons() }
        .accessibilityIdentifier("streaks.weeklyInsights")
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: SkySpacing.s4) {
            NimbusView(state: .fluffyWhite, size: 80)
                .accessibilityHidden(true)

            Text("Nothing here yet — and that's the goal.")
                .skyText(.body, color: SkyColor.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SkyLayout.screenMargin)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SkySpacing.s8)
    }

    // MARK: - Reasons list

    @ViewBuilder
    private var reasonsList: some View {
        VStack(spacing: SkySpacing.s4) {
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, entry in
                SkyCard {
                    VStack(alignment: .leading, spacing: SkySpacing.s3) {
                        Text(entry.reason)
                            .skyText(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        FrequencyDotsView(count: entry.count)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(entry.reason). Used \(entry.count) \(entry.count == 1 ? "time" : "times") this week.")
            }
        }
        .padding(.horizontal, SkyLayout.screenMargin)
    }

    // MARK: - Data

    private func loadReasons() {
        reasons = EmergencyLogStore.shared.topReasonsThisWeek(limit: 3)
    }
}

// MARK: - Frequency dots

private struct FrequencyDotsView: View {
    let count: Int

    private let maxDots = 5

    var body: some View {
        HStack(spacing: SkySpacing.s1) {
            let dotsToShow = min(count, maxDots)
            ForEach(0..<dotsToShow, id: \.self) { _ in
                Circle()
                    .fill(SkyColor.coralStreak)
                    .frame(width: 8, height: 8)
            }
            if count > maxDots {
                Text("+\(count - maxDots)")
                    .skyText(.caption, color: SkyColor.coralStreak)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("S-STREAK-04 — empty") {
    NavigationStack {
        WeeklyInsightsView()
    }
}

#Preview("S-STREAK-04 — with reasons") {
    // Inject test data by using a custom store in a real preview requires
    // running in Simulator — this shows the layout structure.
    NavigationStack {
        WeeklyInsightsView()
    }
}
