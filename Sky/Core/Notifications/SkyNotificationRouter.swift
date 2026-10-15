// SkyNotificationRouter.swift
// Routes a tapped Sky notification to its deep-link destination
// (Sky_App_Workflow.md S-SHIELD-02 / S-SHIELD-03; DAILY_LOCK_PLAN.md Phase A).
//
// SkyShieldAction cannot open Sky, so a shield-button tap posts a notification
// carrying `sky_deep_link` in its userInfo. Tapping it lands here, and SkyApp
// presents the destination. Installed as the notification-center delegate in
// SkyApp.init so a tap that cold-launches Sky is still delivered.

import Foundation
import UserNotifications

@MainActor
final class SkyNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Mirrors `SkyShieldAction.deepLinkUserInfoKey` (extensions can't import Sky).
    nonisolated static let deepLinkKey = "sky_deep_link"

    @Published var pendingLink: SkyDeepLink?

    /// The destination a notification's userInfo names, if any.
    nonisolated static func deepLink(from userInfo: [AnyHashable: Any]) -> SkyDeepLink? {
        (userInfo[deepLinkKey] as? String).flatMap(SkyDeepLink.init(rawValue:))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = Self.deepLink(from: response.notification.request.content.userInfo)
        Task { @MainActor in
            if let link {
                // The App Group copy would present the same screen a second time.
                SharedDefaults().pendingDeepLink = nil
                pendingLink = link
            }
            completionHandler()
        }
    }
}
