// SkyShieldAction.swift
// Principal class for the ShieldAction extension target (Technical Spec §7.5,
// Sky_App_Workflow.md S-SHIELD-02 / S-SHIELD-03).
//
// Phase 6: records which shield button the user tapped so the main app can route
// to the correct screen the next time it becomes active.
//   Primary button   → "verify"    → VerificationPlaceholderView
//   Auxiliary button → "emergency" → EmergencyUnlockPlaceholderView
//
// An app extension cannot call UIApplication.shared.open() (UIApplication.shared
// is unavailable in extensions), and ShieldActionResponse has no "open host app"
// case. So the handoff is via the App Group: we write the pending destination to
// shared UserDefaults and call completionHandler(.close). SkyApp reads and clears
// `pending_deep_link` on scenePhase == .active and presents the destination.
//
// This target cannot import the Sky module, so the App Group is accessed via raw
// UserDefaults keys that mirror SharedDefaults.Key — keep both in sync.

import ManagedSettings
import ManagedSettingsUI
import Foundation

final class SkyShieldAction: ShieldActionDelegate {

    // Raw key string mirrors SharedDefaults.Key.pendingDeepLink (Technical Spec §6.1).
    private static let suiteName = "group.com.shirolepranav.sky"
    private static let pendingDeepLinkKey = "pending_deep_link"

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    // MARK: - Private

    private func handleAction(
        _ action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let destination: String?
        switch action {
        case .primaryButtonPressed:
            destination = "verify"
        case .secondaryButtonPressed:
            destination = "emergency"
        @unknown default:
            completionHandler(.defer)
            return
        }

        if let destination {
            let ud = UserDefaults(suiteName: Self.suiteName) ?? .standard
            ud.set(destination, forKey: Self.pendingDeepLinkKey)
        }

        // .close dismisses the shield and the shielded app; the user re-opens Sky,
        // and SkyApp consumes the pending destination on activation.
        completionHandler(.close)
    }
}
