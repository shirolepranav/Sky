// FamilyControlsServiceTests.swift
// Phase 3 automated tests (Roadmap Phase 3 → Automated Tests). Verifies the
// service mirrors an injected authorization provider and updates its published
// status after a request resolves.

import XCTest
import FamilyControls
@testable import Sky

@MainActor
final class FamilyControlsServiceTests: XCTestCase {
    /// `status` reflects the injected center's status at init.
    func testAuthorizationStatusReadsFromCenter() {
        let approved = FamilyControlsService(center: AuthorizationStub(status: .approved))
        XCTAssertEqual(approved.status, .approved)
        XCTAssertTrue(approved.isApproved)

        let denied = FamilyControlsService(center: AuthorizationStub(status: .denied))
        XCTAssertEqual(denied.status, .denied)
        XCTAssertFalse(denied.isApproved)
    }

    /// A successful request flips the published status to approved.
    func testRequestUpdatesStatusOnApproval() async {
        let stub = AuthorizationStub(status: .notDetermined)
        stub.statusAfterRequest = .approved
        let service = FamilyControlsService(center: stub)

        await service.requestAuthorization()

        XCTAssertEqual(stub.requestCount, 1)
        XCTAssertTrue(service.isApproved)
    }

    /// A thrown error leaves the resolved (denied) status as the source of truth.
    func testRequestErrorResolvesToCurrentStatus() async {
        let stub = AuthorizationStub(status: .denied)
        stub.requestError = NSError(domain: "test", code: 1)
        let service = FamilyControlsService(center: stub)

        await service.requestAuthorization()

        XCTAssertFalse(service.isApproved)
        XCTAssertEqual(service.status, .denied)
    }
}
