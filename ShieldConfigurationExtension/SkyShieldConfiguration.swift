// SkyShieldConfiguration.swift
// Principal class for the ShieldConfiguration extension target
// (Technical Spec §7.5, Sky_App_Workflow.md S-SHIELD-01).
//
// Phase 6: returns the Sky-branded ShieldConfiguration — warm-cream background,
// Nimbus mascot PNG, "Time's up" copy, and two action buttons whose handlers live
// in SkyShieldAction.swift.
//
// Extension targets cannot import the main Sky module, so colour values are
// expressed as UIColor literals that mirror SkyColor in ColorTokens.swift.
// AppBranding constants are inlined below — update both on a rebrand.

import ManagedSettings
import ManagedSettingsUI
import UIKit

// These literals mirror AppBranding.{appName, mascotName} — extensions cannot
// import the main Sky target. Update both files if the product is rebranded.
private let kAppName    = "Sky"
private let kMascotName = "Nimbus"

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
            // #FFF6E5 warmCream — matches SkyColor.warmCream
            backgroundColor: UIColor(red: 1.0, green: 246/255, blue: 229/255, alpha: 1),
            // NimbusCloudy imageset lives in this extension's Assets.xcassets.
            // Run NimbusPNGExporter (Sky/Features/Mascot/NimbusPNGExporter.swift)
            // once in the iOS Simulator to generate the @1x/@2x/@3x PNG files
            // and add them to ShieldConfigurationExtension/Assets.xcassets/NimbusCloudy.imageset/.
            icon: UIImage(named: "NimbusCloudy"),
            // #2D3748 ink — matches SkyColor.ink
            title: .init(
                text: "\(kAppName) — Time's up",
                color: UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1)
            ),
            // #5A6373 inkSoft — matches SkyColor.inkSoft
            subtitle: .init(
                text: "\(kMascotName) is waiting outside for you ☁",
                color: UIColor(red: 90/255, green: 99/255, blue: 115/255, alpha: 1)
            ),
            primaryButtonLabel: .init(text: "Go outside to unlock", color: .white),
            // #52822A mossGreenAction — only green that clears WCAG AA with white label
            primaryButtonBackgroundColor: UIColor(red: 82/255, green: 130/255, blue: 42/255, alpha: 1),
            // #2D3748 ink
            secondaryButtonLabel: .init(
                text: "I can't go outside right now",
                color: UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1)
            )
        )
    }
}
