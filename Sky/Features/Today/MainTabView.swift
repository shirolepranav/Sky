// MainTabView.swift
// S-TAB-00 — Persistent three-tab navigation home. Replaces MainPlaceholderView
// as the `.main` route destination once the app is fully configured.
// Sky_App_Workflow.md §Group C S-TAB-00; Roadmap Phase 11.
//
// Phase 12: Streaks tab wired to StreaksView.
// Phase 14: StoreKitService injected as environment object; Settings tab shows
// SubscriptionView (S-SET-07) as a placeholder until Phase 15 adds the full
// SettingsView.

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var mascotManager: MascotStateManager
    @EnvironmentObject private var deviceActivity: DeviceActivityService
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var cloudKitSync: CloudKitSyncService
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var scheduler: LocalNotificationScheduler

    @SceneStorage("selectedTab") private var selectedTab: Int = 0
    @State private var todayBadge: Int = 0
    @State private var store = SharedDefaults()

    var body: some View {
        TabView(selection: $selectedTab) {
            // Today tab
            NavigationStack {
                TodayView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .badge(todayBadge)
            .tag(0)

            // Streaks tab — Phase 12
            StreaksView()
                .environmentObject(streakManager)
                .environmentObject(cloudKitSync)
                .environmentObject(storeKit)
                .tabItem {
                    Label("Streaks", systemImage: "flame.fill")
                }
                .badge(streaksBadge)
                .tag(1)

            // Settings tab — S-SET-01 full settings hub (Phase 15).
            SettingsView()
                .environmentObject(storeKit)
                .environmentObject(scheduler)
                .environmentObject(streakManager)
                .environmentObject(cloudKitSync)
                .environmentObject(deviceActivity)
                .environmentObject(mascotManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(SkyColor.mossGreen)
        .onAppear { refreshBadge() }
        .onChange(of: store.isCurrentlyBlocked) { refreshBadge() }
        .onChange(of: store.didVerifyToday) { refreshBadge() }
    }

    /// Non-zero when there is a newly earned but not-yet-viewed badge.
    private var streaksBadge: Int {
        let unviewed = streakManager.progress.unlockedBadges.filter { badge in
            !UserDefaults.standard.bool(forKey: "viewedBadge_\(badge.rawValue)")
        }
        return unviewed.isEmpty ? 0 : 1
    }

    private func refreshBadge() {
        store = SharedDefaults()
        todayBadge = (store.isCurrentlyBlocked && !store.didVerifyToday) ? 1 : 0
    }
}

#Preview("S-TAB-00") {
    MainTabView()
        .environmentObject(MascotStateManager())
        .environmentObject(DeviceActivityService())
        .environmentObject(StreakManager())
        .environmentObject(CloudKitSyncService())
        .environmentObject(StoreKitService())
        .environmentObject(LocalNotificationScheduler())
        .environmentObject(FamilyControlsService())
        .environmentObject(AppearanceManager())
}
