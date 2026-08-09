// NotificationTogglesView.swift
// S-SET-04 — Per-notification opt-in/out. Writes flags to SharedDefaults and
// re-schedules calendar notifications via LocalNotificationScheduler. Block-start
// is always on (PRD §4.11) and shown as a disabled row. When OS notifications are
// denied, every toggle is disabled with a deep link to Settings.
// Sky_App_Workflow.md S-SET-04; Roadmap Phase 15.

import SwiftUI
import UserNotifications

struct NotificationTogglesView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var scheduler: LocalNotificationScheduler
    @EnvironmentObject private var streakManager: StreakManager

    @State private var store = SharedDefaults()
    @State private var warning = SharedDefaults().notifWarningEnabled
    @State private var streak  = SharedDefaults().notifStreakEnabled
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private var denied: Bool {
        authStatus == .denied
    }

    var body: some View {
        List {
            if denied {
                Section {
                    Button("Enable in Settings") { openSystemSettings() }
                        .foregroundStyle(SkyColor.mossGreen)
                        .accessibilityIdentifier("notif.enableInSettings")
                } footer: {
                    Text("Notifications are turned off for Sky. Turn them on in the iOS Settings app to use these reminders.")
                        .skyText(.caption, color: SkyColor.inkSoft)
                }
            }

            Section {
                toggleRow("30-minute warning before block", isOn: $warning)

                // Block start — always on per PRD §4.11.
                HStack {
                    Text("Block start")
                        .skyText(.body, color: SkyColor.inkSoft)
                    Spacer()
                    Text("Always on")
                        .skyText(.caption, color: SkyColor.inkMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Block start notification. Always on.")

                if storeKit.isPro {
                    toggleRow("Streak warning at 10 PM", isOn: $streak)
                } else {
                    proLockedRow("Streak warning at 10 PM")
                }
            } footer: {
                Text("Sky sends at most two a day, and only when your own usage triggers them. All of them are scheduled by your phone — Sky doesn't use push servers.")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { authStatus = await scheduler.authorizationStatus() }
        .onChange(of: warning) { _, v in store.notifWarningEnabled = v; reschedule() }
        .onChange(of: streak)  { _, v in store.notifStreakEnabled  = v; reschedule() }
        .accessibilityIdentifier("notif.root")
    }

    // MARK: - Rows

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).skyText(.body, color: SkyColor.ink)
        }
        .tint(SkyColor.mossGreen)
        .disabled(denied)
    }

    private func proLockedRow(_ title: String) -> some View {
        HStack {
            Text(title).skyText(.body, color: SkyColor.inkSoft)
            Spacer()
            Label("Pro", systemImage: "lock.fill")
                .skyText(.caption, color: SkyColor.inkMuted)
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("\(title). Pro feature, locked.")
    }

    // MARK: - Actions

    private func reschedule() {
        let atRisk = streakManager.progress.currentStreak > 0 && !store.didVerifyToday
        Task { await scheduler.rescheduleAll(store: store, isPro: storeKit.isPro, streakAtRisk: atRisk) }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#Preview("S-SET-04") {
    NavigationStack { NotificationTogglesView() }
        .environmentObject(StoreKitService())
        .environmentObject(LocalNotificationScheduler())
        .environmentObject(StreakManager())
}
