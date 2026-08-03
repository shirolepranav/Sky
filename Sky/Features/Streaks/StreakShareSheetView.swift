// StreakShareSheetView.swift
// S-STREAK-05 — "Share your streak" preview sheet, presented from the Streaks
// tab toolbar. Shows the exact card that will be shared, then hands it to the
// system share sheet via ShareLink.
//
// The card is rendered with ImageRenderer and shared as a SwiftUI `Image`
// (Transferable since iOS 16), so nothing is written to disk — no temp file to
// clean up, in keeping with the app's "leave no artifacts" handling of media.
//
// Not a v1.0 non-goal violation: the PRD rules out leaderboards, social
// features, and accountability partners. A system share-sheet export adds no
// account, server, or friend graph.
//
// Sky_App_Workflow.md §Group C S-STREAK-05; Roadmap Phase 12.

import SwiftUI

struct StreakShareSheetView: View {

    let progress: UserProgress
    let onDismiss: () -> Void

    @State private var rendered: Image? = nil
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SkySpacing.s6) {
                Spacer(minLength: 0)

                cardPreview

                Spacer(minLength: 0)

                if let rendered {
                    // ShareLink is a Button underneath, so it takes the real
                    // design-system style — don't hand-roll the look.
                    ShareLink(
                        item: rendered,
                        preview: SharePreview(shareTitle, image: rendered)
                    ) {
                        Text("Share")
                    }
                    .buttonStyle(SkyPrimaryButtonStyle())
                    .accessibilityIdentifier("streaks.share.confirm")
                }
            }
            .padding(.horizontal, SkyLayout.screenMargin)
            .padding(.bottom, SkySpacing.s6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SkyColor.surface.ignoresSafeArea())
            .navigationTitle("Share your streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(SkyColor.mossGreen)
                }
            }
        }
        .task {
            guard rendered == nil else { return }
            if let image = StreakShareCardView.render(progress: progress) {
                rendered = Image(uiImage: image)
            } else {
                renderFailed = true
            }
        }
        .accessibilityIdentifier("streaks.share.sheet")
    }

    // MARK: - Preview

    @ViewBuilder
    private var cardPreview: some View {
        if renderFailed {
            VStack(spacing: SkySpacing.s3) {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(SkyColor.inkMuted)
                Text("Couldn't build your card.")
                    .skyText(.body, color: SkyColor.inkSoft)
            }
        } else {
            // Show the live view rather than the rendered bitmap so the preview
            // appears instantly and stays crisp at any scale.
            StreakShareCardView(progress: progress)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.colorScheme, .light)
                .clipShape(RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous)
                        .strokeBorder(SkyColor.divider, lineWidth: 1)
                )
                .accessibilityLabel(shareTitle)
        }
    }

    private var shareTitle: String {
        progress.currentStreak > 0
        ? "\(progress.currentStreak)-day streak on \(AppBranding.appName)"
        : "My \(AppBranding.appName) streak"
    }
}

#Preview("S-STREAK-05 Share sheet") {
    StreakShareSheetView(
        progress: {
            var p = UserProgress()
            p.currentStreak = 14
            p.longestStreak = 21
            p.totalVerifications = 47
            p.unlockedBadges = [.firstLight, .cumulus, .stratus, .cirrus]
            return p
        }(),
        onDismiss: {}
    )
}
