// NotificationPermissionView.swift
// S-PERM-03 — Pre-frames the OS notification prompt so the user knows what they're
// agreeing to. Shown once after first setup. "Sure" requests local-only
// authorization (alert + sound, never remote push); "Not now" skips.
// Sky_App_Workflow.md S-PERM-03; Roadmap Phase 15.

import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject private var scheduler: LocalNotificationScheduler
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var streakManager: StreakManager

    /// Called when the primer is dismissed (either choice).
    var onDismiss: () -> Void

    @State private var store = SharedDefaults()

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                NimbusView(state: .fluffyWhite, size: 160)
                    .accessibilityHidden(true)

                Text("Want gentle nudges?")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: SkySpacing.s3) {
                    bullet("A heads-up 30 minutes before your apps pause.")
                    bullet("A note when they do.")
                    bullet("Streak reminders if you're about to break one. (Pro)")
                }
                .padding(.horizontal, SkyLayout.screenMargin)

                Spacer()

                VStack(spacing: SkySpacing.s3) {
                    SkyPrimaryButton("Sure") { Task { await enable() } }
                    SkySecondaryButton("Not now") { finish() }
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("perm.notifications")
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SkySpacing.s3) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SkyColor.mossGreen)
            Text(text).skyText(.body, color: SkyColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func enable() async {
        _ = await scheduler.requestAuthorization()
        let atRisk = streakManager.progress.currentStreak > 0 && !store.didVerifyToday
        await scheduler.rescheduleAll(store: store, isPro: storeKit.isPro, streakAtRisk: atRisk)
        finish()
    }

    private func finish() {
        store.notificationPrimerShown = true
        onDismiss()
    }
}

#Preview("S-PERM-03") {
    NotificationPermissionView(onDismiss: {})
        .environmentObject(LocalNotificationScheduler())
        .environmentObject(StoreKitService())
        .environmentObject(StreakManager())
}
