// SkyConfettiBurst.swift
// One-shot celebration confetti for S-VER-06 ("Confetti optional — Reduce
// Motion off") and S-CEL-02. Native Canvas + TimelineView; a single gentle
// burst that drifts down like snowfall and then stops for good, honoring the
// "no infinite decorative animation" rule (DESIGN_SYSTEM.md principle 6).
// Callers gate it with `if !reduceMotion`. Colors are the four prototype
// confetti-dot tokens (Sky-handoff screens-verify.jsx).

import SwiftUI

// MARK: - Particle model (pure, deterministic, unit-tested)

/// One confetti piece. All geometry is in unit space (x, y ∈ [0, 1] of the
/// canvas) so the same burst scales to any container.
struct ConfettiParticle: Equatable {
    let start: CGPoint          // spawn point; y slightly above/at the top
    let velocity: CGVector      // unit/s; gentle downward drift
    let swayAmplitude: Double   // unit; side-to-side breeze
    let swayFrequency: Double   // Hz
    let size: CGFloat           // pt (4…8, the prototype dot sizes)
    let isRect: Bool            // a few 2:1 rounded rects among the circles
    let spin: Double            // rad/s, rects only
    let colorIndex: Int         // into SkyConfettiBurst.palette
    let delay: TimeInterval     // stagger before this piece appears
    let lifetime: TimeInterval  // seconds visible after its delay

    static let gravity = 0.25   // unit/s²
    static let baseOpacity = 0.7 // prototype dot opacity

    /// Unit-space position `t` seconds after the burst started, or nil while
    /// the particle hasn't spawned yet / after its lifetime ended.
    func unitPosition(at t: TimeInterval) -> CGPoint? {
        let alive = t - delay
        guard alive >= 0, alive <= lifetime else { return nil }
        let x = Double(start.x) + velocity.dx * alive
            + swayAmplitude * sin(2 * .pi * swayFrequency * alive)
        let y = Double(start.y) + velocity.dy * alive
            + 0.5 * Self.gravity * alive * alive
        return CGPoint(x: x, y: y)
    }

    /// 0…0.7: fades in quickly, holds, fades out over the last 30% of life.
    func opacity(at t: TimeInterval) -> Double {
        let alive = t - delay
        guard alive >= 0, alive <= lifetime else { return 0 }
        let fadeIn = min(1, alive / 0.15)
        let remaining = lifetime - alive
        let fadeOut = min(1, remaining / (lifetime * 0.3))
        return Self.baseOpacity * fadeIn * fadeOut
    }

    /// Deterministic burst: the same `count` + `seed` always produce the same
    /// particles (testable; previews don't flicker between renders).
    static func burst(count: Int, seed: UInt64) -> [ConfettiParticle] {
        var rng = SplitMix64(seed: seed)
        return (0..<count).map { i in
            ConfettiParticle(
                start: CGPoint(x: Double.random(in: 0...1, using: &rng),
                               y: Double.random(in: -0.05...0.15, using: &rng)),
                velocity: CGVector(dx: Double.random(in: -0.02...0.02, using: &rng),
                                   dy: Double.random(in: 0.05...0.15, using: &rng)),
                swayAmplitude: Double.random(in: 0.01...0.04, using: &rng),
                swayFrequency: Double.random(in: 0.5...1.2, using: &rng),
                size: CGFloat(Double.random(in: 4...8, using: &rng)),
                isRect: i % 4 == 3,   // every fourth piece is a spinning rect
                spin: Double.random(in: -2...2, using: &rng),
                colorIndex: i % 4,
                delay: Double.random(in: 0...0.4, using: &rng),
                lifetime: Double.random(in: 2.0...3.0, using: &rng)
            )
        }
    }
}

/// Tiny deterministic RNG (SplitMix64) so bursts are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - View

/// A single confetti burst overlay. Non-interactive, invisible to VoiceOver,
/// and self-pausing: once every particle's delay + lifetime has elapsed the
/// timeline stops updating entirely.
struct SkyConfettiBurst: View {
    private let particles: [ConfettiParticle]
    private let totalDuration: TimeInterval

    @State private var startDate: Date? = nil
    @State private var finished = false

    /// Prototype confetti palette (#FF8A7A #FFD66B #7CB342 #A8D8EA) via tokens.
    static let palette: [Color] = [
        SkyColor.coralStreak, SkyColor.sunYellow, SkyColor.mossGreen, SkyColor.primarySky,
    ]

    init(count: Int = 28, seed: UInt64 = 0x5EED_C10D) {
        let burst = ConfettiParticle.burst(count: count, seed: seed)
        particles = burst
        totalDuration = burst.map { $0.delay + $0.lifetime }.max() ?? 0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: finished)) { timeline in
            Canvas { ctx, size in
                guard let startDate, !finished else { return }
                let t = timeline.date.timeIntervalSince(startDate)
                for particle in particles {
                    guard let unit = particle.unitPosition(at: t) else { continue }
                    let alpha = particle.opacity(at: t)
                    guard alpha > 0 else { continue }
                    let color = Self.palette[particle.colorIndex].opacity(alpha)
                    let pos = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
                    if particle.isRect {
                        var piece = ctx
                        piece.translateBy(x: pos.x, y: pos.y)
                        piece.rotate(by: .radians(particle.spin * max(0, t - particle.delay)))
                        let rect = CGRect(x: -particle.size / 2, y: -particle.size / 4,
                                          width: particle.size, height: particle.size / 2)
                        piece.fill(Path(roundedRect: rect, cornerRadius: particle.size / 8),
                                   with: .color(color))
                    } else {
                        let r = particle.size / 2
                        let rect = CGRect(x: pos.x - r, y: pos.y - r,
                                          width: particle.size, height: particle.size)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .onAppear {
            startDate = Date()
            Task {
                try? await Task.sleep(for: .seconds(totalDuration + 0.1))
                finished = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Confetti burst") {
    ZStack {
        SkyColor.surface.ignoresSafeArea()
        Text("🎉 behind this text")
            .skyText(.headline, color: SkyColor.inkSoft)
        SkyConfettiBurst()
            .ignoresSafeArea()
    }
}
