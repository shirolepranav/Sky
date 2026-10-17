// MilestoneOverlayView.swift
// S-CEL-02 — Full-screen streak-milestone celebration shown before S-VER-06
// when a streak count hits 3, 7, 14, 30, 60, or 100.
// Sky_App_Workflow.md §Group H S-CEL-02; Roadmap Phase 11.

import SwiftUI

struct MilestoneOverlayView: View {
    let streakDays: Int
    let onAdvance: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entrance choreography for the hero Nimbus.
    private struct EntrancePose {
        var scale: CGFloat = 0.8
        var y: CGFloat = 8
        var opacity: Double = 0
    }

    private static let milestoneCopy: [Int: String] = [
        3:   "Three days. Real momentum.",
        7:   "A whole week. You're doing it.",
        14:  "Two weeks. This is who you are now.",
        30:  "Thirty days. Most people quit by now. Not you.",
        60:  "Sixty days. We're in rare air.",
        100: "One hundred days. Take a screenshot."
    ]

    private var milestoneLine: String {
        Self.milestoneCopy[streakDays] ?? "Keep going."
    }

    var body: some View {
        ZStack {
            // Adaptive celebration backdrop: warm cream→sky in light, a calm
            // night-sky gradient in dark, so the adaptive `ink` text stays legible.
            LinearGradient(
                colors: [
                    Color(light: Color(hex: "FFF6E5"), dark: Color(hex: "15171F")),
                    Color(light: Color(hex: "A8D8EA").opacity(0.4), dark: Color(hex: "232838"))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Spec: confetti only when Reduce Motion is off (Workflow §3.6).
            if !reduceMotion {
                SkyConfettiBurst(count: 20)
                    .ignoresSafeArea()
            }

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                heroNimbus

                VStack(spacing: SkySpacing.s2) {
                    dayCount

                    Text("day streak!")
                        .skyText(.titleL, color: SkyColor.inkSoft)
                }

                Text(milestoneLine)
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                Text("Tap to continue")
                    .skyText(.caption, color: SkyColor.inkMuted)
                    .padding(.bottom, SkySpacing.s8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onAdvance() }
        .onAppear {
            appeared = true
            #if os(iOS)
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(streakDays)-day streak! \(milestoneLine)"
            )
            #endif
            // Auto-advance after 4 seconds
            Task {
                try? await Task.sleep(for: .seconds(4))
                onAdvance()
            }
        }
        .accessibilityIdentifier("milestone.overlay")
    }

    // MARK: - Choreographed pieces (Reduce Motion → instant, no bounce)

    @ViewBuilder private var heroNimbus: some View {
        let nimbus = NimbusView(state: .rainbow, size: 200)
        if reduceMotion {
            nimbus
        } else {
            // Rise + overshoot bounce, settling upright.
            nimbus.keyframeAnimator(
                initialValue: EntrancePose(), trigger: appeared
            ) { view, pose in
                view
                    .scaleEffect(pose.scale)
                    .offset(y: pose.y)
                    .opacity(pose.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.05, duration: 0.35, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.25, spring: .snappy)
                }
                KeyframeTrack(\.y) {
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: 0.2)
                }
            }
        }
    }

    @ViewBuilder private var dayCount: some View {
        let count = Text("\(streakDays)").skyText(.display)
        if reduceMotion {
            count
        } else {
            // Delayed pop once Nimbus has mostly settled.
            count.keyframeAnimator(
                initialValue: CGFloat(1), trigger: appeared
            ) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(CGFloat(1.0), duration: 0.25)
                    SpringKeyframe(CGFloat(1.1), duration: 0.15, spring: .bouncy)
                    SpringKeyframe(CGFloat(1.0), duration: 0.2, spring: .snappy)
                }
            }
        }
    }
}

#Preview("S-CEL-02 — 7-day milestone") {
    MilestoneOverlayView(streakDays: 7, onAdvance: {})
}

#Preview("S-CEL-02 — 30-day milestone") {
    MilestoneOverlayView(streakDays: 30, onAdvance: {})
}
