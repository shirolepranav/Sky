// AppBrandingTests.swift
// Phase 0 automated tests (Roadmap Phase 0 → Automated Tests).
// Verifies the swappable branding constants and the hex color decoding that the
// whole design system is built on.

import XCTest
import SwiftUI
import UIKit
@testable import Sky

final class AppBrandingTests: XCTestCase {

    /// `Color(hex:)` decodes known strings to the expected RGB, and every
    /// SkyColor token instantiates without crashing.
    func testColorValuesParseCorrectly() {
        // Known-value spot checks (tolerance covers float rounding to 1/255).
        assertColor(Color(hex: "A8D8EA"), red: 0xA8, green: 0xD8, blue: 0xEA) // primarySky
        assertColor(Color(hex: "#FFF6E5"), red: 0xFF, green: 0xF6, blue: 0xE5) // warmCream, with '#'
        assertColor(Color(hex: "2D3748"), red: 0x2D, green: 0x37, blue: 0x48) // ink

        // Touch every brand + semantic token so a malformed hex would surface.
        let tokens: [Color] = [
            SkyColor.primarySky, SkyColor.primarySkyDeep,
            SkyColor.warmCream, SkyColor.warmCreamDeep,
            SkyColor.mossGreen, SkyColor.mossGreenDeep,
            SkyColor.mossGreenAction, SkyColor.mossGreenActionDeep,
            SkyColor.coralStreak, SkyColor.coralStreakDeep,
            SkyColor.cloudGrey, SkyColor.cloudGreyDeep,
            SkyColor.sunYellow, SkyColor.sunYellowDeep,
            SkyColor.ink, SkyColor.inkSoft, SkyColor.inkMuted, SkyColor.inkDisabled,
            SkyColor.surface, SkyColor.surfaceCard, SkyColor.surfaceElev,
            SkyColor.darkBg, SkyColor.darkBgElev, SkyColor.darkInk, SkyColor.darkInkSoft,
        ]
        for token in tokens {
            // Resolving to a UIColor forces the underlying components to evaluate.
            XCTAssertNotNil(UIColor(token).cgColor.components)
        }
    }

    /// The four StoreKit product IDs must be distinct.
    func testProductIDsAreUnique() {
        let ids = [
            AppBranding.monthlyProductID,
            AppBranding.annualProductID,
            AppBranding.lifetimeProductID,
            AppBranding.founderLifetimeProductID,
        ]
        XCTAssertEqual(Set(ids).count, ids.count, "Product IDs must be unique")
    }

    // MARK: - Helpers

    private func assertColor(_ color: Color, red: Int, green: Int, blue: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, &g, &b, &a)
        let tol: CGFloat = 1.0 / 255.0 + 0.001
        XCTAssertEqual(r, CGFloat(red) / 255, accuracy: tol, "red", file: file, line: line)
        XCTAssertEqual(g, CGFloat(green) / 255, accuracy: tol, "green", file: file, line: line)
        XCTAssertEqual(b, CGFloat(blue) / 255, accuracy: tol, "blue", file: file, line: line)
    }
}
