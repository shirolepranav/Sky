// SettingsAppsAndLimitsView.swift
// S-SET-02 — Re-entry into app selection (S-CFG-01) and the lock time
// (S-CFG-03) for editing. Each row shows the current state at a glance. Saving a
// change re-arms DeviceActivity monitoring so the new configuration takes effect.
// Sky_App_Workflow.md S-SET-02; Roadmap Phase 15.

import SwiftUI

struct SettingsAppsAndLimitsView: View {
    @EnvironmentObject private var deviceActivity: DeviceActivityService

    @State private var store = SharedDefaults()

    var body: some View {
        List {
            Section {
                NavigationLink {
                    EditAppsScreen { rearm() }
                } label: {
                    row(title: "Apps", subtitle: appsSubtitle, coral: store.selectionNeedsRedo)
                }
                .accessibilityIdentifier("settings.apps.edit")

                NavigationLink {
                    EditLimitsScreen { rearm() }
                } label: {
                    row(title: "Lock time", subtitle: limitSubtitle, coral: false)
                }
                .accessibilityIdentifier("settings.limits.edit")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Apps & Lock")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store = SharedDefaults() }
        .accessibilityIdentifier("settings.appsAndLimits.root")
    }

    // MARK: - Rows

    private func row(title: String, subtitle: String, coral: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).skyText(.body, color: SkyColor.ink)
            Text(subtitle).skyText(.caption, color: coral ? SkyColor.coralStreak : SkyColor.inkSoft)
        }
    }

    // MARK: - Derived subtitles

    private var appsSubtitle: String {
        if store.selectionNeedsRedo { return "Re-select apps" }
        return AppSelectionViewModel().summaryText
    }

    private var limitSubtitle: String {
        let days = store.lockWeekdays.count == 7 ? "every day" : "\(store.lockWeekdays.count) days a week"
        return "\(store.lockTimeLabel), \(days)"
    }

    // MARK: - Actions

    private func rearm() {
        store = SharedDefaults()
        try? deviceActivity.startMonitoring()
        // A lock time moved to an hour already past today applies now — the
        // extension ignores the start iOS fires on registration.
        ShieldService.reconcile()
    }
}

// MARK: - Edit screen wrappers (own their dismiss so the callbacks can pop)

private struct EditAppsScreen: View {
    var onDone: () -> Void
    @StateObject private var viewModel = AppSelectionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSelectionView(viewModel: viewModel, onContinue: { onDone(); dismiss() })
    }
}

private struct EditLimitsScreen: View {
    var onDone: () -> Void
    @StateObject private var viewModel = LimitConfigurationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LimitConfigurationView(viewModel: viewModel, onSave: { onDone(); dismiss() })
    }
}

#Preview("S-SET-02") {
    NavigationStack { SettingsAppsAndLimitsView() }
        .environmentObject(DeviceActivityService())
        .environmentObject(StoreKitService())
}
