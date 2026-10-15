// Cards.swift
// Sky container components — DESIGN_SYSTEM.md §7.
// Info-only cards lean on a hairline `divider` border, never the ink outline:
// under Sky Pop (§6 "Tappable outline") the ink outline + hard shadow means
// "you can tap this", so cards stay soft. Pop pills, the streak badge and the
// Pop bottom sheet live at the bottom of this file.

import SwiftUI

/// Primary card: white fill, 24 radius, 1px divider border, 20 padding.
/// Pass `secondary: true` for inner cards (20 radius).
struct SkyCard<Content: View>: View {
    var secondary = false
    var padding: CGFloat = SkySpacing.s5
    @ViewBuilder var content: () -> Content

    var body: some View {
        let radius = secondary ? SkyRadius.cardSecondary : SkyRadius.card
        content()
            .padding(padding)
            .background(SkyColor.surfaceCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SkyColor.divider, lineWidth: 1)
            )
    }
}

/// Status pill: pill-shaped, cream or white fill, 14/bold label, often led by an
/// 8×8 dot whose color signals state (e.g. coral = paused).
struct SkyStatusPill: View {
    let text: String
    var dotColor: Color? = nil
    var fill: Color = SkyColor.warmCream

    var body: some View {
        HStack(spacing: SkySpacing.s2) {
            if let dotColor {
                Circle().fill(dotColor).frame(width: 8, height: 8)
            }
            Text(text).skyText(.label, color: SkyColor.ink)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(fill, in: Capsule())
    }
}

/// Streak chip: cream rounded tile with a flame icon and "N day streak".
struct SkyStreakChip: View {
    let days: Int

    var body: some View {
        HStack(spacing: SkySpacing.s2) {
            FlameIcon(color: SkyColor.coralStreak, size: 20)
            Text("\(days) day streak")
                .skyText(.headline, color: SkyColor.ink)
                // Rolls the digits when the count ticks up (S-VER-06); the
                // caller's transaction decides whether the change animates.
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SkyColor.warmCream, in: RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous))
    }
}

// MARK: - Sky Pop (DESIGN_SYSTEM.md §6 "Tappable outline", §7)

/// Outlined pill. `raised: true` adds the 3×3 hard shadow — use it for badges
/// (streak, milestone). `raised: false` is a flat "sticker" label (outline only,
/// no shadow) for info on a Pop ground, e.g. "Tue · 8:02" or "214 steps".
/// Neither is a button; wrap in a Button + SkyChipButtonStyle if it must be tappable.
/// - `onAccent`: the pill sits on a bright Pop ground, so the outline stays ink.
/// - `textColor`: `ink` on surface fills (adaptive); `inkOnAccent` on Pop fills.
struct SkyPopPill<Leading: View>: View {
    let text: String
    var fill: Color = SkyColor.surface
    var textColor: Color = SkyColor.ink
    var raised = false
    var onAccent = false
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: SkySpacing.s1) {
            leading()
            Text(text).skyText(.label, color: textColor)
        }
        .padding(.vertical, SkySpacing.s2)
        .padding(.horizontal, SkySpacing.s3)
        .skyPopSurface(
            Capsule(),
            fill: fill,
            outline: onAccent ? SkyColor.outlineOnAccent : SkyColor.outline,
            lineWidth: SkyStroke.outline,
            shadow: raised ? SkyPopShadow.chip : .zero
        )
    }
}

extension SkyPopPill where Leading == EmptyView {
    init(_ text: String, fill: Color = SkyColor.surface, textColor: Color = SkyColor.ink,
         raised: Bool = false, onAccent: Bool = false) {
        self.init(text: text, fill: fill, textColor: textColor, raised: raised, onAccent: onAccent) { EmptyView() }
    }
}

