// NimbusView.swift
// Nimbus — Sky's cloud mascot. One silhouette, five states tied to user
// behavior (DESIGN_SYSTEM.md §8). Faithful SwiftUI Canvas translation of the
// prototype's `nimbus.jsx`, drawn in the original 200×156 viewBox and scaled to
// the requested size.
//
// This is the single replaceable mascot component — swapping it (e.g. for a
// Lottie file in v1.1+) only touches this file.

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        Canvas { ctx, canvasSize in
            draw(&ctx, size: canvasSize)
        }
        .frame(width: size, height: size * 0.78)
        .offset(y: bob ? -4 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(state.accessibilityDescription))
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / 200
        ctx.scaleBy(x: s, y: s)

        let cfg = NimbusConfig.config(for: state)
        let expr = expressionOverride ?? cfg.expr

        switch state {
        case .sunny: drawSun(&ctx)
        case .rainbow: drawRainbow(&ctx)
        case .rainy: drawRain(&ctx)
        default: break
        }

        drawCloud(&ctx, cfg: cfg)
        drawFace(&ctx, cfg: cfg, expr: expr)
    }
}

// MARK: - State palette

private struct NimbusConfig {
    let fill: Color
    let shadow: Color
    let cheekRGB: Color // solid, alpha applied at draw time
    let cheekAlpha: Double
    let expr: NimbusExpression

    static func config(for state: MascotState) -> NimbusConfig {
        let coralCheek = Color(.sRGB, red: 1, green: 138/255, blue: 122/255)
        let greyCheek = Color(.sRGB, red: 120/255, green: 140/255, blue: 160/255)
        switch state {
        case .fluffyWhite:
            return .init(fill: Color(hex: "FFFFFF"), shadow: Color(hex: "E8F0F5"),
                         cheekRGB: coralCheek, cheekAlpha: 0.4, expr: .happy)
        case .cloudyGrey:
            return .init(fill: Color(hex: "B8C5D0"), shadow: Color(hex: "9BA9B6"),
                         cheekRGB: coralCheek, cheekAlpha: 0.25, expr: .neutral)
        case .sunny:
            return .init(fill: Color(hex: "FFFFFF"), shadow: Color(hex: "FFF4D6"),
                         cheekRGB: coralCheek, cheekAlpha: 0.55, expr: .beaming)
        case .rainbow:
            return .init(fill: Color(hex: "FFFFFF"), shadow: Color(hex: "F5E8FF"),
                         cheekRGB: coralCheek, cheekAlpha: 0.55, expr: .beaming)
        case .rainy:
            return .init(fill: Color(hex: "A8B5C2"), shadow: Color(hex: "8A98A6"),
                         cheekRGB: greyCheek, cheekAlpha: 0.3, expr: .sad)
        }
    }
}

// MARK: - Drawing helpers (operate in the 200×156 coordinate space)

private let nimbusInk = SkyColor.ink

private func fillEllipse(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat,
                         _ rx: CGFloat, _ ry: CGFloat, _ color: Color, _ opacity: Double = 1) {
    let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
}

private func fillCircle(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat,
                        _ r: CGFloat, _ color: Color, _ opacity: Double = 1) {
    fillEllipse(&ctx, cx, cy, r, r, color, opacity)
}

private func quad(_ a: CGPoint, _ b: CGPoint, _ control: CGPoint) -> Path {
    var p = Path()
    p.move(to: a)
    p.addQuadCurve(to: b, control: control)
    return p
}

private func strokeQuad(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint,
                        _ control: CGPoint, width: CGFloat, color: Color = nimbusInk) {
    ctx.stroke(quad(a, b, control), with: .color(color),
               style: StrokeStyle(lineWidth: width, lineCap: .round))
}

// MARK: - Background accessories

private func drawSun(_ ctx: inout GraphicsContext) {
    let sun = SkyColor.sunYellow
    fillCircle(&ctx, 100, 80, 62, sun, 0.35)
    fillCircle(&ctx, 100, 80, 48, sun, 0.5)
    let ray = Path(roundedRect: CGRect(x: 98, y: -6, width: 4, height: 14), cornerRadius: 2)
    for deg in stride(from: 0, to: 360, by: 45) {
        let rad = CGFloat(deg) * .pi / 180
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: 100, y: 80)
        t = t.rotated(by: rad)
        t = t.translatedBy(x: -100, y: -80)
        ctx.fill(ray.applying(t), with: .color(sun.opacity(0.85)))
    }
}

