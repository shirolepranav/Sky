// NimbusRendering.swift
// Nimbus render model, interpolation math, and Canvas drawing. Together with
// NimbusView.swift this is the single replaceable mascot component
// (DESIGN_SYSTEM.md §8) — swapping the mascot (e.g. a Lottie file in v1.1+)
// must touch only these two files.
//
// The ~0.5s state morph (§8) lerps colors and stroked-quad features and
// staggered-crossfades discrete features (filled eyes/mouth, accessories) so
// heavy ink never double-draws. Under Reduce Motion the two complete states
// crossfade as flattened layers over 0.2s instead (Sky_App_Workflow.md §3.6).
// All geometry lives in the prototype's 200×156 viewBox (nimbus.jsx).

import Foundation
import SwiftUI

// MARK: - Interpolable color

/// sRGB components kept as plain doubles so state palettes can lerp.
/// Only used for the state-dependent colors (cloud fill/shadow, cheeks) —
/// the face ink stays `SkyColor.ink` so it keeps adapting to dark mode.
struct NimbusRGBA: Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// 6-digit hex, matching the values previously passed to `Color(hex:)`.
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    static func lerp(_ x: Self, _ y: Self, _ t: Double) -> Self {
        Self(
            NimbusMorphMath.lerp(x.r, y.r, t),
            NimbusMorphMath.lerp(x.g, y.g, t),
            NimbusMorphMath.lerp(x.b, y.b, t),
            NimbusMorphMath.lerp(x.a, y.a, t)
        )
    }
}

// MARK: - Scalar / point lerp + crossfade ramps

enum NimbusMorphMath {
    // The two-coefficient form is exact at both endpoints (t = 0 draws `a`
    // bit-for-bit, t = 1 draws `b`), unlike `a + (b - a) * t`.
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a * CGFloat(1 - t) + b * CGFloat(t)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a * (1 - t) + b * t
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let u = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Discrete-feature crossfade: outgoing ink fades 1 → 0 over t ∈ [0, 0.45].
    static func outgoingAlpha(_ t: Double) -> Double {
        1 - smoothstep(0, 0.45, t)
    }

    /// Discrete-feature crossfade: incoming ink fades 0 → 1 over t ∈ [0.55, 1].
    static func incomingAlpha(_ t: Double) -> Double {
        smoothstep(0.55, 1, t)
    }
}

// MARK: - Face geometry specs

/// One stroked quad curve (an eye arc or a mouth line).
struct NimbusQuadSpec: Equatable {
    var a: CGPoint
    var b: CGPoint
    var control: CGPoint
    var width: CGFloat

    static func lerp(_ x: Self, _ y: Self, _ t: Double) -> Self {
        Self(
            a: NimbusMorphMath.lerp(x.a, y.a, t),
            b: NimbusMorphMath.lerp(x.b, y.b, t),
            control: NimbusMorphMath.lerp(x.control, y.control, t),
            width: NimbusMorphMath.lerp(x.width, y.width, t)
        )
    }
}

enum NimbusEyeSpec: Equatable {
    /// Happy: filled ink circles with white glints.
    case circles
    /// Neutral / beaming / sad: stroked arcs.
    case arcs(left: NimbusQuadSpec, right: NimbusQuadSpec)

    static func spec(for expr: NimbusExpression) -> NimbusEyeSpec {
        switch expr {
        case .happy:
            return .circles
        case .neutral:
            return .arcs(
                left: .init(a: CGPoint(x: 78, y: 70), b: CGPoint(x: 86, y: 70),
                            control: CGPoint(x: 82, y: 67), width: 2.5),
                right: .init(a: CGPoint(x: 114, y: 70), b: CGPoint(x: 122, y: 70),
                             control: CGPoint(x: 118, y: 67), width: 2.5)
            )
        case .beaming:
            return .arcs(
                left: .init(a: CGPoint(x: 76, y: 72), b: CGPoint(x: 88, y: 72),
                            control: CGPoint(x: 82, y: 66), width: 2.8),
                right: .init(a: CGPoint(x: 112, y: 72), b: CGPoint(x: 124, y: 72),
                             control: CGPoint(x: 118, y: 66), width: 2.8)
            )
        case .sad:
            return .arcs(
                left: .init(a: CGPoint(x: 76, y: 74), b: CGPoint(x: 88, y: 74),
                            control: CGPoint(x: 82, y: 78), width: 2.5),
                right: .init(a: CGPoint(x: 112, y: 74), b: CGPoint(x: 124, y: 74),
                             control: CGPoint(x: 118, y: 78), width: 2.5)
            )
        }
    }
}

