// NimbusView.swift
// Nimbus — Sky's cloud mascot. One silhouette, five states tied to user
// behavior (DESIGN_SYSTEM.md §8). Faithful SwiftUI Canvas translation of the
// prototype's `nimbus.jsx`; state changes morph over ~0.5s (§8), or crossfade
// over 0.2s under Reduce Motion (Sky_App_Workflow.md §3.6). The palette,
// geometry, and interpolation live in NimbusRendering.swift.
//
// Together with NimbusRendering.swift this is the single replaceable mascot
// component — swapping it (e.g. for a Lottie file in v1.1+) only touches
// these two files.

import SwiftUI

// MARK: - State & expression

enum MascotState: String, CaseIterable, Sendable {
    case cloudyGrey   // Default · not yet verified today
    case fluffyWhite  // Idle · under budget
    case sunny        // After a successful verification
    case rainbow      // Streak milestone reached
    case rainy        // Emergency unlock used

    var displayName: String {
        switch self {
        case .cloudyGrey: "Cloudy"
        case .fluffyWhite: "Fluffy"
        case .sunny: "Sunny"
        case .rainbow: "Rainbow"
        case .rainy: "Rainy"
        }
    }

    var hint: String {
        switch self {
        case .cloudyGrey: "Default · not yet verified"
        case .fluffyWhite: "Idle · under budget"
        case .sunny: "After verification"
        case .rainbow: "Streak milestone"
        case .rainy: "Emergency unlock"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .cloudyGrey: "Nimbus looks cloudy and grey."
        case .fluffyWhite: "Nimbus is a fluffy white cloud."
        case .sunny: "Nimbus is sunny and beaming."
        case .rainbow: "Nimbus is celebrating with a rainbow."
        case .rainy: "Nimbus is rainy and sad."
        }
    }
}

enum NimbusExpression: Sendable {
    case happy, neutral, beaming, sad
}

// MARK: - View

struct NimbusView: View {
    var state: MascotState = .fluffyWhite
    var size: CGFloat = 180
    var expressionOverride: NimbusExpression? = nil
    /// Renders the canonical frozen pose with no live timeline — for
    /// ImageRenderer exports (NimbusPNGExporter) and fixed-pose previews.
    var isStatic: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fromState: MascotState? = nil
    @State private var morphProgress: Double = 1

    /// Idle loops freeze on first frame under Reduce Motion (Workflow §3.6).
    private var idleFrozen: Bool { reduceMotion || isStatic }

    var body: some View {
        // 24fps cap: the idle motion is gentle enough that display-rate
        // updates would only cost battery. `paused` renders exactly one frame.
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: idleFrozen)) { timeline in
            let time: TimeInterval? =
                idleFrozen ? nil : timeline.date.timeIntervalSinceReferenceDate
            NimbusCanvas(
                from: fromState ?? state,
                to: state,
                progress: morphProgress,
                time: time,
                crossfadeOnly: reduceMotion,
                expressionOverride: expressionOverride
            )
            .frame(width: size, height: size * 0.78)
            .offset(y: NimbusIdle.bobOffset(at: time))
        }
        .onChange(of: state) { oldState, _ in
            beginMorph(from: oldState)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(state.accessibilityDescription))
    }

    /// Restarts the morph from the state that was just replaced. The reset to
    /// progress 0 renders the old state unchanged for one frame; the animated
    /// write to 1 is deferred a runloop turn so it can't coalesce with the
    /// reset (a same-turn write would animate 1 → 1, i.e. not at all). An
    /// interrupted morph snaps to its endpoint and restarts from there.
    private func beginMorph(from oldState: MascotState) {
        fromState = oldState
        var noAnimation = Transaction()
        noAnimation.disablesAnimations = true
        withTransaction(noAnimation) { morphProgress = 0 }
        let animation = reduceMotion ? SkyMotion.morphReducedEase : SkyMotion.morphEase
        Task { @MainActor in
            withAnimation(animation) { morphProgress = 1 }
        }
    }
}

/// Animatable canvas: SwiftUI interpolates `progress` per frame (the morph)
/// while the enclosing TimelineView refreshes `time` (the idle loops); either
/// source of change re-renders the drawing through NimbusRenderer.
private struct NimbusCanvas: View, Animatable {
    var from: MascotState
    var to: MascotState
    var progress: Double
    var time: TimeInterval?
    var crossfadeOnly: Bool
    var expressionOverride: NimbusExpression?

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 200
            ctx.scaleBy(x: s, y: s)
            NimbusRenderer.render(
                &ctx,
                from: from,
                to: to,
                t: progress,
                time: time,
                crossfadeOnly: crossfadeOnly,
                expressionOverride: expressionOverride
            )
        }
    }
}

// MARK: - Inline avatar

/// Small mascot avatar for inline use (status banners, buttons).
struct NimbusMini: View {
    var state: MascotState = .fluffyWhite
    var size: CGFloat = 40
    var body: some View { NimbusView(state: state, size: size) }
}

#Preview("Nimbus — 5 states") {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            ForEach(MascotState.allCases, id: \.self) { state in
                VStack(spacing: 6) {
                    NimbusView(state: state, size: 110)
                        .frame(height: 110)
                    Text(state.displayName).skyText(.label)
                    Text(state.hint).skyText(.caption, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 130)
            }
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SkyColor.surface)
}

#Preview("Nimbus — morph cycle") {
    struct MorphDemo: View {
        @State private var index = 0
        private let states = MascotState.allCases
        private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

        var body: some View {
            VStack(spacing: 16) {
                NimbusView(state: states[index], size: 200)
                Text(states[index].displayName).skyText(.headline)
                Text("Cycles every 2s — each pair should morph over 0.5s")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SkyColor.surface)
            .onReceive(timer) { _ in index = (index + 1) % states.count }
        }
    }
    return MorphDemo()
}
