// DebugMenuView.swift
// S-SET-09 — Hidden developer/QA utilities. Reachable after the 7-tap version
// unlock (S-SET-08) or a long-press on Nimbus. Each row triggers a side effect
// and shows a result toast. Never listed in the App Store surface.
// Sky_App_Workflow.md S-SET-09; Roadmap Phase 0, 1.
//
// ⚠️ DEBUG BUILDS ONLY. This used to ship in Release behind nothing but the
// 7-tap gesture, which made "Force midnight reset" a one-tap unblock for any
// user who read a support thread — the shield is the product, so it cannot have
// a shipping bypass. `SettingsView.debugSection` and the `AboutView` tap counter
// are gated to match. Keep the #Preview inside the #if or Release archives break
// (CLAUDE.md, Build & verify §2).

#if DEBUG
import SwiftUI
import ManagedSettings
import FamilyControls

struct DebugMenuView: View {
    @EnvironmentObject private var mascotManager: MascotStateManager
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var deviceActivity: DeviceActivityService

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
                Button("Force re-arm monitoring") { forceReArmMonitoring() }
                Button("Rewind day stamps to yesterday") { forceStaleDayStamp() }
                Button("Run shield reconcile") { runReconcile() }
                Menu("Force mascot state") {
                    ForEach(MascotState.allCases, id: \.self) { state in
                        Button(state.displayName) {
                            mascotManager.debugSetState(state)
                            flash("Mascot → \(state.displayName)")
                        }
                    }
                }
            }

            Section("Pro demo account") {
                Toggle("Simulate Pro", isOn: Binding(
                    get: { storeKit.isPro },
                    set: { pro in
                        storeKit.debugSetPro(pro)
                        flash(pro ? "Pro granted" : "Back to Free")
                    }
                ))
                .tint(SkyColor.mossGreen)

                Button("Seed full Pro demo account") {
                    DebugSeeder.applyFullProAccount(streakManager: streakManager,
                                                    storeKit: storeKit,
                                                    store: store)
                    flash("Seeded full Pro account")
                }

                Button("Unlock all 10 badges") {
                    DebugSeeder.unlockAllBadges(streakManager: streakManager)
                    flash("All badges unlocked")
                }
                Button("Set 100-day streak") {
                    DebugSeeder.set100DayStreak(streakManager: streakManager)
                    flash("Streak → 100 days")
                }
                Button("Add emergency + pause history") {
                    DebugSeeder.seedEmergencyHistory()
                    flash("Emergency history added")
                }
                Button("Add weekly-insights data") {
                    DebugSeeder.seedWeeklyInsights(streakManager: streakManager)
                    flash("Weekly-insights data added")
                }
            }

            Section("Inspect") {
                NavigationLink("Shield history") { ShieldHistoryView() }
                NavigationLink("Signal probe") { SignalProbeView() }
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
        store.stampTodayState()
        store.todayResetToken = MidnightResetRecovery.dayStamp(for: Date())
        ShieldService.unlockApps(source: .debug, store: store)
        mascotManager.refreshState()
        flash("Midnight reset applied")
    }

    /// Rewinds the day stamps to yesterday, reproducing the state a device is in
    /// when `intervalDidStart` was missed overnight — the setup for the "Go
    /// outside to unlock" unlock bug. Pair with "Force shield apply".
    private func forceStaleDayStamp() {
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let stamp = MidnightResetRecovery.dayStamp(for: yesterday)
        store.todayResetToken = stamp
        store.todayStateDay = stamp
        flash("Day stamps → \(stamp)")
    }

    private func forceShieldApply() {
        guard let selection = store.selection else { flash("No selection to shield"); return }
        ShieldService.applyShield(
            tokens: selection.applicationTokens,
            categories: selection.categoryTokens,
            source: .debug,
            store: store
        )
        store.isCurrentlyBlocked = true
        store.stampTodayState()
        mascotManager.refreshState()
        flash("Shield applied")
    }

    private func runReconcile() {
        let restored = ShieldService.reconcile(store: store)
        mascotManager.refreshState()
        flash(restored ? "Shield restored" : "Nothing to restore")
    }


    /// Bypasses the configuration-fingerprint guard in `DeviceActivityService`.
    /// Normal foregrounds deliberately skip re-registering so the day's usage
    /// accumulation isn't reset (TIME_REMAINING_PLAN.md §2) — this is the escape
    /// hatch for verifying a schedule change on device.
    private func forceReArmMonitoring() {
        do {
            try deviceActivity.startMonitoring(force: true)
            flash(deviceActivity.isMonitoring ? "Monitoring re-armed" : "Nothing to monitor")
        } catch {
            flash("Re-arm failed: \(error.localizedDescription)")
        }
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
        night=\(store.nightModeEnabled) limit=\(store.combinedLimitSeconds)s \
        resetToken=\(store.todayResetToken) stateDay=\(store.todayStateDay)
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
        // Reset the live managers too, so the wipe is reflected without a relaunch,
        // and clear the on-device emergency/pause log seeded by the demo account.
        streakManager.debugReplaceProgress(UserProgress())
        EmergencyLogStore.shared.debugClear()
        storeKit.debugSetPro(false)
        wipeTaps = 0
        flash("Local progress wiped")
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
        .environmentObject(StreakManager())
        .environmentObject(DeviceActivityService())
}
#endif
