// ColorTokens.swift
// Sky design system — the single source of truth for color in the app.
// Mirrors `tokens.jsx` (SKY_TOKENS) from the design handoff and the palette in
// DESIGN_SYSTEM.md §2. If anything conflicts, DESIGN_SYSTEM.md / tokens.jsx win.
//
// Principle: never pure white, never pure black. Text uses `ink`, surfaces use
// the warm off-white tokens.

import SwiftUI

extension Color {
    /// Create a Color from a hex string. Accepts "RRGGBB", "#RRGGBB",
    /// "AARRGGBB", or "#AARRGGBB". Falls back to clear on a malformed string.
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else {
            self = .clear
            return
        }

        let a, r, g, b: Double
        switch raw.count {
        case 6: // RRGGBB
            a = 1
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        case 8: // AARRGGBB
            a = Double((value & 0xFF000000) >> 24) / 255
            r = Double((value & 0x00FF0000) >> 16) / 255
            g = Double((value & 0x0000FF00) >> 8) / 255
            b = Double(value & 0x000000FF) / 255
        default:
            self = .clear
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// All Sky color tokens. Use these — do not inline hex values elsewhere.
enum SkyColor {
    // MARK: Brand palette
    static let primarySky = Color(hex: "A8D8EA")        // hero, calm backgrounds
    static let primarySkyDeep = Color(hex: "7AB8D0")    // hover / active
    static let warmCream = Color(hex: "FFF6E5")         // surfaces, shield, chips
    static let warmCreamDeep = Color(hex: "F5EAD0")     // pressed cream
    static let mossGreen = Color(hex: "7CB342")         // tints, nav active, success on light
    static let mossGreenDeep = Color(hex: "5C8A2E")     // green text/icons on white
    /// Primary button fill — deeper moss so a white label clears WCAG AA (4.6:1).
    static let mossGreenAction = Color(hex: "52822A")
    static let mossGreenActionDeep = Color(hex: "3D6420") // pressed + solid drop shadow
    static let coralStreak = Color(hex: "FF8A7A")       // streaks, alerts, "apps paused"
    static let coralStreakDeep = Color(hex: "E5685A")   // coral shadow / coral text on white
    static let cloudGrey = Color(hex: "B8C5D0")         // indoor / paused, neutral
    static let cloudGreyDeep = Color(hex: "9BA9B6")     // pressed grey
    static let sunYellow = Color(hex: "FFD66B")         // verified, milestones, badges
    static let sunYellowDeep = Color(hex: "E5B843")     // yellow shadow / accent

    // MARK: Text
    static let ink = Color(hex: "2D3748")               // primary text (never #000)
    static let inkSoft = Color(hex: "5A6373")           // secondary
    static let inkMuted = Color(hex: "9CA3AF")          // tertiary / captions / overlines
    static let inkDisabled = Color(hex: "CBD5E0")       // disabled fills & text

    // MARK: Surfaces
    static let surface = Color(hex: "FFFBF2")           // main app background
    static let surfaceCard = Color(hex: "FFFFFF")       // cards on top of surface
    static let surfaceElev = Color(hex: "FFFEFB")       // elevated surfaces
    static let divider = Color(hex: "2D3748").opacity(0.08) // hairline dividers & borders

    // MARK: Dark mode
    static let darkBg = Color(hex: "15171F")            // deep night-sky background
    static let darkBgElev = Color(hex: "1F2230")        // elevated dark surface
    static let darkInk = Color(hex: "F0F4F8")           // primary text on dark
    static let darkInkSoft = Color(hex: "A8B3C2")       // secondary text on dark
    static let darkDivider = Color.white.opacity(0.08)  // dividers on dark
}

#Preview("Color tokens") {
    let swatches: [(String, Color)] = [
        ("primarySky", SkyColor.primarySky),
        ("warmCream", SkyColor.warmCream),
        ("mossGreen", SkyColor.mossGreen),
        ("mossGreenAction", SkyColor.mossGreenAction),
        ("coralStreak", SkyColor.coralStreak),
        ("cloudGrey", SkyColor.cloudGrey),
        ("sunYellow", SkyColor.sunYellow),
        ("ink", SkyColor.ink),
        ("surface", SkyColor.surface),
    ]
    return ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
            ForEach(swatches, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color)
                        .frame(height: 72)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.05)))
                    Text(name).font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
        }
        .padding()
    }
    .background(SkyColor.surface)
}
