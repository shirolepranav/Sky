// StreakShareCardView.swift
// The image users export from the Streaks tab (S-STREAK-01 share action).
// Rendered off-screen by `ImageRenderer` in StreakShareSheetView, so it is a
// fixed-size, deterministic view — never laid out responsively.
//
// Deliberately omitted from the card:
//   • the emergency-unlock count — broadcasting it is guilt-shaped, and the
//     brand voice rule is that Sky is never punishing (PRD §7).
//   • anything derived from `verificationLocations` — those are rounded GPS
//     strings and stay on-device (CLAUDE.md privacy invariants). The Wanderer
//     badge mark is fine; the coordinates are not.
//
// Sky_App_Workflow.md §Group C S-STREAK-01; DESIGN_SYSTEM.md §2, §7.

import SwiftUI

struct StreakShareCardView: View {

    let progress: UserProgress

    /// 4:5 — reads well in an Instagram feed and is safe inside a 9:16 story.
    static let size = CGSize(width: 320, height: 400)

    // MARK: - Derived

    private var isActiveStreak: Bool { progress.currentStreak > 0 }

    private var headlineNumber: Int {
        isActiveStreak ? progress.currentStreak : progress.longestStreak
    }

    private var headlineCaption: String {
        let unit = headlineNumber == 1 ? "day" : "days"
        return isActiveStreak ? "\(unit) outside in a row" : "\(unit) — my best streak"
    }

    /// Nimbus mirrors the Today tab's logic rather than depending on
    /// MascotStateManager, which the Streaks tab never receives.
    private var mascotState: MascotState {
        guard isActiveStreak else { return .cloudyGrey }
        return StreakInsights.milestones.contains(progress.currentStreak) ? .rainbow : .sunny
    }

    private var showcaseBadges: [BadgeID] {
        BadgeID.displayOrder.filter { progress.unlockedBadges.contains($0) }.suffix(3)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: SkySpacing.s3) {
            NimbusView(state: mascotState, size: 116, isStatic: true)

            VStack(spacing: 0) {
                Text("\(headlineNumber)")
                    .skyText(.display, color: SkyColor.coralStreak)
                Text(headlineCaption)
                    .skyText(.bodyS, color: SkyColor.inkSoft)
            }

            Divider().background(SkyColor.divider)
                .padding(.horizontal, SkySpacing.s4)

            HStack(spacing: SkySpacing.s6) {
                statColumn(value: "\(progress.longestStreak)", label: "LONGEST")
                statColumn(value: "\(progress.totalVerifications)", label: "VERIFIED")
            }

            if !showcaseBadges.isEmpty {
                HStack(spacing: SkySpacing.s3) {
                    ForEach(showcaseBadges, id: \.self) { badge in
                        BadgeArtView(badge: badge, size: 32)
                    }
                }
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(SkySpacing.s5)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(cardBackground)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).skyText(.titleM, color: SkyColor.ink)
            Text(label).skyText(.overline, color: SkyColor.inkMuted)
        }
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Text(AppBranding.appName)
                .skyText(.headline, color: SkyColor.ink)
            Text("Go outside to unlock your apps.")
                .skyText(.caption, color: SkyColor.inkMuted)
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [SkyColor.primarySky.opacity(0.35), SkyColor.warmCream],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Render helper

extension StreakShareCardView {

    /// Renders the card to a `UIImage` at 3× for sharing.
    ///
    /// The environment is pinned deliberately:
    ///   • `dynamicTypeSize` — `.skyText` scales via `@ScaledMetric`, so without
    ///     this the exported image would change size with the reader's text
    ///     setting and overflow the fixed frame.
    ///   • `colorScheme` — the card's tokens are adaptive; pinning to light
    ///     keeps the exported PNG identical for every user.
    @MainActor
    static func render(progress: UserProgress) -> UIImage? {
        let renderer = ImageRenderer(
            content: StreakShareCardView(progress: progress)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview("Share card — active streak") {
    StreakShareCardView(progress: {
        var p = UserProgress()
        p.currentStreak = 14
        p.longestStreak = 21
        p.totalVerifications = 47
        p.unlockedBadges = [.firstLight, .cumulus, .stratus, .cirrus, .earlyBird]
        return p
    }())
    .padding()
    .background(SkyColor.surface)
}

#Preview("Share card — lapsed streak") {
    StreakShareCardView(progress: {
        var p = UserProgress()
        p.currentStreak = 0
        p.longestStreak = 31
        p.totalVerifications = 64
        p.unlockedBadges = [.firstLight, .cumulus, .sunburst]
        return p
    }())
    .padding()
    .background(SkyColor.surface)
}
