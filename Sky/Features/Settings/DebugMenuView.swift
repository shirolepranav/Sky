// DebugMenuView.swift
// S-SET-09 — Hidden developer/QA utilities. Reachable only after the 7-tap version
// unlock (S-SET-08) or, in Debug builds, a long-press on Nimbus. Each row triggers
// a side effect and shows a result toast. Never listed in the App Store surface.
// Sky_App_Workflow.md S-SET-09; Roadmap Phase 0, 1.

import SwiftUI
import ManagedSettings
import FamilyControls

struct DebugMenuView: View {
    @EnvironmentObject private var mascotManager: MascotStateManager
    @EnvironmentObject private var storeKit: StoreKitService

    @State private var store = SharedDefaults()
    @State private var toast = ""
    @State private var showToast = false
    @State private var wipeTaps = 0

    var body: some View {
        List {
            Section("Surfaces") {
                NavigationLink("Design System Preview") { DesignSystemPreviewScreen() }
            }

            Section("State") {
                Button("Force midnight reset") { forceMidnightReset() }
                Button("Force shield apply") { forceShieldApply() }
                #if DEBUG
                Menu("Force mascot state") {
                    ForEach(MascotState.allCases, id: \.self) { state in
                        Button(state.displayName) {
                            mascotManager.debugSetState(state)
                            flash("Mascot → \(state.displayName)")
                        }
                    }
                }
                Button(storeKit.isPro ? "Toggle Pro (currently ON)" : "Toggle Pro (currently OFF)") {
                    storeKit.debugTogglePro()
                    flash(storeKit.isPro ? "Pro ON" : "Pro OFF")
                }
                #endif
            }

            Section("Inspect") {
                Button("View temp video files") { countTempVideos() }
                Button("Dump SharedDefaults") { dumpDefaults() }
            }

            Section("Destructive") {
                Button(wipeLabel, role: .destructive) { wipeProgress() }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Debug menu")
        .navigationBarTitleDisplayMode(.inline)
        .skyToast(isPresented: $showToast, message: toast)
        .accessibilityIdentifier("debug.root")
    }

    // MARK: - Actions

    private func forceMidnightReset() {
        store.yesterdayDidVerify = store.didVerifyToday
        store.yesterdayDidEmergency = store.didEmergencyUnlockToday
        store.pendingMidnightReset = true
        store.isCurrentlyBlocked = false
        store.didVerifyToday = false
        store.didEmergencyUnlockToday = false
        ShieldService.unlockApps()
        mascotManager.refreshState()
        flash("Midnight reset applied")
    }

    private func forceShieldApply() {
        guard let selection = store.selection else { flash("No selection to shield"); return }
        let managed = ManagedSettingsStore()
        managed.shield.applications = selection.applicationTokens
        if !selection.categoryTokens.isEmpty {
            managed.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        store.isCurrentlyBlocked = true
        mascotManager.refreshState()
        flash("Shield applied")
    }

    private func countTempVideos() {
        let dir = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let videos = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
        flash("\(videos.count) temp video file(s)")
    }

    private func dumpDefaults() {
        let summary = """
        blocked=\(store.isCurrentlyBlocked) verified=\(store.didVerifyToday) \
        emergency=\(store.didEmergencyUnlockToday) paused=\(store.isPaused) \
        night=\(store.nightModeEnabled) limit=\(store.combinedLimitSeconds)s
        """
        print("[SharedDefaults] \(summary)")
        flash("Dumped to console")
    }

    private var wipeLabel: String {
        wipeTaps == 0 ? "Wipe local progress" : "Tap \(3 - wipeTaps)× more to confirm"
    }

    private func wipeProgress() {
        wipeTaps += 1
        guard wipeTaps >= 3 else { return }
        UserDefaults.standard.removeObject(forKey: "userProgress")
        store.didVerifyToday = false
        store.didEmergencyUnlockToday = false
        store.isCurrentlyBlocked = false
        store.pauseStartedAt = nil
        store.lastPauseDate = nil
        wipeTaps = 0
        flash("Local progress wiped — relaunch to reload")
    }

    private func flash(_ message: String) {
        toast = message
        showToast = true
    }
}

#Preview("S-SET-09") {
    NavigationStack { DebugMenuView() }
        .environmentObject(MascotStateManager())
        .environmentObject(StoreKitService())
}
