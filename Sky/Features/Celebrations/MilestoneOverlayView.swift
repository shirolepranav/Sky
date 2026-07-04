// MilestoneOverlayView.swift
// S-CEL-02 — Full-screen streak-milestone celebration shown before S-VER-06
// when a streak count hits 3, 7, 14, 30, 60, or 100.
// Sky_App_Workflow.md §Group H S-CEL-02; Roadmap Phase 11.

import SwiftUI

struct MilestoneOverlayView: View {
    let streakDays: Int
    let onAdvance: () -> Void

    @State private var nimbusBounce: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            LinearGradient(
                colors: [
                    Color(hex: "FFF6E5"),
                    Color(hex: "A8D8EA").opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                NimbusView(state: .rainbow, size: 200)
                    .scaleEffect(reduceMotion ? 1 : nimbusBounce)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6),
                        value: nimbusBounce
                    )

                VStack(spacing: SkySpacing.s2) {
                    Text("\(streakDays)")
                        .skyText(.display)

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
            if !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                    nimbusBounce = 1.0
                }
            } else {
                nimbusBounce = 1.0
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(streakDays)-day streak! \(milestoneLine)"
            )
            // Auto-advance after 4 seconds
            Task {
                try? await Task.sleep(for: .seconds(4))
                onAdvance()
            }
        }
        .accessibilityIdentifier("milestone.overlay")
    }
}

#Preview("S-CEL-02 — 7-day milestone") {
    MilestoneOverlayView(streakDays: 7, onAdvance: {})
}

#Preview("S-CEL-02 — 30-day milestone") {
    MilestoneOverlayView(streakDays: 30, onAdvance: {})
}
