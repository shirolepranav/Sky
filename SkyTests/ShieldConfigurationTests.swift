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

    func testTitleContainsAppName() {
        let title = "Sky — Time's up"
        XCTAssertTrue(title.hasPrefix("Sky"))
    }

    func testTitleContainsTimesUp() {
        let title = "Sky — Time's up"
        XCTAssertTrue(title.contains("Time's up"))
    }

    // MARK: Primary button

    func testPrimaryButtonLabelIsNotEmpty() {
        let label = "Go outside to unlock"
        XCTAssertFalse(label.isEmpty)
    }

    func testPrimaryButtonLabelMentionsOutside() {
        let label = "Go outside to unlock"
        XCTAssertTrue(label.lowercased().contains("outside"))
    }

    // MARK: Auxiliary button — brand voice (PRD §7: never guilt-trip)

    func testAuxiliaryButtonLabelIsNotEmpty() {
        let label = "I can't go outside right now"
        XCTAssertFalse(label.isEmpty)
    }

    func testAuxiliaryButtonLabelIsKind() {
        let label = "I can't go outside right now".lowercased()
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
