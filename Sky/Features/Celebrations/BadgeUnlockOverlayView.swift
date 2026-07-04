// BadgeUnlockOverlayView.swift
// S-CEL-01 — Badge-earned celebration overlay. Shown after S-VER-06 "Done" when
// a new badge has been unlocked. Multiple badges are shown in sequence.
// Sky_App_Workflow.md §Group H S-CEL-01; Roadmap Phase 12.

import SwiftUI

struct BadgeUnlockOverlayView: View {
    let badge: BadgeID
    let onDismiss: () -> Void

    @State private var badgeScale: CGFloat = 0.4
    @State private var badgeOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Dim background — tappable to dismiss
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                // Badge artwork
                BadgeArtView(badge: badge, size: 120)
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)

                // Title + description
                VStack(spacing: SkySpacing.s2) {
                    Text("Badge unlocked: \(badge.displayName)")
                        .skyText(.titleM, color: SkyColor.ink)
                        .multilineTextAlignment(.center)

                    Text(badge.description)
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                SkyPrimaryButton("Nice") { onDismiss() }
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()
            }
            .padding(.vertical, SkySpacing.s8)
        }
        .onAppear {
            if reduceMotion {
                badgeScale = 1
                badgeOpacity = 1
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                    badgeScale = 1
                    badgeOpacity = 1
                }
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Badge unlocked: \(badge.displayName). \(badge.description)"
            )
        }
        .accessibilityIdentifier("badge.overlay.\(badge.rawValue)")
    }
}

// MARK: - Previews

#Preview("S-CEL-01 — First Light") {
    BadgeUnlockOverlayView(badge: .firstLight, onDismiss: {})
}

#Preview("S-CEL-01 — Wanderer") {
    BadgeUnlockOverlayView(badge: .wanderer, onDismiss: {})
}
