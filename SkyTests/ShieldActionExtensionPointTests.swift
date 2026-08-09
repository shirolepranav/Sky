// ShieldActionExtensionPointTests.swift
// Pins the NSExtensionPointIdentifier of every embedded app extension.
//
// Why this test exists: ShieldActionExtension shipped with
// `com.apple.ManagedSettingsUI.shield-action-service`, which is not a real
// extension point. The two shield extension points live in *different*
// namespaces — configuration under ManagedSettingsUI, action under
// ManagedSettings — and the wrong string fails silently: the appex builds,
// signs, and embeds, PluginKit just never matches it, so ShieldActionDelegate
// is never invoked and both shield buttons are inert. Nothing in the previous
// ShieldConfigurationTests could catch that; they only re-asserted copy
// literals lifted from the source.
//
// Asserts against the *built* .appex inside the test host, so it validates the
// artifact that actually ships rather than a string in the repo.
// Sky_App_Workflow.md S-SHIELD-01/02/03; Technical Spec §7.5.

import XCTest

final class ShieldActionExtensionPointTests: XCTestCase {

    /// Ground truth from the system's own registry
    /// (`ExtensionFoundation.framework/Resources/compatibility.plist`).
    private enum ExtensionPoint {
        static let shieldAction        = "com.apple.ManagedSettings.shield-action-service"
        static let shieldConfiguration = "com.apple.ManagedSettingsUI.shield-configuration-service"
        static let deviceActivity      = "com.apple.deviceactivity.monitor-extension"
    }

    // MARK: - The regression

    func testShieldActionDeclaresTheManagedSettingsExtensionPoint() throws {
        XCTAssertEqual(
            try extensionPointIdentifier(ofAppexNamed: "ShieldActionExtension"),
            ExtensionPoint.shieldAction,
            "Shield-action lives under ManagedSettings, not ManagedSettingsUI. With the "
            + "wrong identifier iOS never registers a handler and both shield buttons do nothing."
        )
    }

    func testShieldConfigurationDeclaresTheManagedSettingsUIExtensionPoint() throws {
        XCTAssertEqual(
            try extensionPointIdentifier(ofAppexNamed: "ShieldConfigurationExtension"),
            ExtensionPoint.shieldConfiguration
        )
    }

    func testDeviceActivityMonitorDeclaresTheMonitorExtensionPoint() throws {
        XCTAssertEqual(
            try extensionPointIdentifier(ofAppexNamed: "DeviceActivityMonitorExtension"),
            ExtensionPoint.deviceActivity
        )
    }

    // MARK: - All three must actually be embedded

    func testAllThreeExtensionsAreEmbeddedInTheHostApp() throws {
        for name in ["ShieldActionExtension", "ShieldConfigurationExtension", "DeviceActivityMonitorExtension"] {
            XCTAssertNoThrow(
                try appexBundle(named: name),
                "\(name).appex is missing from the host app — the shield/monitor callbacks cannot fire."
            )
        }
    }

    // MARK: - Helpers

    private enum LookupError: Error, CustomStringConvertible {
        case appexNotFound(String)
        case noExtensionPointIdentifier(String)

        var description: String {
            switch self {
            case .appexNotFound(let name):
                return "Could not locate \(name).appex inside the test host's PlugIns directory."
            case .noExtensionPointIdentifier(let name):
                return "\(name).appex has no NSExtension.NSExtensionPointIdentifier in its Info.plist."
            }
        }
    }

    private func appexBundle(named name: String) throws -> Bundle {
        // Unit tests run with Sky.app as the host, and the "Embed Foundation
        // Extensions" phase copies every appex into its PlugIns directory.
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let bundle = Bundle(url: plugIns.appendingPathComponent("\(name).appex"))
        else { throw LookupError.appexNotFound(name) }
        return bundle
    }

    private func extensionPointIdentifier(ofAppexNamed name: String) throws -> String {
        let info = try appexBundle(named: name).infoDictionary
        guard let extensionInfo = info?["NSExtension"] as? [String: Any],
              let identifier = extensionInfo["NSExtensionPointIdentifier"] as? String
        else { throw LookupError.noExtensionPointIdentifier(name) }
        return identifier
    }
}
