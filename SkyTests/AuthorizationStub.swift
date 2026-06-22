// AuthorizationStub.swift
// Shared test double for `AuthorizationProviding` (Phase 3). Lets tests drive the
// authorization status and observe requests without touching the real
// `AuthorizationCenter` / iOS system prompt.

import FamilyControls
@testable import Sky

final class AuthorizationStub: AuthorizationProviding, @unchecked Sendable {
    var authorizationStatus: AuthorizationStatus
    /// If set, the status becomes this after a request completes (simulates the
    /// user's choice in the system prompt).
    var statusAfterRequest: AuthorizationStatus?
    /// If set, the request throws instead of succeeding.
    var requestError: Error?
    private(set) var requestCount = 0

    init(status: AuthorizationStatus = .notDetermined) {
        self.authorizationStatus = status
    }

    func requestAuthorization(for member: FamilyControlsMember) async throws {
        requestCount += 1
        if let requestError { throw requestError }
        if let statusAfterRequest { authorizationStatus = statusAfterRequest }
    }
}
