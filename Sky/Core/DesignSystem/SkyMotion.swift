// SkyMotion.swift
// Sky motion tokens — standard durations, easings, and springs, plus shared
// reduce-motion helpers. DESIGN_SYSTEM.md §8 (Nimbus transitions), §9 (Motion),
// CLAUDE.md rule 6 ("Subtle motion only"). Compose animations from these
// tokens; do not inline durations or spring parameters.

import SwiftUI

/// Motion scale. Durations are seconds; each has a matching `Animation`.
enum SkyMotion {
    // MARK: Durations

    static let press: TimeInterval = 0.12         // button press feedback
    static let quick: TimeInterval = 0.2          // segment switches, countdown ticks
    static let step: TimeInterval = 0.25          // flow-step fades, root gates
    static let fade: TimeInterval = 0.3           // banner / status crossfades
    static let gentle: TimeInterval = 0.4         // progress ring, prompt swaps
    static let morph: TimeInterval = 0.5          // Nimbus state morph — DESIGN_SYSTEM §8
    static let morphReduced: TimeInterval = 0.2   // Reduce Motion crossfade — Workflow §3.6
    static let countUp: TimeInterval = 1.0        // streak hero roll-up
    static let bobPeriod: TimeInterval = 4.0      // Nimbus idle bob, full sine cycle (§8 "~2s" each way)

    // MARK: Easings

    static var pressEase: Animation { .easeOut(duration: press) }
    static var quickEase: Animation { .easeInOut(duration: quick) }
    static var stepEase: Animation { .easeInOut(duration: step) }
    static var fadeEase: Animation { .easeInOut(duration: fade) }
    static var gentleEase: Animation { .easeOut(duration: gentle) }
    static var morphEase: Animation { .easeInOut(duration: morph) }
    static var morphReducedEase: Animation { .easeInOut(duration: morphReduced) }

    // MARK: Springs

    /// Celebration overlays (S-CEL-01/02): entrance bounce.
    static var celebrationSpring: Animation { .spring(response: 0.5, dampingFraction: 0.6) }
    /// Nimbus tap squish on Today (S-TODAY-01).
    static var squishSpring: Animation { .spring(response: 0.3, dampingFraction: 0.5) }
    /// Streak chip tick-up (S-VER-06).
    static var chipSpring: Animation { .spring(response: 0.6) }
    /// Toast presentation.
    static var toastSpring: Animation { .spring(response: 0.25) }

    // MARK: Special

    /// Attention shake for validation errors (pause / emergency reason fields).
    static var shake: Animation { .linear(duration: 0.05).repeatCount(4, autoreverses: true) }

    /// Staggered section entrance: index 0 leads, each later section trails by 60ms.
    static func entrance(_ index: Int) -> Animation {
        .easeOut(duration: 0.35).delay(Double(index) * 0.06)
    }
}

// MARK: - Reduce-motion helpers

/// Strips all animation from a subtree when `reduce` is true. Use around
/// content whose implicit animations should become instant under Reduce Motion
/// (e.g. countdown rings ticking in discrete steps — Workflow §3.6).
struct ReduceMotionTransaction: ViewModifier {
    let reduce: Bool
    func body(content: Content) -> some View {
        if reduce {
            content.transaction { $0.animation = nil }
        } else {
            content
        }
    }
}

/// Gentle opacity pulse loop. Pass `active: false` (e.g. under Reduce Motion)
/// to render steady at full opacity.
private struct SkyPulsingModifier: ViewModifier {
    let active: Bool
    let dimTo: Double
    let period: TimeInterval
    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(active ? opacity : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) {
                    opacity = dimTo
                }
            }
    }
}

/// Staggered entrance for a screen section: fades in and rises 12pt, delayed by
/// `index`. Under Reduce Motion the content is always fully visible — it never
/// waits at opacity 0.
private struct SkyEntranceModifier: ViewModifier {
    let index: Int
    let revealed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: Bool { reduceMotion || revealed }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .animation(reduceMotion ? nil : SkyMotion.entrance(index), value: revealed)
    }
}

extension View {
    /// Gentle opacity pulse loop (recording dot, waiting hints).
    func skyPulsing(active: Bool, dimTo: Double = 0.3, period: TimeInterval = 1.2) -> some View {
        modifier(SkyPulsingModifier(active: active, dimTo: dimTo, period: period))
    }

    /// Staggered section entrance; flip `revealed` to true in `onAppear`.
    func skyEntrance(_ index: Int, revealed: Bool) -> some View {
        modifier(SkyEntranceModifier(index: index, revealed: revealed))
    }
}

#Preview("Motion helpers") {
    struct Demo: View {
        @State private var revealed = false
        @State private var pressed = false

        var body: some View {
            VStack(spacing: SkySpacing.s6) {
                ForEach(0..<3) { i in
                    Text("Section \(i)")
                        .skyText(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(SkySpacing.s5)
                        .background(SkyColor.warmCream, in: RoundedRectangle(cornerRadius: SkyRadius.card))
                        .skyEntrance(i, revealed: revealed)
                }

                Circle()
                    .fill(SkyColor.coralStreak)
                    .frame(width: 12, height: 12)
                    .skyPulsing(active: true)

                SkyPrimaryButton("Replay entrance") {
                    revealed = false
                    DispatchQueue.main.async { revealed = true }
                }
            }
            .padding(SkySpacing.s6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SkyColor.surface)
            .onAppear { revealed = true }
        }
    }
    return Demo()
}
