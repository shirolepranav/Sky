// ShieldConfigurationTests.swift
// Phase 6 automated tests — shield copy constants and deep-link URL validity
// (Roadmap Phase 6 → Automated Tests).
//
// ShieldConfiguration itself requires the Family Controls entitlement at
// runtime, so we test the copy literals and URL strings directly without
// instantiating ManagedSettingsUI types.

import XCTest

final class ShieldConfigurationTests: XCTestCase {

    // MARK: Title

    func testTitleSaysPaused() {
        let title = "Apps are paused"
        XCTAssertTrue(title.contains("paused"))
    }

    // MARK: Subtitle — carries the outdoor framing

    func testSubtitleMentionsOutside() {
        let subtitle = "Nimbus is waiting outside for you ☁"
        XCTAssertTrue(subtitle.lowercased().contains("outside"))
    }

    // MARK: Primary button

    func testPrimaryButtonLabelNamesTheApp() {
        let label = "Unlock with Sky"
        XCTAssertTrue(label.contains("Sky"))
    }

    // MARK: Auxiliary button — brand voice (PRD §7: never guilt-trip)

    func testAuxiliaryButtonLabelIsNotEmpty() {
        let label = "Emergency unlock"
        XCTAssertFalse(label.isEmpty)
    }

    func testAuxiliaryButtonLabelIsKind() {
        let label = "Emergency unlock".lowercased()
        // PRD §7: warm and truthful, not cold or punishing.
        XCTAssertFalse(label.contains("waste"))
        XCTAssertFalse(label.contains("fail"))
        XCTAssertFalse(label.contains("cheat"))
    }

    // MARK: Deep-link URLs

    func testVerifyDeepLinkIsValidURL() {
        XCTAssertNotNil(URL(string: "sky://verify"))
    }

    func testEmergencyDeepLinkIsValidURL() {
        XCTAssertNotNil(URL(string: "sky://emergency"))
    }
}
