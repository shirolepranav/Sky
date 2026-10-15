// SkyShieldAction.swift
// Principal class for the ShieldAction extension target (Technical Spec §7.5,
// Sky_App_Workflow.md S-SHIELD-02 / S-SHIELD-03).
//
// Phase 6: records which shield button the user tapped so the main app can route
// to the correct screen the next time it becomes active.
//   Primary button   → "verify"    → VerificationCoordinatorView
//   Auxiliary button → "emergency" → EmergencyUnlockCoordinatorView (Phase 13)
//
// An app extension cannot call UIApplication.shared.open() (UIApplication.shared
// is unavailable in extensions), and ShieldActionResponse has no "open host app"
// case. So the handoff is two-fold:
//   1. The pending destination goes to the App Group; SkyApp reads and clears
//      `pending_deep_link` on scenePhase == .active.
//   2. A local notification is posted whose tap opens Sky on that destination
//      (SkyNotificationRouter). Without it, `.close` dropped the user on the Home
//      screen with no sign anything had happened — the "buttons don't work" bug.
//
// This target cannot import the Sky module, so the App Group is accessed via raw
// UserDefaults keys that mirror SharedDefaults.Key — keep both in sync.

import ManagedSettings
import ManagedSettingsUI
import Foundation
import UserNotifications

final class SkyShieldAction: ShieldActionDelegate {

    // Raw key string mirrors SharedDefaults.Key.pendingDeepLink (Technical Spec §6.1).
    private static let suiteName = "group.com.shirolepranav.sky"
    private static let pendingDeepLinkKey = "pending_deep_link"
    /// Mirrors `SkyNotificationRouter.deepLinkKey` in the Sky module.
    private static let deepLinkUserInfoKey = "sky_deep_link"

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
            postContinueNotification(for: destination)
        }

        // .close dismisses the shield and the shielded app; the user re-opens Sky,
        // and SkyApp consumes the pending destination on activation.
        completionHandler(.close)
    }

    /// Delivered immediately (nil trigger). A stable identifier means repeated taps
    /// replace the banner rather than stacking several.
    private func postContinueNotification(for destination: String) {
        let content = UNMutableNotificationContent()
        content.title = destination == "emergency" ? "Emergency unlock" : "Nimbus is ready"
        content.body = destination == "emergency"
            ? "Tap to continue in Sky."
            : "Tap to head outside and unlock your apps ☁"
        content.userInfo = [Self.deepLinkUserInfoKey: destination]
        let request = UNNotificationRequest(identifier: "sky.notif.shieldTap", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
