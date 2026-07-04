// NightModeView.swift
// S-SET-05 — Opt-in toggle to allow verification between sunset and sunrise.
// Writes `nightModeEnabled` to SharedDefaults; VerificationDecisionEngine reads it
// to waive the daylight check only (every other signal still applies).
// Sky_App_Workflow.md S-SET-05; Roadmap Phase 15.

import SwiftUI

struct NightModeView: View {
    @State private var store = SharedDefaults()
    @State private var enabled: Bool = SharedDefaults().nightModeEnabled

    var body: some View {
        List {
            Section {
                Toggle(isOn: $enabled) {
                    Text("Allow after-dark verification")
                        .skyText(.body, color: SkyColor.ink)
                }
                .tint(SkyColor.mossGreen)
                .accessibilityIdentifier("nightMode.toggle")
            } footer: {
                Text("Sky normally requires daylight for verification. Turn this on if you want to verify after sunset — the rest of the checks (movement, GPS, scene) still apply.")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Night mode")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: enabled) { _, newValue in
            store.nightModeEnabled = newValue
        }
        .accessibilityIdentifier("nightMode.root")
    }
}

#Preview("S-SET-05") {
    NavigationStack { NightModeView() }
}
