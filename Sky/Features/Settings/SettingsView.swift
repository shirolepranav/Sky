// SettingsView.swift
// S-SET-01 — Central configuration hub. Grouped list linking to every settings
// sub-screen, with inline notification quick-toggles and Pro-gated rows (Pause,
// Streak warning). Replaces the Phase 14 SubscriptionView placeholder as the
// Settings tab root.
// Sky_App_Workflow.md S-SET-01; Roadmap Phase 15.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var scheduler: LocalNotificationScheduler
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var appearance: AppearanceManager

    @State private var store = SharedDefaults()
    @State private var morning = SharedDefaults().notifMorningEnabled
    @State private var warning = SharedDefaults().notifWarningEnabled
    @State private var streak  = SharedDefaults().notifStreakEnabled
    @State private var debugEnabled = DebugMenuFlag.isEnabled
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                appsAndLimitsSection
                appearanceSection
                pauseSection
                notificationsSection
                nightModeSection
                accountSection
                subscriptionSection
                aboutSection
                if debugEnabled { debugSection }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SkyColor.surface.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { reloadFlags() }
            .onChange(of: morning) { _, v in store.notifMorningEnabled = v; reschedule() }
            .onChange(of: warning) { _, v in store.notifWarningEnabled = v; reschedule() }
            .onChange(of: streak)  { _, v in store.notifStreakEnabled  = v; reschedule() }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
                    .environmentObject(storeKit)
            }
        }
        .accessibilityIdentifier("settings.root")
    }

    // MARK: - Sections

    private var appsAndLimitsSection: some View {
        Section("Apps & Limits") {
            NavigationLink("Apps & daily limits") { SettingsAppsAndLimitsView() }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            NavigationLink {
                AppearanceView()
            } label: {
                HStack {
                    Text("Appearance").skyText(.body, color: SkyColor.ink)
                    Spacer()
                    Text(appearance.mode.title).skyText(.body, color: SkyColor.inkMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var pauseSection: some View {
        Section("Pause") {
            if storeKit.isPro {
                NavigationLink { PauseSkyView() } label: {
                    Text("Pause Sky for 24 hours").skyText(.body, color: SkyColor.ink)
                }
            } else {
                Button { showPaywall = true } label: {
                    lockedRow("Pause Sky for 24 hours")
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Morning reminder", isOn: $morning).tint(SkyColor.mossGreen)
            Toggle("30-minute warning", isOn: $warning).tint(SkyColor.mossGreen)
            if storeKit.isPro {
                Toggle("Streak warning", isOn: $streak).tint(SkyColor.mossGreen)
            } else {
                Button { showPaywall = true } label: { lockedRow("Streak warning") }
            }
            NavigationLink("All notifications") { NotificationTogglesView() }
        }
    }

    private var nightModeSection: some View {
        Section("Night Mode") {
            NavigationLink("Allow verification after sunset") { NightModeView() }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            NavigationLink("iCloud sync status") { SettingsAccountView() }
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            NavigationLink(tierTitle) { SubscriptionView() }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                AboutView(onDebugEnabled: { debugEnabled = true })
            } label: {
                Text("Privacy, terms & support").skyText(.body, color: SkyColor.ink)
            }
        }
    }

    private var debugSection: some View {
        Section("Developer") {
            NavigationLink("Debug menu") { DebugMenuView() }
        }
    }

    // MARK: - Helpers

    private func lockedRow(_ title: String) -> some View {
        HStack {
            Text(title).skyText(.body, color: SkyColor.inkSoft)
            Spacer()
            Label("Pro", systemImage: "lock.fill")
                .skyText(.caption, color: SkyColor.inkMuted)
                .labelStyle(.titleAndIcon)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(title). Pro feature, locked. Tap to see Pro.")
    }

    private var tierTitle: String {
        storeKit.isPro ? "Sky Pro" : "Sky Free — Upgrade"
    }

    private func reloadFlags() {
        store = SharedDefaults()
        morning = store.notifMorningEnabled
        warning = store.notifWarningEnabled
        streak = store.notifStreakEnabled
        debugEnabled = DebugMenuFlag.isEnabled
    }

    private func reschedule() {
        let atRisk = streakManager.progress.currentStreak > 0 && !store.didVerifyToday
        Task { await scheduler.rescheduleAll(store: store, isPro: storeKit.isPro, streakAtRisk: atRisk) }
    }
}

#Preview("S-SET-01") {
    SettingsView()
        .environmentObject(StoreKitService())
        .environmentObject(LocalNotificationScheduler())
        .environmentObject(StreakManager())
        .environmentObject(CloudKitSyncService())
        .environmentObject(DeviceActivityService())
        .environmentObject(MascotStateManager())
        .environmentObject(AppearanceManager())
}
