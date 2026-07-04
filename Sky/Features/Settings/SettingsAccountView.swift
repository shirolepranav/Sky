// SettingsAccountView.swift
// S-SET-06 — iCloud account + CloudKit sync status. Sign in with Apple is deferred
// for v1.0; CloudKit syncs off the system iCloud account, so this screen surfaces
// that account state and the live sync health from CloudKitSyncService.
// Sky_App_Workflow.md S-SET-06; Roadmap Phase 12, 15.

import SwiftUI
import CloudKit

struct SettingsAccountView: View {
    @EnvironmentObject private var cloudKitSync: CloudKitSyncService

    @State private var accountStatus: CKAccountStatus? = nil

    var body: some View {
        List {
            Section {
                LabeledContent("Apple ID", value: accountValue)
                LabeledContent("iCloud", value: syncValue)

                if accountStatus == .noAccount {
                    Button("Open iCloud settings") { openSystemSettings() }
                        .foregroundStyle(SkyColor.mossGreen)
                }
            } footer: {
                Text("Sky syncs your streak and progress through your iCloud account. Your verification videos and emergency reasons never leave this device.")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { accountStatus = try? await CKContainer.default().accountStatus() }
        .accessibilityIdentifier("settings.account.root")
    }

    // MARK: - Derived text

    private var accountValue: String {
        guard let status = accountStatus else { return "Checking…" }
        switch status {
        case .available:            return "Linked"
        case .noAccount:            return "Not signed in"
        case .restricted:           return "Restricted"
        case .temporarilyUnavailable: return "Unavailable"
        case .couldNotDetermine:    return "Checking…"
        @unknown default:           return "Unknown"
        }
    }

    private var syncValue: String {
        switch cloudKitSync.syncStatus {
        case .idle:    return "Up to date"
        case .syncing: return "Syncing…"
        case .error:   return "Waiting for connection"
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#Preview("S-SET-06") {
    NavigationStack { SettingsAccountView() }
        .environmentObject(CloudKitSyncService())
}
