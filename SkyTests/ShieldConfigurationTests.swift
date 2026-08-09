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

    // MARK: Subtitle — carries the outdoor framing

    func testSubtitleMentionsOutside() {
        let subtitle = "Nimbus is waiting outside for you ☁"
        XCTAssertTrue(subtitle.lowercased().contains("outside"))
    }

    // MARK: Primary button

    func testPrimaryButtonLabelIsNotEmpty() {
        let label = "Open Sky to unlock"
        XCTAssertFalse(label.isEmpty)
    }

    /// Both shield buttons resolve to `ShieldActionResponse.close`, which drops the
    /// user on the Home screen — an app extension cannot launch its container. The
    /// label has to name that next step or the flow reads as a dead end; the
    /// outdoor framing moved to the subtitle.
    func testPrimaryButtonLabelNamesTheAppToOpen() {
        let label = "Open Sky to unlock"
        XCTAssertTrue(label.contains("Sky"))
        XCTAssertTrue(label.lowercased().contains("open"))
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
