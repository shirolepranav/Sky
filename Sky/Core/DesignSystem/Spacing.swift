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
    static let device: CGFloat = 48        // phone frame only
}

/// Fixed layout constants.
enum SkyLayout {
    static let screenMargin: CGFloat = 24      // default screen horizontal margin
    static let screenMarginCard: CGFloat = 16  // card-led screens
    static let bottomSafeArea: CGFloat = 34    // bottom safe-area inset
    static let minTouchTarget: CGFloat = 44    // never smaller
}
