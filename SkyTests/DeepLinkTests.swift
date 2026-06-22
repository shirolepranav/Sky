// DeepLinkTests.swift
// Phase 6 automated tests — SkyDeepLink URL parsing (Roadmap Phase 6 → Automated Tests).
//
// Pure Swift; no entitlements, no mocks, no I/O. Tests that sky:// URLs are
// correctly parsed to enum cases and that malformed or unknown URLs return nil.

import XCTest
@testable import Sky

final class DeepLinkTests: XCTestCase {

    func testVerifyURLParsesToVerifyCase() {
        let url = URL(string: "sky://verify")!
        XCTAssertEqual(SkyDeepLink(url: url), .verify)
    }

    func testEmergencyURLParsesToEmergencyCase() {
        let url = URL(string: "sky://emergency")!
        XCTAssertEqual(SkyDeepLink(url: url), .emergency)
    }

    func testUnknownHostReturnsNil() {
        let url = URL(string: "sky://unknown")!
        XCTAssertNil(SkyDeepLink(url: url), "Unrecognised host must not parse to a known case")
    }

    func testWrongSchemeReturnsNil() {
        let url = URL(string: "https://verify")!
        XCTAssertNil(SkyDeepLink(url: url), "Non-sky scheme must return nil")
    }

    func testMissingHostReturnsNil() {
        // sky:/// has scheme "sky" but no host component
        let url = URL(string: "sky:///")!
        XCTAssertNil(SkyDeepLink(url: url))
    }
}
