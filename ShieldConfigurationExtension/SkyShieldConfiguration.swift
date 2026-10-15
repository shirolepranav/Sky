// SkyShieldConfiguration.swift
// Principal class for the ShieldConfiguration extension target
// (Technical Spec §7.5, Sky_App_Workflow.md S-SHIELD-01; DAILY_LOCK_PLAN.md Phase A).
//
// Returns the Sky-branded ShieldConfiguration — Sky Pop sun ground, the
// outlined sticker Nimbus PNG, "Apps are paused" copy, and two action buttons
// whose handlers live in SkyShieldAction.swift.
//
// Sky Pop (Sky Pop canvas board "ShieldPop"). The system only lets us set the
// background colour, icon, title, subtitle and button colours — a custom
// SwiftUI view (outlined buttons, chips) is impossible here. So: popSun ground,
// ink text, and an ink primary button with a cream label.
//
// The ground is a Pop colour, which stays bright in dark mode, so every colour
// here is *fixed* (not adaptive): ink on sun reads in both appearances. The hex
// values mirror SkyColor in ColorTokens.swift — extension targets cannot import
// the main Sky module. AppBranding constants are inlined below for the same
// reason; update both on a rebrand.
//
// The icon is NimbusCloudy.png in this target's Assets.xcassets, exported from
// the sticker NimbusView by Features/Mascot/NimbusPNGExporter.swift.

import ManagedSettings
import ManagedSettingsUI
import UIKit

// These literals mirror AppBranding.{appName, mascotName}.
private let kAppName    = "Sky"
private let kMascotName = "Nimbus"

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
            backgroundColor: rgb(0xFFC93C),                       // SkyColor.popSun
            // NimbusCloudy imageset lives in this extension's Assets.xcassets.
            icon: UIImage(named: "NimbusCloudy"),
            title: .init(text: "Apps are paused", color: rgb(0x2D3748)),                         // inkOnAccent
            // Subtitle is ink too: inkSoft on popSun is only ~4:1, under AA.
            subtitle: .init(
                text: "\(kMascotName) is waiting outside for you ☁",
                color: rgb(0x2D3748)                                                              // inkOnAccent
            ),
            // Both buttons close the shield and post a "tap to continue" notification
            // (SkyShieldAction) — an extension cannot launch its container app.
            primaryButtonLabel: .init(text: "Unlock with \(kAppName)", color: rgb(0xFFFBF2)),   // cream label
            primaryButtonBackgroundColor: rgb(0x2D3748),                                          // ink button
            secondaryButtonLabel: .init(text: "Emergency unlock", color: rgb(0x2D3748))
        )
    }
}
