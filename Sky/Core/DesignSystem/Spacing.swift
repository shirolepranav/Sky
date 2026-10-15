// Spacing.swift
// Sky layout tokens — a 4pt base scale, plus radii and fixed layout constants.
// DESIGN_SYSTEM.md §4 (spacing), §5 (radii). Compose padding/gaps from these
// steps; do not use off-scale values.

import CoreGraphics

/// 4pt base spacing scale.
enum SkySpacing {
    static let s1: CGFloat = 4    // icon ↔ label micro-gaps
    static let s2: CGFloat = 8    // tight gaps, chip padding-y
    static let s3: CGFloat = 12   // stacked controls
    static let s4: CGFloat = 16   // default gap / card list gap
    static let s5: CGFloat = 20   // card inner padding
    static let s6: CGFloat = 24   // screen margin, button padding-x
    static let s8: CGFloat = 32   // section spacing
    static let s10: CGFloat = 40  // large section spacing / foundations padding
}

/// Corner radii.
enum SkyRadius {
    static let chip: CGFloat = 14          // chips, small tiles, swatches
    static let button: CGFloat = 18        // buttons
    static let card: CGFloat = 24          // primary cards
    static let cardSecondary: CGFloat = 20 // inner / secondary cards
    static let pill: CGFloat = 999         // status pills, streak chips, badges
    static let sheet: CGFloat = 32         // Sky Pop bottom sheet (top corners only)
    static let device: CGFloat = 48        // phone frame only
}

/// Sky Pop outline + hard-shadow geometry — DESIGN_SYSTEM.md §6 "Tappable outline".
/// Strokes aren't spacing, so they live outside the 4pt scale.
enum SkyStroke {
    static let outline: CGFloat = 2.5      // chips, tiles, badges, pills
    static let outlineHeavy: CGFloat = 3   // buttons, sheet top edge
}

/// Offset of the solid (radius 0) ink shadow under a tappable element. On press
/// the element translates by this offset into its shadow and the shadow goes to 0.
enum SkyPopShadow {
    static let button = CGSize(width: 0, height: 5) // primary / full-width buttons
    static let chip = CGSize(width: 3, height: 3)   // chips, tiles, badges
}

/// Fixed layout constants.
enum SkyLayout {
    static let screenMargin: CGFloat = 24      // default screen horizontal margin
    static let screenMarginCard: CGFloat = 16  // card-led screens
    static let bottomSafeArea: CGFloat = 34    // bottom safe-area inset
    static let minTouchTarget: CGFloat = 44    // never smaller
    static let popButtonHeight: CGFloat = 58   // Sky Pop full-width button min height
}
