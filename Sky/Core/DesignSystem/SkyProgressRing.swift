// SkyProgressRing.swift
// Circular progress ring — DESIGN_SYSTEM.md §7.
// Track is the accent at ~16% opacity; fill is the accent. Rotated -90° so it
// starts at 12 o'clock, with round line-caps. Used for daily usage and the
// verification countdown.

import SwiftUI

struct SkyProgressRing: View {
    /// 0.0 ... 1.0
    var progress: Double
    var accent: Color = SkyColor.mossGreen
    var lineWidth: CGFloat = 12
    var trackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
        }
        .padding(lineWidth / 2)
    }
}

#Preview("Progress ring") {
    HStack(spacing: 24) {
        SkyProgressRing(progress: 0.38)
            .frame(width: 120, height: 120)
        SkyProgressRing(progress: 0.85, accent: SkyColor.coralStreak)
            .frame(width: 120, height: 120)
        ZStack {
            SkyProgressRing(progress: 0.62, accent: SkyColor.sunYellow, lineWidth: 14)
            Text("14s").skyText(.titleM)
        }
        .frame(width: 120, height: 120)
    }
    .padding(40)
    .background(SkyColor.surface)
}
