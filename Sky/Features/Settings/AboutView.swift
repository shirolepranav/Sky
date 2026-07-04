// AboutView.swift
// S-SET-08 — Legal, support, and version info. Tapping the version row seven
// times enables the hidden debug menu (S-SET-09). Support falls back to copying
// the address when no mail app is configured.
// Sky_App_Workflow.md S-SET-08; Roadmap Phase 15.

import SwiftUI

/// Shared flag for the version-tap-unlocked debug menu. Lives in standard
/// UserDefaults (device-local, not the App Group) so it never syncs.
enum DebugMenuFlag {
    private static let key = "debugMenuEnabled"
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct AboutView: View {
    /// Called when the 7-tap gesture unlocks the debug menu, so the root can
    /// reveal its Debug row without a relaunch.
    var onDebugEnabled: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @State private var versionTaps = 0
    @State private var showDebugToast = false
    @State private var showCopyToast = false

    var body: some View {
        List {
            Section {
                Button("Privacy policy") { openURL(AppBranding.privacyPolicyURL) }
                    .foregroundStyle(SkyColor.ink)
                Button("Terms of service") { openURL(AppBranding.termsOfServiceURL) }
                    .foregroundStyle(SkyColor.ink)
                Button("Support") { contactSupport() }
                    .foregroundStyle(SkyColor.ink)
            }

            Section {
                Button(action: handleVersionTap) {
                    HStack {
                        Text("Version").skyText(.body, color: SkyColor.ink)
                        Spacer()
                        Text(versionString).skyText(.caption, color: SkyColor.inkSoft)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("about.version")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .skyToast(isPresented: $showDebugToast, message: "Debug menu enabled")
        .skyToast(isPresented: $showCopyToast, message: "Copied \(AppBranding.supportEmail)")
        .accessibilityIdentifier("about.root")
    }

    // MARK: - Version / debug unlock

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func handleVersionTap() {
        guard !DebugMenuFlag.isEnabled else { return }
        versionTaps += 1
        if versionTaps >= 7 {
            DebugMenuFlag.isEnabled = true
            showDebugToast = true
            onDebugEnabled()
        }
    }

    // MARK: - Support

    private func contactSupport() {
        guard let url = URL(string: "mailto:\(AppBranding.supportEmail)") else { return }
        openURL(url) { accepted in
            if !accepted {
                #if os(iOS)
                UIPasteboard.general.string = AppBranding.supportEmail
                #endif
                showCopyToast = true
            }
        }
    }
}

#Preview("S-SET-08") {
    NavigationStack { AboutView() }
}