enum NimbusMouthSpec: Equatable {
    /// Happy / neutral / sad: one stroked quad.
    case stroked(NimbusQuadSpec)
    /// Beaming: the filled open-smile shape.
    case beamingFill

    static func spec(for expr: NimbusExpression) -> NimbusMouthSpec {
        switch expr {
        case .happy:
            return .stroked(.init(a: CGPoint(x: 92, y: 84), b: CGPoint(x: 108, y: 84),
                                  control: CGPoint(x: 100, y: 90), width: 2.5))
        case .neutral:
            return .stroked(.init(a: CGPoint(x: 94, y: 86), b: CGPoint(x: 106, y: 86),
                                  control: CGPoint(x: 100, y: 88), width: 2.2))
        case .beaming:
            return .beamingFill
        case .sad:
            return .stroked(.init(a: CGPoint(x: 92, y: 90), b: CGPoint(x: 108, y: 90),
                                  control: CGPoint(x: 100, y: 84), width: 2.5))
        }
    }
}

// MARK: - Render model

/// Everything continuous about one mascot state, ready to draw or to lerp.
struct NimbusRenderModel: Equatable {
    var fill: NimbusRGBA
    var shadow: NimbusRGBA
    var cheekColor: NimbusRGBA
    var cheekAlpha: Double     // effective (sad ×0.6 baked in)
    var cheekLeft: CGPoint
    var cheekRight: CGPoint
    var cheekRX: CGFloat
    var cheekRY: CGFloat
    var highlightOpacity: Double
    var sunOpacity: Double
    var rainbowOpacity: Double
    var rainOpacity: Double
    var expr: NimbusExpression

    private static let coralCheek = NimbusRGBA(1, 138 / 255, 122 / 255)
    private static let greyCheek = NimbusRGBA(120 / 255, 140 / 255, 160 / 255)

    static func model(
        for state: MascotState,
        expressionOverride: NimbusExpression? = nil
    ) -> NimbusRenderModel {
        let fill: NimbusRGBA
        let shadow: NimbusRGBA
        let cheekColor: NimbusRGBA
        let baseCheekAlpha: Double
        let defaultExpr: NimbusExpression
        var sun = 0.0, rainbow = 0.0, rain = 0.0

        switch state {
        case .fluffyWhite:
            fill = NimbusRGBA(hex: "FFFFFF"); shadow = NimbusRGBA(hex: "E8F0F5")
            cheekColor = coralCheek; baseCheekAlpha = 0.4; defaultExpr = .happy
        case .cloudyGrey:
            fill = NimbusRGBA(hex: "B8C5D0"); shadow = NimbusRGBA(hex: "9BA9B6")
            cheekColor = coralCheek; baseCheekAlpha = 0.25; defaultExpr = .neutral
        case .sunny:
            fill = NimbusRGBA(hex: "FFFFFF"); shadow = NimbusRGBA(hex: "FFF4D6")
            cheekColor = coralCheek; baseCheekAlpha = 0.55; defaultExpr = .beaming
            sun = 1
        case .rainbow:
            fill = NimbusRGBA(hex: "FFFFFF"); shadow = NimbusRGBA(hex: "F5E8FF")
            cheekColor = coralCheek; baseCheekAlpha = 0.55; defaultExpr = .beaming
            rainbow = 1
        case .rainy:
            fill = NimbusRGBA(hex: "A8B5C2"); shadow = NimbusRGBA(hex: "8A98A6")
            cheekColor = greyCheek; baseCheekAlpha = 0.3; defaultExpr = .sad
            rain = 1
        }

        let expr = expressionOverride ?? defaultExpr
        let sad = expr == .sad
        return NimbusRenderModel(
            fill: fill,
            shadow: shadow,
            cheekColor: cheekColor,
            cheekAlpha: sad ? baseCheekAlpha * 0.6 : baseCheekAlpha,
            cheekLeft: sad ? CGPoint(x: 76, y: 86) : CGPoint(x: 74, y: 82),
            cheekRight: sad ? CGPoint(x: 124, y: 86) : CGPoint(x: 126, y: 82),
            cheekRX: sad ? 6 : 7,
            cheekRY: sad ? 3.5 : 4,
            highlightOpacity: (expr == .neutral || expr == .sad) ? 0.15 : 0.4,
            sunOpacity: sun,
            rainbowOpacity: rainbow,
            rainOpacity: rain,
            expr: expr
        )
    }

