// VerificationSuccessView.swift
// S-VER-06 — Rewards the user, clears the shield, and writes today-state flags.
// Sky_App_Workflow.md §Part 2 S-VER-06; Tech Spec §7.6.

import ManagedSettings
import SwiftUI

struct VerificationSuccessView: View {
    var onDone: () -> Void
    var store: SharedDefaults = SharedDefaults()
    /// Stub value of 1 for Phase 7; Phase 12 derives the real count from UserProgress.
    var currentStreak: Int = 1

    @State private var mascotState: MascotState = .rainbow
    @State private var displayedStreak: Int = 0
    @State private var unlockFailed: Bool = false
    @State private var showUnlockError: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SkyColor.surface, SkyColor.warmCream],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: SkySpacing.s5) {
                Spacer()

                NimbusView(state: mascotState, size: 200)

                Text("Verified ☀")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)

                Text("Apps are open until midnight. Enjoy your day.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                SkyStreakChip(days: displayedStreak)

                Spacer()

                if showUnlockError {
                    Text("Couldn't fully clear shields — restart Sky if apps remain blocked.")
                        .skyText(.bodyS, color: SkyColor.coralStreak)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                SkyPrimaryButton("Done", action: onDone)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.success")
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Verified. Apps are open until midnight."
            )
        }
        .task { await performUnlock() }
    }

    private func performUnlock() async {
        // 1. Write today-state flags
        store.didVerifyToday = true
        store.isCurrentlyBlocked = false
        store.verificationCompletedAt = Date()

        // 2. Clear the ManagedSettings shield
        let settings = ManagedSettingsStore()
        settings.shield.applications = nil
        settings.shield.applicationCategories = nil

        // 3. Animate streak chip after short delay
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.spring(response: 0.6)) {
            displayedStreak = currentStreak
        }

        // 4. Transition Nimbus rainbow → sunny after 5s
        try? await Task.sleep(for: .seconds(5))
        withAnimation(.easeInOut(duration: 0.5)) {
            mascotState = .sunny
        }
    }
}

#Preview("S-VER-06") {
    VerificationSuccessView(onDone: {}, currentStreak: 7)
}

#Preview("S-VER-06 dark") {
    VerificationSuccessView(onDone: {}, currentStreak: 3)
        .preferredColorScheme(.dark)
}
