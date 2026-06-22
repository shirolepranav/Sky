// FamilyControlsService.swift
// Wraps Family Controls authorization (Technical Spec §7.1, Sky_App_Workflow.md
// §S-PERM-01/02). `.individual` = the user manages their own device (not a
// parental/Family Sharing relationship).
//
// `AuthorizationCenter` is hidden behind the `AuthorizationProviding` protocol so
// the service can be unit-tested with an injected mock. The OS persists the grant;
// Sky re-reads it on every cold launch and on each return to the foreground (the
// user may have toggled the permission in Settings).

import Foundation
import FamilyControls

/// The slice of `AuthorizationCenter` the service depends on — mockable in tests.
protocol AuthorizationProviding {
    var authorizationStatus: AuthorizationStatus { get }
    func requestAuthorization(for member: FamilyControlsMember) async throws
}

extension AuthorizationCenter: AuthorizationProviding {}

@MainActor
final class FamilyControlsService: ObservableObject {
    /// Published so the setup flow / coordinator re-route when the grant changes.
    @Published private(set) var status: AuthorizationStatus

    private let center: AuthorizationProviding

    init(center: AuthorizationProviding = AuthorizationCenter.shared) {
        self.center = center
        self.status = center.authorizationStatus
    }

    /// Trigger the iOS system prompt, then refresh `status`. A thrown error means
    /// the request did not produce an approval; the resolved `authorizationStatus`
    /// (`.denied` / `.notDetermined`) is the source of truth, so we just re-read it.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            // Intentionally ignored — `refreshStatus()` reflects the real outcome.
        }
        refreshStatus()
    }

    /// Re-read the OS-persisted status. Call on launch and on `scenePhase` → active.
    func refreshStatus() {
        status = center.authorizationStatus
    }

    var isApproved: Bool { status == .approved }
}

#if DEBUG
/// UI-test stub that reports an already-granted authorization so tests can land
/// on S-CFG-01 without the (Simulator-unreliable) system prompt. Wired via the
/// `-mockAuthorized` launch argument in SkyApp.
struct MockApprovedAuthorizationCenter: AuthorizationProviding {
    var authorizationStatus: AuthorizationStatus { .approved }
    func requestAuthorization(for member: FamilyControlsMember) async throws {}
}
#endif
