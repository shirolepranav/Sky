// Typography.swift
// Sky type scale — Nunito on the web prototype, SF Rounded as the native iOS
// equivalent (DESIGN_SYSTEM.md §3). Rounded, friendly, generous line height.
//
// SwiftUI has no Nunito bundled by default, so we use the system rounded design,
// which is the documented native equivalent. If Nunito is later added to the
// bundle, swap `.system(... design: .rounded)` for `.custom("Nunito", ...)`.

import SwiftUI

/// A semantic text style: size, weight, tracking (letter-spacing), and an
/// approximate line-height multiple. Apply with `.skyText(_:)`.
struct SkyTextStyle {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    let lineHeightMultiple: CGFloat

    var font: Font { .system(size: size, weight: weight, design: .rounded) }

    /// SwiftUI `lineSpacing` is *extra* space between lines, not a multiple.
    /// Approximate the design's line-height multiple by treating the font's
    /// natural leading as ~0 and adding the difference.
    var lineSpacing: CGFloat { max(0, size * (lineHeightMultiple - 1)) }
}

extension SkyTextStyle {
    // DESIGN_SYSTEM.md §3. Weights map 800→.heavy, 700→.bold, 600→.semibold,
    // 500→.medium, 400→.regular.
    static let display  = SkyTextStyle(size: 40, weight: .heavy,    tracking: -1.2, lineHeightMultiple: 1.05)
    static let titleXL  = SkyTextStyle(size: 32, weight: .heavy,    tracking: -0.6, lineHeightMultiple: 1.05)
    static let titleL   = SkyTextStyle(size: 28, weight: .heavy,    tracking: -0.6, lineHeightMultiple: 1.10)
    static let titleM   = SkyTextStyle(size: 22, weight: .heavy,    tracking: -0.4, lineHeightMultiple: 1.20)
    static let headline = SkyTextStyle(size: 17, weight: .heavy,    tracking: -0.2, lineHeightMultiple: 1.20)
    static let body     = SkyTextStyle(size: 17, weight: .medium,   tracking: 0,    lineHeightMultiple: 1.45)
    static let bodyS    = SkyTextStyle(size: 15, weight: .medium,   tracking: 0,    lineHeightMultiple: 1.45)
    static let label    = SkyTextStyle(size: 14, weight: .bold,     tracking: 0,    lineHeightMultiple: 1.30)
    static let caption  = SkyTextStyle(size: 13, weight: .semibold, tracking: 0.3,  lineHeightMultiple: 1.40)
    static let overline = SkyTextStyle(size: 12, weight: .heavy,    tracking: 1.2,  lineHeightMultiple: 1.30)
    static let tabLabel = SkyTextStyle(size: 10, weight: .bold,     tracking: 0.3,  lineHeightMultiple: 1.00)
}

extension View {
    /// Apply a Sky text style (font + tracking + line spacing + color).
    func skyText(_ style: SkyTextStyle, color: Color = SkyColor.ink) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .foregroundStyle(color)
    }
}

#Preview("Type scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("That's the stuff.").skyText(.display)
            Text("Time's up.").skyText(.titleL)
            Text("Card title").skyText(.titleM)
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