    /// Lerps every continuous field; `expr` stays discrete (the drawing layer
    /// handles expressions from the two endpoint models).
    static func lerp(_ a: Self, _ b: Self, _ t: Double) -> Self {
        NimbusRenderModel(
            fill: .lerp(a.fill, b.fill, t),
            shadow: .lerp(a.shadow, b.shadow, t),
            cheekColor: .lerp(a.cheekColor, b.cheekColor, t),
            cheekAlpha: NimbusMorphMath.lerp(a.cheekAlpha, b.cheekAlpha, t),
            cheekLeft: NimbusMorphMath.lerp(a.cheekLeft, b.cheekLeft, t),
            cheekRight: NimbusMorphMath.lerp(a.cheekRight, b.cheekRight, t),
            cheekRX: NimbusMorphMath.lerp(a.cheekRX, b.cheekRX, t),
            cheekRY: NimbusMorphMath.lerp(a.cheekRY, b.cheekRY, t),
            highlightOpacity: NimbusMorphMath.lerp(a.highlightOpacity, b.highlightOpacity, t),
            sunOpacity: NimbusMorphMath.lerp(a.sunOpacity, b.sunOpacity, t),
            rainbowOpacity: NimbusMorphMath.lerp(a.rainbowOpacity, b.rainbowOpacity, t),
            rainOpacity: NimbusMorphMath.lerp(a.rainOpacity, b.rainOpacity, t),
            expr: t < 0.5 ? a.expr : b.expr
        )
    }
}

// MARK: - Renderer

/// Draws Nimbus into a `GraphicsContext` already scaled to the 200×156 space.
enum NimbusRenderer {
    private static var ink: Color { SkyColor.ink }

    /// Entry point. `t == 1` (or `from == to`) draws the target state exactly
    /// as the pre-morph implementation did; `crossfadeOnly` is the Reduce
    /// Motion path (flattened whole-mascot crossfade, Workflow §3.6).
    static func render(
        _ ctx: inout GraphicsContext,
        from: MascotState,
        to: MascotState,
        t: Double,
        crossfadeOnly: Bool,
        expressionOverride: NimbusExpression? = nil
    ) {
        let toModel = NimbusRenderModel.model(for: to, expressionOverride: expressionOverride)
        guard from != to, t < 1 else {
            drawState(&ctx, model: toModel)
            return
        }
        let fromModel = NimbusRenderModel.model(for: from, expressionOverride: expressionOverride)

        if crossfadeOnly {
            ctx.drawLayer { layer in
                layer.opacity = 1 - t
                drawState(&layer, model: fromModel)
            }
            ctx.drawLayer { layer in
                layer.opacity = t
                drawState(&layer, model: toModel)
            }
            return
        }

        let blended = NimbusRenderModel.lerp(fromModel, toModel, t)

        // Accessories: each state's own accessory, faded out / in.
        drawAccessories(&ctx, model: fromModel, opacity: 1 - t)
        drawAccessories(&ctx, model: toModel, opacity: t)

        drawCloud(&ctx, model: blended)
        drawFaceMorph(&ctx, from: fromModel, to: toModel, blended: blended, t: t)
    }

    // MARK: Single-state drawing (t = 0 or 1)

    static func drawState(_ ctx: inout GraphicsContext, model: NimbusRenderModel) {
        drawAccessories(&ctx, model: model, opacity: 1)
        drawCloud(&ctx, model: model)
        drawFace(&ctx, model: model)
    }

    private static func drawAccessories(
        _ ctx: inout GraphicsContext, model: NimbusRenderModel, opacity: Double
    ) {
        if model.sunOpacity > 0 { drawSun(&ctx, opacity: model.sunOpacity * opacity) }
        if model.rainbowOpacity > 0 { drawRainbow(&ctx, opacity: model.rainbowOpacity * opacity) }
        if model.rainOpacity > 0 { drawRain(&ctx, opacity: model.rainOpacity * opacity) }
    }

