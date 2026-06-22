// SkyDeepLink.swift
// Parses sky:// URLs into typed deep-link destinations (Phase 6).
// Sky_App_Workflow.md S-SHIELD-02 (sky://verify) and S-SHIELD-03 (sky://emergency).
//
// Used by SkyApp's .onOpenURL handler and by DeepLinkTests.

import Foundation

enum SkyDeepLink: String, Identifiable {
    case verify    // sky://verify    → VerificationPlaceholderView (Phase 7: real video capture)
    case emergency // sky://emergency → EmergencyUnlockPlaceholderView (Phase 13: real unlock flow)

    var id: String { rawValue }

    init?(url: URL) {
        guard url.scheme == "sky", let host = url.host else { return nil }
        self.init(rawValue: host)
    }
}
