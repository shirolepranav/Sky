// SkyShieldConfiguration.swift
// Principal class for the ShieldConfiguration extension target
// (Technical Spec §7.5, Sky_App_Workflow.md S-SHIELD-01; DAILY_LOCK_PLAN.md Phase A).
//
// Returns the Sky-branded ShieldConfiguration — warm-cream background, Nimbus
// mascot PNG, "Apps are paused" copy, and two action buttons whose handlers live
// in SkyShieldAction.swift.
//
// Every colour is *adaptive*. iOS draws the shield in the system appearance, so a
// fixed light-mode ink on a dark shield left the title and secondary label
// unreadable. The light/dark pairs mirror SkyColor in ColorTokens.swift —
// extension targets cannot import the main Sky module. AppBranding constants are
// inlined below for the same reason; update both on a rebrand.

import ManagedSettings
import ManagedSettingsUI
import UIKit

// These literals mirror AppBranding.{appName, mascotName}.
private let kAppName    = "Sky"
private let kMascotName = "Nimbus"

/// `light` in light mode, `dark` in dark mode — mirrors `Color(light:dark:)`.
private func adaptive(_ light: UInt32, _ dark: UInt32) -> UIColor {
    UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
}

private func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

final class SkyShieldConfiguration: ShieldConfigurationDataSource {

    // Called when an individual app is shielded.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    // Called when an app inside a blocked category is shielded.
    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    // MARK: - Private

    private func makeShieldConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: adaptive(0xFFF6E5, 0x232633),        // SkyColor.warmCream
            // NimbusCloudy imageset lives in this extension's Assets.xcassets.
            icon: UIImage(named: "NimbusCloudy"),
            title: .init(text: "Apps are paused", color: adaptive(0x2D3748, 0xF0F4F8)),            // ink
            subtitle: .init(
                text: "\(kMascotName) is waiting outside for you ☁",
                color: adaptive(0x5A6373, 0xA8B3C2)                                                // inkSoft
            ),
            // Both buttons close the shield and post a "tap to continue" notification
            // (SkyShieldAction) — an extension cannot launch its container app.
            primaryButtonLabel: .init(text: "Unlock with \(kAppName)", color: rgb(0xFFFFFF)),
            primaryButtonBackgroundColor: rgb(0x52822A),                                          // mossGreenAction
            secondaryButtonLabel: .init(text: "Emergency unlock", color: adaptive(0x5A6373, 0xA8B3C2))
        )
    }
}