/// Streak badge: popCoral pill, sun-filled ink-outlined flame, day count in the
/// display face. Raised (badge), not tappable. Reads "12 day streak" to VoiceOver.
struct SkyPopStreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: SkySpacing.s1) {
            // Sun-yellow flame with an ink outline, like the design's sticker flame.
            ZStack {
                Image(systemName: "flame.fill").foregroundStyle(SkyColor.popSun)
                Image(systemName: "flame").foregroundStyle(SkyColor.outlineOnAccent)
            }
            .font(SkyTextStyle.label.font)
            Text("\(days)")
                .skyText(.headline, color: SkyColor.inkOnAccent)
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.vertical, SkySpacing.s2)
        .padding(.horizontal, SkySpacing.s3)
        // Coral stays bright in dark mode, so the outline stays ink.
        .skyPopSurface(Capsule(), fill: SkyColor.popCoral, outline: SkyColor.outlineOnAccent,
                       lineWidth: SkyStroke.outline, shadow: SkyPopShadow.chip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) day streak")
    }
}

/// Only the top edge of a top-rounded sheet: down the left corner curve,
/// across, and down the right curve. Inset by half the line so it isn't clipped.
private struct SheetTopEdge: Shape {
    let radius: CGFloat
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = lineWidth / 2
        let r = radius - inset
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY + inset))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: r,
                    startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        return path
    }
}

/// Sky Pop bottom sheet: cream fill, 32pt top corners, 3pt ink top edge. Sits
/// under a full-bleed Pop hero (Today), so the edge stays ink in dark mode — it
/// separates the bright ground from the sheet. Extends into the bottom safe area.
struct SkyPopSheet<Content: View>: View {
    var padding: CGFloat = SkySpacing.s5
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: SkyRadius.sheet,
                                           topTrailingRadius: SkyRadius.sheet,
                                           style: .continuous)
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Fill runs on into the bottom safe area; bottom corners are square.
            .background { shape.fill(SkyColor.surface).ignoresSafeArea(edges: .bottom) }
            .overlay(
                SheetTopEdge(radius: SkyRadius.sheet, lineWidth: SkyStroke.outlineHeavy)
                    .stroke(SkyColor.outlineOnAccent, style: StrokeStyle(lineWidth: SkyStroke.outlineHeavy, lineCap: .round))
            )
    }
}

#Preview("Cards & chips") {
    VStack(spacing: 16) {
        SkyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card title").skyText(.titleM)
                Text("A calm container with a hairline border, not a heavy shadow.")
                    .skyText(.body, color: SkyColor.inkSoft)
            }
        }
        HStack {
            SkyStatusPill(text: "Apps paused", dotColor: SkyColor.coralStreak)
            SkyStreakChip(days: 12)
        }
    }
    .padding(24)
    .background(SkyColor.surface)
}

/// Pop pills, badge and sheet on a popSky ground, as Today uses them.
private struct SkyPopPillGallery: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SkySpacing.s4) {
                HStack {
                    SkyPopPill("Tue · 8:02", onAccent: true)
                    Spacer()
                    SkyPopStreakBadge(days: 12)
                }
                SkyPopPill(text: "Instagram is napping", onAccent: true) {
                    Image(systemName: "lock.fill").foregroundStyle(SkyColor.ink)
                }
                HStack(spacing: SkySpacing.s2) {
                    SkyPopPill("214 steps", onAccent: true)
                    SkyPopPill("Badge · Cirrus", fill: SkyColor.popSun, textColor: SkyColor.inkOnAccent,
                               raised: true, onAccent: true)
                }
            }
            .padding(SkySpacing.s6)
            .frame(maxWidth: .infinity)
            .background(SkyColor.popSky)

            SkyPopSheet {
                VStack(alignment: .leading, spacing: SkySpacing.s4) {
                    Text("Apps are napping.\nSky's awake.").skyText(.titleXL)
                    SkyCard(secondary: true) {
                        Text("Info cards keep the soft hairline.").skyText(.bodyS, color: SkyColor.inkSoft)
                    }
                    SkyPopButton("Let's go outside", systemImage: "arrow.right") {}
                }
            }
            .background(SkyColor.popSky) // ground shows behind the sheet's round corners
        }
    }
}

#Preview("Sky Pop pills & sheet — light") {
    SkyPopPillGallery().preferredColorScheme(.light)
}

#Preview("Sky Pop pills & sheet — dark") {
    SkyPopPillGallery().preferredColorScheme(.dark)
}
