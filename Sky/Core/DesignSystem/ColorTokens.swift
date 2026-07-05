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

    /// An adaptive color that resolves to `light` or `dark` based on the active
    /// interface style (system setting or an in-app `.preferredColorScheme`
    /// override). This keeps `SkyColor` the single source of truth — no Asset
    /// Catalog color sets. Guarded because `UIColor(dynamicProvider:)` is
    /// unavailable under the macOS SDK used by the CLAUDE.md type-check path.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light // macOS type-check fallback only — device builds use UIKit.
        #endif
    }
}

/// All Sky color tokens. Use these — do not inline hex values elsewhere.
enum SkyColor {
    // MARK: Brand palette
    static let primarySky = Color(hex: "A8D8EA")        // hero, calm backgrounds
    static let primarySkyDeep = Color(hex: "7AB8D0")    // hover / active
    // Cream is a *surface* (chips, shield, cream cards), so it must darken in
    // dark mode — otherwise the now-adaptive `ink` text on it would be unreadable.
    static let warmCream = Color(light: Color(hex: "FFF6E5"), dark: Color(hex: "232633"))     // surfaces, shield, chips
    static let warmCreamDeep = Color(light: Color(hex: "F5EAD0"), dark: Color(hex: "2C3040")) // pressed cream
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

    // MARK: Text — adaptive (light value / dark value). Never pure #000/#FFF.
    static let ink = Color(light: Color(hex: "2D3748"), dark: Color(hex: "F0F4F8"))     // primary text
    static let inkSoft = Color(light: Color(hex: "5A6373"), dark: Color(hex: "A8B3C2")) // secondary
    static let inkMuted = Color(light: Color(hex: "9CA3AF"), dark: Color(hex: "7C8797")) // tertiary / captions
    static let inkDisabled = Color(light: Color(hex: "CBD5E0"), dark: Color(hex: "3A4150")) // disabled fills & text
    /// Fixed dark ink for content drawn *on top of a bright accent fill*
    /// (sunYellow / coralStreak / primarySky / mossGreen tints). These fills stay
    /// bright in dark mode, so `ink` (which flips near-white) must not be used there.
    static let inkOnAccent = Color(hex: "2D3748")

    // MARK: Surfaces — adaptive
    static let surface = Color(light: Color(hex: "FFFBF2"), dark: Color(hex: "15171F"))     // main app background
    static let surfaceCard = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1F2230")) // cards on top of surface
    static let surfaceElev = Color(light: Color(hex: "FFFEFB"), dark: Color(hex: "242838")) // elevated surfaces
    static let divider = Color(light: Color(hex: "2D3748").opacity(0.08),
                              dark: Color.white.opacity(0.08))                              // hairline dividers & borders

    // MARK: Dark-mode raw inputs (kept for `dark:`-context views like the camera
    // viewfinder and always-dark overlays; also feed the adaptive tokens above).
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
