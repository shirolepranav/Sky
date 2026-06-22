// SkyIcons.swift
// Small custom icons used across Sky. SunIcon is drawn faithfully from the
// prototype SVG (screens-foundations.jsx). FlameIcon uses the native SF Symbol
// `flame.fill` — the idiomatic iOS equivalent of the prototype's custom flame —
// tinted with the coral streak color.

import SwiftUI

/// Flame used on streak chips. SF Symbol `flame.fill`, coral-tinted.
struct FlameIcon: View {
    var color: Color = SkyColor.coralStreak
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size * 0.92))
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

/// Sun icon: a center disc plus 8 rounded rays. Faithful to the prototype SVG
/// (24×24 viewBox: circle r4.5 at center, rays x11 y1.5 w2 h3.5 rotated by 45°).
struct SunIcon: View {
    var color: Color = SkyColor.sunYellow
    var size: CGFloat = 20

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 24
            ctx.scaleBy(x: s, y: s)

            // Center disc
            ctx.fill(Path(ellipseIn: CGRect(x: 7.5, y: 7.5, width: 9, height: 9)), with: .color(color))

            // 8 rays, each a rounded rect rotated around the center (12,12)
            let ray = Path(roundedRect: CGRect(x: 11, y: 1.5, width: 2, height: 3.5), cornerRadius: 1)
            for deg in stride(from: 0, to: 360, by: 45) {
                let rad = CGFloat(deg) * .pi / 180
                var t = CGAffineTransform.identity
                t = t.translatedBy(x: 12, y: 12)
                t = t.rotated(by: rad)
                t = t.translatedBy(x: -12, y: -12)
                ctx.fill(ray.applying(t), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Icons") {
    HStack(spacing: 24) {
        FlameIcon(size: 40)
        SunIcon(size: 40)
    }
    .padding(40)
    .background(SkyColor.surface)
}
