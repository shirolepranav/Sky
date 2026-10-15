// Typography.swift
// Sky type scale — DESIGN_SYSTEM.md §3. Two faces:
//   • Display (titles, big numbers, Pop button labels): Fredoka in the design,
//     SF Rounded Heavy for now. See `SkyFont` — the ONE place to swap it.
//   • Body: Nunito on the web prototype, SF Rounded as the native equivalent.
//
// To bundle Fredoka later: add the .ttf files under Sky/, list them under
// `UIAppFonts` in Sky/Info.plist (the target merges a generated plist on top
// of that file, and UIAppFonts has no INFOPLIST_KEY_* build setting), then
// change `SkyFont.display(size:weight:)` only.

import SwiftUI

/// Which face a text style uses.
enum SkyFontFamily {
    case display // rounded display face — titles, big numbers, Pop buttons
    case body    // reading face — body, labels, captions
}

/// The single font token. Every `SkyTextStyle` resolves its `Font` here, so
/// swapping SF Rounded for Fredoka/Nunito touches only this enum.
enum SkyFont {
    static func font(_ family: SkyFontFamily, size: CGFloat, weight: Font.Weight) -> Font {
        switch family {
        case .display: return display(size: size, weight: weight)
        case .body: return .system(size: size, weight: weight, design: .rounded)
        }
    }

    /// Display face. Today: SF Rounded (display styles ask for `.heavy`).
    /// Later: `.custom("Fredoka-Bold", size: size)` etc., mapping `weight`.
    static func display(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A semantic text style: face, size, weight, tracking (letter-spacing), and an
/// approximate line-height multiple. Apply with `.skyText(_:)`.
struct SkyTextStyle {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    let lineHeightMultiple: CGFloat
    var family: SkyFontFamily = .body

    var font: Font { SkyFont.font(family, size: size, weight: weight) }

    /// SwiftUI `lineSpacing` is *extra* space between lines, not a multiple.
    /// Approximate the design's line-height multiple by treating the font's
    /// natural leading as ~0 and adding the difference.
    var lineSpacing: CGFloat { max(0, size * (lineHeightMultiple - 1)) }
}

extension SkyTextStyle {
    // DESIGN_SYSTEM.md §3. Weights map 800→.heavy, 700→.bold, 600→.semibold,
    // 500→.medium, 400→.regular. Titles and numbers use the display face.
    static let display  = SkyTextStyle(size: 40, weight: .heavy,    tracking: -1.2, lineHeightMultiple: 1.05, family: .display)
    static let titleXL  = SkyTextStyle(size: 32, weight: .heavy,    tracking: -0.6, lineHeightMultiple: 1.05, family: .display)
    static let titleL   = SkyTextStyle(size: 28, weight: .heavy,    tracking: -0.6, lineHeightMultiple: 1.10, family: .display)
    static let titleM   = SkyTextStyle(size: 22, weight: .heavy,    tracking: -0.4, lineHeightMultiple: 1.20, family: .display)
    static let headline = SkyTextStyle(size: 17, weight: .heavy,    tracking: -0.2, lineHeightMultiple: 1.20)
    static let body     = SkyTextStyle(size: 17, weight: .medium,   tracking: 0,    lineHeightMultiple: 1.45)
    static let bodyS    = SkyTextStyle(size: 15, weight: .medium,   tracking: 0,    lineHeightMultiple: 1.45)
    static let label    = SkyTextStyle(size: 14, weight: .bold,     tracking: 0,    lineHeightMultiple: 1.30)
    static let caption  = SkyTextStyle(size: 13, weight: .semibold, tracking: 0.3,  lineHeightMultiple: 1.40)
    static let overline = SkyTextStyle(size: 12, weight: .heavy,    tracking: 1.2,  lineHeightMultiple: 1.30)
    static let tabLabel = SkyTextStyle(size: 10, weight: .bold,     tracking: 0.3,  lineHeightMultiple: 1.00)

    // Sky Pop additions (display face).
    /// Pop button label — 20 display. Sticker/speech-bubble text uses it too.
    static let button    = SkyTextStyle(size: 20, weight: .heavy, tracking: -0.2, lineHeightMultiple: 1.10, family: .display)
    /// Big numbers in stat tiles ("0/200", "5 sec").
    static let numeral   = SkyTextStyle(size: 32, weight: .heavy, tracking: -0.5, lineHeightMultiple: 1.00, family: .display)
    /// Hero numbers (streak count, lock time).
    static let numeralXL = SkyTextStyle(size: 64, weight: .heavy, tracking: -1.5, lineHeightMultiple: 0.95, family: .display)
}

/// Applies a Sky text style with Dynamic Type support. `@ScaledMetric` scales the
/// design's point size relative to the user's text-size setting and re-renders
/// live when it changes; the app root clamps growth (…accessibility1) so the
/// tight hero/ring layouts don't break. Line spacing scales proportionally.
private struct SkyTextModifier: ViewModifier {
    let style: SkyTextStyle
    let color: Color
    @ScaledMetric private var scaledSize: CGFloat

    init(style: SkyTextStyle, color: Color) {
        self.style = style
        self.color = color
        _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content
            .font(SkyFont.font(style.family, size: scaledSize, weight: style.weight))
            .tracking(style.tracking)
            .lineSpacing(max(0, scaledSize * (style.lineHeightMultiple - 1)))
            .foregroundStyle(color)
    }
}

extension View {
    /// Apply a Sky text style (font + tracking + line spacing + color), scaled for
    /// Dynamic Type.
    func skyText(_ style: SkyTextStyle, color: Color = SkyColor.ink) -> some View {
        modifier(SkyTextModifier(style: style, color: color))
    }
}

#Preview("Type scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("That's the stuff.").skyText(.display)
            Text("Apps are napping.").skyText(.titleXL)
            Text("Time's up.").skyText(.titleL)
            Text("Card title").skyText(.titleM)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("12").skyText(.numeralXL)
                Text("0/200").skyText(.numeral)
            }
            Text("Let's go outside").skyText(.button)
            Text("Verify now").skyText(.headline)
            Text("Nimbus is waiting outside for you. Take a short walk and point your camera at the sky.")
                .skyText(.body, color: SkyColor.inkSoft)
            Text("SECTION HEADER").skyText(.overline, color: SkyColor.inkMuted)
            Text("Caption · metadata").skyText(.caption, color: SkyColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
    .background(SkyColor.surface)
}
