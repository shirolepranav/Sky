// BadgeUnlockOverlayView.swift
// S-CEL-01 — Badge-earned celebration overlay. Shown after S-VER-06 "Done" when
// a new badge has been unlocked. Multiple badges are shown in sequence.
// Sky_App_Workflow.md §Group H S-CEL-01; Roadmap Phase 12.
//
// Sky Pop: the badge and its copy sit on a hairline card (info), and the one
// tappable thing — "Nice" — is the outlined Pop button.

import SwiftUI

struct BadgeUnlockOverlayView: View {
    let badge: BadgeID
    let onDismiss: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entrance choreography for the badge art: grow with overshoot while
    /// straightening from a slight tilt.
    private struct BadgePose {
        var scale: CGFloat = 0.4
        var rotation: Angle = .degrees(-8)
        var opacity: Double = 0
    }

    var body: some View {
        ZStack {
            // Dim background — tappable to dismiss. Fixed ink scrim (never pure
            // black), the same in both modes.
            SkyColor.inkOnAccent.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            SkyCard {
                VStack(spacing: SkySpacing.s5) {
                    // Badge artwork
                    badgeArt

                    // Title + description
                    VStack(spacing: SkySpacing.s2) {
                        Text("Badge unlocked: \(badge.displayName)")
                            .skyText(.titleM, color: SkyColor.ink)
                            .multilineTextAlignment(.center)

                        Text(badge.description)
                            .skyText(.body, color: SkyColor.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    SkyPopButton("Nice") { onDismiss() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SkyLayout.screenMarginCard)
        }
        .onAppear {
            appeared = true
            #if os(iOS)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Badge unlocked: \(badge.displayName). \(badge.description)"
            )
            #endif
        }
        .accessibilityIdentifier("badge.overlay.\(badge.rawValue)")
    }

    // Reduce Motion → instant appearance, no bounce (Workflow §3.6).
    @ViewBuilder private var badgeArt: some View {
        let art = BadgeArtView(badge: badge, size: 120)
        if reduceMotion {
            art
        } else {
            art.keyframeAnimator(
                initialValue: BadgePose(), trigger: appeared
            ) { view, pose in
                view
                    .scaleEffect(pose.scale)
                    .rotationEffect(pose.rotation)
                    .opacity(pose.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.08, duration: 0.3, spring: .bouncy)
                    SpringKeyframe(0.97, duration: 0.15, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.15, spring: .snappy)
                }
                KeyframeTrack(\.rotation) {
                    SpringKeyframe(.degrees(4), duration: 0.3, spring: .bouncy)
                    SpringKeyframe(.degrees(0), duration: 0.3, spring: .snappy)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: 0.15)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("S-CEL-01 — First Light") {
    BadgeUnlockOverlayView(badge: .firstLight, onDismiss: {})
}

#Preview("S-CEL-01 — Wanderer") {
    BadgeUnlockOverlayView(badge: .wanderer, onDismiss: {})
}

#Preview("S-CEL-01 — dark") {
    BadgeUnlockOverlayView(badge: .firstLight, onDismiss: {})
        .preferredColorScheme(.dark)
}