    // MARK: Primitive helpers

    private static func fillEllipse(
        _ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat,
        _ rx: CGFloat, _ ry: CGFloat, _ color: Color, _ opacity: Double = 1
    ) {
        let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
    }

    private static func fillCircle(
        _ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat,
        _ r: CGFloat, _ color: Color, _ opacity: Double = 1
    ) {
        fillEllipse(&ctx, cx, cy, r, r, color, opacity)
    }

    private static func quadPath(_ spec: NimbusQuadSpec) -> Path {
        var p = Path()
        p.move(to: spec.a)
        p.addQuadCurve(to: spec.b, control: spec.control)
        return p
    }

    private static func strokeQuad(
        _ ctx: inout GraphicsContext, _ spec: NimbusQuadSpec, alpha: Double = 1
    ) {
        ctx.stroke(
            quadPath(spec), with: .color(ink.opacity(alpha)),
            style: StrokeStyle(lineWidth: spec.width, lineCap: .round)
        )
    }

    // MARK: Background accessories

    private static func drawSun(_ ctx: inout GraphicsContext, opacity: Double) {
        guard opacity > 0 else { return }
        let sun = SkyColor.sunYellow
        fillCircle(&ctx, 100, 80, 62, sun, 0.35 * opacity)
        fillCircle(&ctx, 100, 80, 48, sun, 0.5 * opacity)
        let ray = Path(roundedRect: CGRect(x: 98, y: -6, width: 4, height: 14), cornerRadius: 2)
        for deg in stride(from: 0, to: 360, by: 45) {
            let rad = CGFloat(deg) * .pi / 180
            var t = CGAffineTransform.identity
            t = t.translatedBy(x: 100, y: 80)
            t = t.rotated(by: rad)
            t = t.translatedBy(x: -100, y: -80)
            ctx.fill(ray.applying(t), with: .color(sun.opacity(0.85 * opacity)))
        }
    }

    private static func drawRainbow(_ ctx: inout GraphicsContext, opacity: Double) {
        guard opacity > 0 else { return }
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
            ctx.stroke(
                p, with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
        }
        // sparkles
        let sun = SkyColor.sunYellow
        fillCircle(&ctx, 25, 40, 2.5, sun, opacity)
        fillCircle(&ctx, 175, 50, 2, sun, opacity)
        fillCircle(&ctx, 15, 90, 1.8, sun, opacity)
        fillCircle(&ctx, 185, 100, 2.2, sun, opacity)
    }

