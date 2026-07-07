// EmergencyUnlockCoordinatorView.swift
// Orchestrates the three-screen emergency-unlock friction gate:
//   S-EMG-01 (intro) → S-EMG-02 (typed reason) → S-EMG-03 (result)
//
// Replaces EmergencyUnlockPlaceholderView as the destination for:
//   • sky://emergency deep link (SkyApp.swift fullScreenCover)
//   • "I can't go outside" button in TodayView
//   • "I can't go outside" button in VerificationFailureView (via VerificationCoordinatorView)
//
// A @State step enum is used instead of NavigationStack because the Cancel
// button in S-EMG-02 exits the entire flow rather than navigating back to
// S-EMG-01 — NavigationStack's automatic back button would misbehave.
//
// Privacy invariant: EmergencyLogStore.shared.add() is the sole write point for
// the typed reason. It is never passed to CloudKitSyncService.
// Sky_App_Workflow.md S-EMG-01/02/03; Roadmap Phase 13.

import SwiftUI
import ManagedSettings

struct EmergencyUnlockCoordinatorView: View {
    var onDismiss:    () -> Void
    /// If set, called when the user taps "Try outside again" in S-EMG-01.
    /// The caller is responsible for routing to S-VER-01. Defaults to onDismiss.
    var onTryOutside: (() -> Void)? = nil

    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var mascotManager: MascotStateManager

    private enum Step: Equatable {
        case intro
        case typedReason
        case result(Int)   // payload = streak count before reset

        static func == (lhs: Step, rhs: Step) -> Bool {
            switch (lhs, rhs) {
            case (.intro, .intro), (.typedReason, .typedReason): return true
            case (.result(let a), .result(let b)): return a == b
            default: return false
            }
        }
    }

    @State private var step: Step = .intro

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            switch step {
            case .intro:
                EmergencyUnlockIntroView(
                    onContinue:   { withAnimation(SkyMotion.stepEase) { step = .typedReason } },
                    onTryOutside: { (onTryOutside ?? onDismiss)() }
                )
                .transition(.asymmetric(
                    insertion:  .move(edge: .trailing),
                    removal:    .opacity
                ))

            case .typedReason:
                EmergencyUnlockTypedReasonView(
                    onUnlock: { reason in handleUnlock(reason: reason) },
                    onCancel: onDismiss
                )
                .transition(.asymmetric(
                    insertion:  .move(edge: .trailing),
                    removal:    .opacity
                ))

            case .result(let prevStreak):
                EmergencyUnlockResultView(
                    previousStreak: prevStreak,
                    onDone: onDismiss
                )
                .transition(.asymmetric(
                    insertion:  .move(edge: .trailing),
                    removal:    .opacity
                ))
            }
        }
        .animation(SkyMotion.stepEase, value: step)
    }

    // MARK: - Unlock logic

    private func handleUnlock(reason: String) {
        let prevStreak = streakManager.progress.currentStreak

        // 1. Persist the entry on-device (never synced to CloudKit)
        let cal = Calendar.current
        let now = Date()
        let entry = EmergencyUnlockEntry(
            id: UUID(),
            date: now,
            typedReason: reason,
            dayOfWeek: cal.component(.weekday, from: now),
            hourOfDay:  cal.component(.hour,    from: now)
        )
        EmergencyLogStore.shared.add(entry)

        // 2. Update SharedDefaults so extensions and TodayView reflect the new state
        let store = SharedDefaults()
        store.didEmergencyUnlockToday = true
        store.isCurrentlyBlocked      = false

        // 3. Clear the active shield in ManagedSettings
        ShieldService.unlockApps()

        // 4. Update streak + mascot state
        streakManager.handleEmergencyUnlock()
        mascotManager.handleEmergencyUnlock()

        // 5. Advance to result screen
        withAnimation(SkyMotion.stepEase) {
            step = .result(prevStreak)
        }
    }
}

#Preview("Emergency flow — intro") {
    EmergencyUnlockCoordinatorView(onDismiss: {})
        .environmentObject(StreakManager())
        .environmentObject(MascotStateManager())
}