private func drawRainbow(_ ctx: inout GraphicsContext) {
    let bands: [(Color, CGFloat)] = [
        (SkyColor.coralStreak, 85),
        (SkyColor.sunYellow, 75),
        (SkyColor.mossGreen, 65),
        (SkyColor.primarySky, 55),
    ]
    for (color, r) in bands {
        var p = Path()
        let steps = 28
        for i in 0...steps {
            let theta = CGFloat.pi * (1 - CGFloat(i) / CGFloat(steps)) // π → 0 (left → top → right)
            let pt = CGPoint(x: 100 + r * cos(theta), y: 95 - r * sin(theta))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }
    // sparkles
    let sun = SkyColor.sunYellow
    fillCircle(&ctx, 25, 40, 2.5, sun)
    fillCircle(&ctx, 175, 50, 2, sun)
    fillCircle(&ctx, 15, 90, 1.8, sun)
    fillCircle(&ctx, 185, 100, 2.2, sun)
}

private func drawRain(_ ctx: inout GraphicsContext) {
    let drop = Color(hex: "7BB3D6")
    let drops: [(CGFloat, CGFloat, CGFloat)] = [
        (55, 120, 14), (75, 130, 12), (100, 122, 16), (125, 132, 12), (145, 118, 14),
    ]
    for (x, y, h) in drops {
        var p = Path()
        p.move(to: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y + h), control: CGPoint(x: x - 3, y: y + h / 2))
        p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + 3, y: y + h / 2))
        ctx.fill(p, with: .color(drop.opacity(0.85)))
    }
}

// MARK: - Cloud body & face

private func drawCloud(_ ctx: inout GraphicsContext, cfg: NimbusConfig) {
    // Soft shadow (group translated down 2px)
    fillEllipse(&ctx, 100, 94, 78, 28, cfg.shadow, 0.6)
    fillCircle(&ctx, 60, 77, 28, cfg.shadow, 0.6)
    fillCircle(&ctx, 100, 57, 38, cfg.shadow, 0.6)
    fillCircle(&ctx, 140, 72, 32, cfg.shadow, 0.6)

    // Main fill
    fillEllipse(&ctx, 100, 90, 78, 28, cfg.fill)
    fillCircle(&ctx, 60, 73, 28, cfg.fill)
    fillCircle(&ctx, 100, 53, 38, cfg.fill)
    fillCircle(&ctx, 140, 68, 32, cfg.fill)
}

private func drawFace(_ ctx: inout GraphicsContext, cfg: NimbusConfig, expr: NimbusExpression) {
    // Top-left highlight (dimmer on grey/rainy)
    let highlight = (expr == .neutral || expr == .sad) ? 0.15 : 0.4
    fillEllipse(&ctx, 78, 42, 14, 6, .white, highlight)

    // Cheeks
    if expr == .sad {
        fillEllipse(&ctx, 76, 86, 6, 3.5, cfg.cheekRGB, cfg.cheekAlpha * 0.6)
        fillEllipse(&ctx, 124, 86, 6, 3.5, cfg.cheekRGB, cfg.cheekAlpha * 0.6)
    } else {
        fillEllipse(&ctx, 74, 82, 7, 4, cfg.cheekRGB, cfg.cheekAlpha)
        fillEllipse(&ctx, 126, 82, 7, 4, cfg.cheekRGB, cfg.cheekAlpha)
    }

    // Eyes
    switch expr {
    case .happy:
        fillCircle(&ctx, 82, 70, 4, nimbusInk)
        fillCircle(&ctx, 118, 70, 4, nimbusInk)
        fillCircle(&ctx, 83.5, 68.5, 1.3, .white)
        fillCircle(&ctx, 119.5, 68.5, 1.3, .white)
    case .neutral:
        strokeQuad(&ctx, CGPoint(x: 78, y: 70), CGPoint(x: 86, y: 70), CGPoint(x: 82, y: 67), width: 2.5)
        strokeQuad(&ctx, CGPoint(x: 114, y: 70), CGPoint(x: 122, y: 70), CGPoint(x: 118, y: 67), width: 2.5)
    case .beaming:
        strokeQuad(&ctx, CGPoint(x: 76, y: 72), CGPoint(x: 88, y: 72), CGPoint(x: 82, y: 66), width: 2.8)
        strokeQuad(&ctx, CGPoint(x: 112, y: 72), CGPoint(x: 124, y: 72), CGPoint(x: 118, y: 66), width: 2.8)
    case .sad:
        strokeQuad(&ctx, CGPoint(x: 76, y: 74), CGPoint(x: 88, y: 74), CGPoint(x: 82, y: 78), width: 2.5)
        strokeQuad(&ctx, CGPoint(x: 112, y: 74), CGPoint(x: 124, y: 74), CGPoint(x: 118, y: 78), width: 2.5)
    }

    // Mouth
    switch expr {
    case .happy:
        strokeQuad(&ctx, CGPoint(x: 92, y: 84), CGPoint(x: 108, y: 84), CGPoint(x: 100, y: 90), width: 2.5)
    case .neutral:
        strokeQuad(&ctx, CGPoint(x: 94, y: 86), CGPoint(x: 106, y: 86), CGPoint(x: 100, y: 88), width: 2.2)
    case .beaming:
        var p = Path()
        p.move(to: CGPoint(x: 88, y: 82))
        p.addQuadCurve(to: CGPoint(x: 112, y: 82), control: CGPoint(x: 100, y: 96))
        p.addQuadCurve(to: CGPoint(x: 88, y: 82), control: CGPoint(x: 100, y: 90))
        p.closeSubpath()
        ctx.fill(p, with: .color(nimbusInk))
    case .sad:
        strokeQuad(&ctx, CGPoint(x: 92, y: 90), CGPoint(x: 108, y: 90), CGPoint(x: 100, y: 84), width: 2.5)
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
