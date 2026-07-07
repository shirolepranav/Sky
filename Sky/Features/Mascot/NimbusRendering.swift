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

// MARK: - Idle micro-animation math

/// Deterministic pure functions of wall-clock time driving the idle
/// micro-animations (CLAUDE.md rule 6: subtle motion only). Passing `nil`
/// time anywhere yields the canonical static pose — which is exactly the
/// frozen frame Reduce Motion requires (Workflow §3.6 "idle loops freeze
/// on first frame").
enum NimbusIdle {
    /// Vertical bob: full sine cycle over `SkyMotion.bobPeriod`, 0…−4pt like
    /// the original ease-in-out loop.
    static func bobOffset(at time: TimeInterval?) -> CGFloat {
        guard let time else { return 0 }
        return CGFloat(-2 - 2 * sin(2 * .pi * time / SkyMotion.bobPeriod))
    }

    /// Eye openness 1…0.15…1. Blinks last 0.12s at the start of each 4s
    /// cycle, skipped pseudo-randomly so the rhythm feels organic (~3–5s
    /// apart on average).
    static func blink(at time: TimeInterval?) -> Double {
        guard let time else { return 1 }
        let cycle: TimeInterval = 4
        let blinkDuration: TimeInterval = 0.12
        let n = (time / cycle).rounded(.down)
        // Hash the cycle index into [0, 1); skip ~1 in 5 blinks.
        let jitter = (sin(n * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        guard abs(jitter) > 0.2 else { return 1 }
        let phase = time - n * cycle
        guard phase < blinkDuration else { return 1 }
        let p = phase / blinkDuration          // 0…1 through the blink
        let closed = 0.15
        return p < 0.5
            ? 1 - (1 - closed) * (p * 2)       // closing
            : closed + (1 - closed) * ((p - 0.5) * 2) // opening
    }

    /// Cloud "breathing": ±1% scale, 5s period.
    static func breathScale(at time: TimeInterval?) -> CGFloat {
        guard let time else { return 1 }
        return CGFloat(1 + 0.01 * sin(2 * .pi * time / 5))
    }

    /// Sun-ray rotation: one calm revolution per minute.
    static func sunRayAngle(at time: TimeInterval?) -> CGFloat {
        guard let time else { return 0 }
        return CGFloat(time.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi)
    }

    /// Falling offset for rain drop `index`: 0…18pt below its resting spot,
    /// staggered per drop, looping.
    static func rainDropFall(index: Int, at time: TimeInterval?) -> CGFloat {
        guard let time else { return 0 }
        let stagger = Double(index) * 3.7
        return CGFloat((time * 22 + stagger * 18 / 5).truncatingRemainder(dividingBy: 18))
    }

    /// Rain drop visibility 0…1: triangle-peaks mid-fall so drops fade in
    /// near the cloud and out near the bottom of the band.
    static func rainDropVisibility(fall: CGFloat) -> Double {
        1 - abs(Double(fall) / 18 * 2 - 1)
    }

    /// Sparkle twinkle 0.1…1 for sparkle `index`.
    static func sparkleAlpha(index: Int, at time: TimeInterval?) -> Double {
        guard let time else { return 1 }
        let phase = Double(index) * 1.6
        return 0.55 + 0.45 * sin(time * 2 + phase)
    }

    /// Sparkle radius modulation ±15%.
    static func sparkleRadiusScale(index: Int, at time: TimeInterval?) -> CGFloat {
        guard let time else { return 1 }
        let phase = Double(index) * 1.6 + 0.8
        return CGFloat(1 + 0.15 * sin(time * 2 + phase))
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
    /// `time` drives the idle micro-animations; `nil` freezes them on the
    /// canonical pose.
    static func render(
        _ ctx: inout GraphicsContext,
        from: MascotState,
        to: MascotState,
        t: Double,
        time: TimeInterval? = nil,
        crossfadeOnly: Bool,
        expressionOverride: NimbusExpression? = nil
    ) {
        let toModel = NimbusRenderModel.model(for: to, expressionOverride: expressionOverride)
        guard from != to, t < 1 else {
            drawState(&ctx, model: toModel, time: time)
            return
        }
        let fromModel = NimbusRenderModel.model(for: from, expressionOverride: expressionOverride)

        if crossfadeOnly {
            ctx.drawLayer { layer in
                layer.opacity = 1 - t
                drawState(&layer, model: fromModel, time: nil)
            }
            ctx.drawLayer { layer in
                layer.opacity = t
                drawState(&layer, model: toModel, time: nil)
            }
            return
        }

        let blended = NimbusRenderModel.lerp(fromModel, toModel, t)

        // Accessories: each state's own accessory, faded out / in. They keep
        // idling (rain keeps falling, rays keep turning) while they fade.
        drawAccessories(&ctx, model: fromModel, opacity: 1 - t, time: time)
        drawAccessories(&ctx, model: toModel, opacity: t, time: time)

        var body = breathingContext(ctx, time: time)
        drawCloud(&body, model: blended)
        // Blinks are suppressed mid-morph so they never fight the eye morph.
        drawFaceMorph(&body, from: fromModel, to: toModel, blended: blended, t: t)
    }

    // MARK: Single-state drawing (t = 0 or 1)

    static func drawState(
        _ ctx: inout GraphicsContext, model: NimbusRenderModel, time: TimeInterval?
    ) {
        drawAccessories(&ctx, model: model, opacity: 1, time: time)
        var body = breathingContext(ctx, time: time)
        drawCloud(&body, model: model)
        drawFace(&body, model: model, blink: NimbusIdle.blink(at: time))
    }

    /// A context copy scaled by the breathing factor around the cloud's
    /// visual centre (100, 80). Copies share the underlying drawing surface
    /// but carry independent transform state.
    private static func breathingContext(
        _ ctx: GraphicsContext, time: TimeInterval?
    ) -> GraphicsContext {
        let s = NimbusIdle.breathScale(at: time)
        var copy = ctx
        guard s != 1 else { return copy }
        copy.translateBy(x: 100, y: 80)
        copy.scaleBy(x: s, y: s)
        copy.translateBy(x: -100, y: -80)
        return copy
    }

    private static func drawAccessories(
        _ ctx: inout GraphicsContext, model: NimbusRenderModel, opacity: Double,
        time: TimeInterval?
    ) {
        if model.sunOpacity > 0 {
            drawSun(&ctx, opacity: model.sunOpacity * opacity, time: time)
        }
        if model.rainbowOpacity > 0 {
            drawRainbow(&ctx, opacity: model.rainbowOpacity * opacity, time: time)
        }
        if model.rainOpacity > 0 {
            drawRain(&ctx, opacity: model.rainOpacity * opacity, time: time)
        }
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

    private static func drawSun(
        _ ctx: inout GraphicsContext, opacity: Double, time: TimeInterval?
    ) {
        guard opacity > 0 else { return }
        let sun = SkyColor.sunYellow
        fillCircle(&ctx, 100, 80, 62, sun, 0.35 * opacity)
        fillCircle(&ctx, 100, 80, 48, sun, 0.5 * opacity)
        let ray = Path(roundedRect: CGRect(x: 98, y: -6, width: 4, height: 14), cornerRadius: 2)
        let spin = NimbusIdle.sunRayAngle(at: time)
        for deg in stride(from: 0, to: 360, by: 45) {
            let rad = CGFloat(deg) * .pi / 180 + spin
            var t = CGAffineTransform.identity
            t = t.translatedBy(x: 100, y: 80)
            t = t.rotated(by: rad)
            t = t.translatedBy(x: -100, y: -80)
            ctx.fill(ray.applying(t), with: .color(sun.opacity(0.85 * opacity)))
        }
    }

    private static func drawRainbow(
        _ ctx: inout GraphicsContext, opacity: Double, time: TimeInterval?
    ) {
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
        // sparkles (twinkle: alpha + radius modulation per sparkle)
        let sun = SkyColor.sunYellow
        let sparkles: [(CGFloat, CGFloat, CGFloat)] = [
            (25, 40, 2.5), (175, 50, 2), (15, 90, 1.8), (185, 100, 2.2),
        ]
        for (i, sparkle) in sparkles.enumerated() {
            let (x, y, r) = sparkle
            fillCircle(&ctx, x, y, r * NimbusIdle.sparkleRadiusScale(index: i, at: time),
                       sun, opacity * NimbusIdle.sparkleAlpha(index: i, at: time))
        }
    }

    private static func drawRain(
        _ ctx: inout GraphicsContext, opacity: Double, time: TimeInterval?
    ) {
        guard opacity > 0 else { return }
        let drop = Color(hex: "7BB3D6")
        let drops: [(CGFloat, CGFloat, CGFloat)] = [
            (55, 120, 14), (75, 130, 12), (100, 122, 16), (125, 132, 12), (145, 118, 14),
        ]
        for (i, spec) in drops.enumerated() {
            let (x, restY, h) = spec
            // Animated drops fall through an 18pt window starting 6pt above
            // the resting spot, fading in/out at the extremes; the frozen
            // pose (fall 0, visibility 1) is the original static drawing.
            let fall = NimbusIdle.rainDropFall(index: i, at: time)
            let visibility = time == nil ? 1 : NimbusIdle.rainDropVisibility(fall: fall)
            let y = time == nil ? restY : restY - 6 + fall
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x, y: y + h), control: CGPoint(x: x - 3, y: y + h / 2))
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + 3, y: y + h / 2))
            ctx.fill(p, with: .color(drop.opacity(0.85 * opacity * visibility)))
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

    private static func drawFace(
        _ ctx: inout GraphicsContext, model: NimbusRenderModel, blink: Double = 1
    ) {
        drawHighlightAndCheeks(&ctx, model: model)
        drawEyes(&ctx, spec: .spec(for: model.expr), alpha: 1, blink: blink)
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
        _ ctx: inout GraphicsContext, spec: NimbusEyeSpec, alpha: Double, blink: Double = 1
    ) {
        guard alpha > 0 else { return }
        let squash = CGFloat(blink)
        switch spec {
        case .circles:
            // Blink squashes the eyes vertically around their centres.
            fillEllipse(&ctx, 82, 70, 4, 4 * squash, ink, alpha)
            fillEllipse(&ctx, 118, 70, 4, 4 * squash, ink, alpha)
            fillEllipse(&ctx, 83.5, 68.5, 1.3, 1.3 * squash, .white, alpha)
            fillEllipse(&ctx, 119.5, 68.5, 1.3, 1.3 * squash, .white, alpha)
        case let .arcs(left, right):
            // Blink flattens the arcs: the control point sinks toward the
            // chord so the curve closes to a near-line.
            strokeQuad(&ctx, flattened(left, by: blink), alpha: alpha)
            strokeQuad(&ctx, flattened(right, by: blink), alpha: alpha)
        }
    }

    private static func flattened(_ quad: NimbusQuadSpec, by blink: Double) -> NimbusQuadSpec {
        guard blink < 1 else { return quad }
        var q = quad
        let chordMid = CGPoint(x: (quad.a.x + quad.b.x) / 2, y: (quad.a.y + quad.b.y) / 2)
        q.control = NimbusMorphMath.lerp(chordMid, quad.control, blink)
        return q
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