    private static func drawRain(_ ctx: inout GraphicsContext, opacity: Double) {
        guard opacity > 0 else { return }
        let drop = Color(hex: "7BB3D6")
        let drops: [(CGFloat, CGFloat, CGFloat)] = [
            (55, 120, 14), (75, 130, 12), (100, 122, 16), (125, 132, 12), (145, 118, 14),
        ]
        for (x, y, h) in drops {
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x, y: y + h), control: CGPoint(x: x - 3, y: y + h / 2))
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + 3, y: y + h / 2))
            ctx.fill(p, with: .color(drop.opacity(0.85 * opacity)))
        }
    }

    // MARK: Cloud body

    private static func drawCloud(_ ctx: inout GraphicsContext, model: NimbusRenderModel) {
        let shadow = model.shadow.color
        let fill = model.fill.color

        // Soft shadow (group translated down 2px)
        fillEllipse(&ctx, 100, 94, 78, 28, shadow, 0.6)
        fillCircle(&ctx, 60, 77, 28, shadow, 0.6)
        fillCircle(&ctx, 100, 57, 38, shadow, 0.6)
        fillCircle(&ctx, 140, 72, 32, shadow, 0.6)

        // Main fill
        fillEllipse(&ctx, 100, 90, 78, 28, fill)
        fillCircle(&ctx, 60, 73, 28, fill)
        fillCircle(&ctx, 100, 53, 38, fill)
        fillCircle(&ctx, 140, 68, 32, fill)
    }

    // MARK: Face

    private static func drawHighlightAndCheeks(
        _ ctx: inout GraphicsContext, model: NimbusRenderModel
    ) {
        // Top-left highlight (dimmer on grey/rainy)
        fillEllipse(&ctx, 78, 42, 14, 6, .white, model.highlightOpacity)

        // Cheeks
        fillEllipse(&ctx, model.cheekLeft.x, model.cheekLeft.y,
                    model.cheekRX, model.cheekRY, model.cheekColor.color, model.cheekAlpha)
        fillEllipse(&ctx, model.cheekRight.x, model.cheekRight.y,
                    model.cheekRX, model.cheekRY, model.cheekColor.color, model.cheekAlpha)
    }

    private static func drawFace(_ ctx: inout GraphicsContext, model: NimbusRenderModel) {
        drawHighlightAndCheeks(&ctx, model: model)
        drawEyes(&ctx, spec: .spec(for: model.expr), alpha: 1)
        drawMouth(&ctx, spec: .spec(for: model.expr), alpha: 1)
    }

    private static func drawFaceMorph(
        _ ctx: inout GraphicsContext,
        from: NimbusRenderModel, to: NimbusRenderModel,
        blended: NimbusRenderModel, t: Double
    ) {
        drawHighlightAndCheeks(&ctx, model: blended)

        // Eyes: lerp arcs↔arcs, crossfade anything involving filled circles.
        let fromEyes = NimbusEyeSpec.spec(for: from.expr)
        let toEyes = NimbusEyeSpec.spec(for: to.expr)
        if case let .arcs(fl, fr) = fromEyes, case let .arcs(tl, tr) = toEyes {
            drawEyes(&ctx, spec: .arcs(left: .lerp(fl, tl, t), right: .lerp(fr, tr, t)), alpha: 1)
        } else if fromEyes == toEyes {
            drawEyes(&ctx, spec: toEyes, alpha: 1)
        } else {
            drawEyes(&ctx, spec: fromEyes, alpha: NimbusMorphMath.outgoingAlpha(t))
            drawEyes(&ctx, spec: toEyes, alpha: NimbusMorphMath.incomingAlpha(t))
        }

        // Mouth: same rules.
        let fromMouth = NimbusMouthSpec.spec(for: from.expr)
        let toMouth = NimbusMouthSpec.spec(for: to.expr)
        if case let .stroked(fq) = fromMouth, case let .stroked(tq) = toMouth {
            drawMouth(&ctx, spec: .stroked(.lerp(fq, tq, t)), alpha: 1)
        } else if fromMouth == toMouth {
            drawMouth(&ctx, spec: toMouth, alpha: 1)
        } else {
            drawMouth(&ctx, spec: fromMouth, alpha: NimbusMorphMath.outgoingAlpha(t))
            drawMouth(&ctx, spec: toMouth, alpha: NimbusMorphMath.incomingAlpha(t))
        }
    }

    private static func drawEyes(
        _ ctx: inout GraphicsContext, spec: NimbusEyeSpec, alpha: Double
    ) {
        guard alpha > 0 else { return }
        switch spec {
        case .circles:
            fillCircle(&ctx, 82, 70, 4, ink, alpha)
            fillCircle(&ctx, 118, 70, 4, ink, alpha)
            fillCircle(&ctx, 83.5, 68.5, 1.3, .white, alpha)
            fillCircle(&ctx, 119.5, 68.5, 1.3, .white, alpha)
        case let .arcs(left, right):
            strokeQuad(&ctx, left, alpha: alpha)
            strokeQuad(&ctx, right, alpha: alpha)
        }
    }

    private static func drawMouth(
        _ ctx: inout GraphicsContext, spec: NimbusMouthSpec, alpha: Double
    ) {
        guard alpha > 0 else { return }
        switch spec {
        case let .stroked(quad):
            strokeQuad(&ctx, quad, alpha: alpha)
        case .beamingFill:
            var p = Path()
            p.move(to: CGPoint(x: 88, y: 82))
            p.addQuadCurve(to: CGPoint(x: 112, y: 82), control: CGPoint(x: 100, y: 96))
            p.addQuadCurve(to: CGPoint(x: 88, y: 82), control: CGPoint(x: 100, y: 90))
            p.closeSubpath()
            ctx.fill(p, with: .color(ink.opacity(alpha)))
        }
    }
}
