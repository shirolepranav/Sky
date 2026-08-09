// VerificationCoordinatorView.swift
// Navigation host for the full verification flow (S-VER-01 through S-VER-08).
// Replaces VerificationPlaceholderView with the same external signature
// (onDismiss closure) so SkyApp.swift requires only a one-line swap.
// Sky_App_Workflow.md §Part 2, §0.3 deep-link router.
//
// Phase 11: milestone overlay step added (S-CEL-02).
// Phase 12: real StreakManager integration — streak is updated on verification
// success, milestone is checked against the real new streak value, and any
// newly earned badges are queued in StreakManager.pendingBadgeCelebrations for
// TodayView to display after the cover dismisses.
//
// Phase 14 shipped a one-shot Pro upsell that fired after the user's first
// successful verification. It has been removed: landing a paywall on the beat
// where the user has just walked outside and earned their apps back turns the
// reward into a toll booth. The upsell now lives only where the user is already
// reaching for a Pro capability — SettingsView's upgrade row, the locked
// streak-warning toggle, and the S-PAY-05 gate in LimitConfigurationView.
//
// The retired `hasSeenFirstVerificationPaywall` AppStorage key is deliberately
// left unread rather than migrated; it is inert.

import SwiftUI

// MARK: - Navigation step enum

private enum VerificationStep: Hashable {
    case permissionPreflight
    case recording
    case processing(URL, SensorReading)
    case milestone(Int)  // S-CEL-02 — shown before success when streak hits 3/7/14/30/60/100
    case success
    case failure(FailureReason)
    case interrupted
}

// MARK: - Cross-screen flow state

@MainActor
private final class VerificationFlowState: ObservableObject {
    @Published var consecutiveFailures: Int = 0

    private let rationaleKey = "ver.hasShownPermRationale"

    var hasShownPermissionRationale: Bool {
        get { UserDefaults.standard.bool(forKey: rationaleKey) }
        set { UserDefaults.standard.set(newValue, forKey: rationaleKey) }
    }

    func recordFailure() { consecutiveFailures += 1 }
    func resetFailures() { consecutiveFailures = 0 }
}

// MARK: - Coordinator

struct VerificationCoordinatorView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var mascotManager: MascotStateManager
    @EnvironmentObject private var streakManager: StreakManager
    // No StoreKitService dependency: nothing in this flow is Pro-gated now that
    // the post-verification upsell is gone. Callers may still inject it harmlessly.
    @StateObject private var flowState = VerificationFlowState()
    @StateObject private var recordingVM = VideoRecordingViewModel()
    @State private var path: [VerificationStep] = []
    @State private var showCloseConfirmation = false
    @State private var showEmergencyFlow = false
    /// The sensor reading from the most recent recording; provides location tag for Wanderer badge.
    @State private var lastSensorReading: SensorReading? = nil
    /// The streak value computed on success, shown on S-VER-06.
    @State private var streakAfterVerification: Int = 1

    var body: some View {
        NavigationStack(path: $path) {
            // Root screen: S-VER-01
            VerificationIntroView(
                onPrimary: { handleIntroPrimary() },
                onClose:   { showCloseConfirmation = true }
            )
            .navigationDestination(for: VerificationStep.self) { step in
                destination(for: step)
            }
        }
        .confirmationDialog(
            "Cancel verification?",
            isPresented: $showCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .destructive) { abandon() }
            Button("Keep going", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showEmergencyFlow) {
            EmergencyUnlockCoordinatorView(
                // Dismiss emergency AND close the verification flow
                onDismiss:    { showEmergencyFlow = false; abandon() },
                // Dismiss emergency and restart verification from S-VER-01
                onTryOutside: { showEmergencyFlow = false; restartFlow() }
            )
            .environmentObject(streakManager)
            .environmentObject(mascotManager)
        }
        .navigationBarHidden(true)
    }

    // MARK: Routing

    /// Sends the user back to S-VER-01 for another attempt.
    ///
    /// `recordingVM` is a single `@StateObject` shared by every attempt in this
    /// flow, so popping the navigation path is not enough — the view model would
    /// still be holding the finished attempt's elapsed time, prompt index, and
    /// configured capture session. Every retry entry point must go through here.
    private func restartFlow() {
        recordingVM.reset()
        flowState.resetFailures()
        path = []
    }

    /// Leaves the flow without a pass.
    ///
    /// Reconciles first: backing out of verification must never be a way to end
    /// up unblocked. If anything lifted the shield while the flow was open — a
    /// late midnight reset, an OS quirk — this puts it back before the cover
    /// dismisses, rather than waiting for the next foreground.
    private func abandon() {
        ShieldService.reconcile()
        onDismiss()
    }

    private func handleIntroPrimary() {
        if flowState.hasShownPermissionRationale {
            path.append(.permissionPreflight)
        } else {
            flowState.hasShownPermissionRationale = true
            path.append(.permissionPreflight)
        }
    }

    @ViewBuilder
    private func destination(for step: VerificationStep) -> some View {
        switch step {
        case .permissionPreflight:
            PermissionPreflightView(
                onAllGranted: { path.append(.recording) }
            )
            .navigationBarHidden(true)

        case .recording:
            VideoRecordingView(
                vm: recordingVM,
                onFinished: { url, reading in
                    lastSensorReading = reading
                    path.append(.processing(url, reading))
                },
                onCancelled:   { path = []; abandon() },
                onInterrupted: { path.append(.interrupted) }
            )
            .navigationBarHidden(true)

        case .processing(let url, let reading):
            VerificationProcessingView(
                input: VerificationInput(videoURL: url, sensorReading: reading),
                service: RealVerificationService(),
                onSuccess: {
                    // Update streak first — the new streak value determines whether
                    // a milestone overlay is shown.
                    let (newStreak, newBadges) = streakManager.handleVerificationSuccess(
                        locationTag: lastSensorReading?.bestLocationTag,
                        time: Date()
                    )
                    // Queue badge celebrations for TodayView to display after dismiss.
                    if !newBadges.isEmpty {
                        streakManager.pendingBadgeCelebrations = newBadges
                    }
                    mascotManager.handleVerificationSuccess()
                    // S-VER-06's streak chip animates to this. It used to take the
                    // `currentStreak: Int = 1` default and always land on 1.
                    streakAfterVerification = newStreak
                    if streakManager.isMilestoneStreak(newStreak) {
                        path.append(.milestone(newStreak))
                    } else {
                        path.append(.success)
                    }
                },
                onFailure: { reason in
                    flowState.recordFailure()
                    path.append(.failure(reason))
                }
            )
            .navigationBarHidden(true)

        case .milestone(let days):
            MilestoneOverlayView(streakDays: days) {
                path.append(.success)
            }
            .navigationBarHidden(true)

        case .success:
            VerificationSuccessView(onDone: onDismiss, currentStreak: streakAfterVerification)
                .navigationBarHidden(true)

        case .failure(let reason):
            VerificationFailureView(
                reason: reason,
                consecutiveFailures: flowState.consecutiveFailures,
                onTryAgain: { restartFlow() },
                onEmergency: {
                    // Phase 13: route to the full typed-reason friction gate.
                    // Streak reset happens inside EmergencyUnlockCoordinatorView
                    // only after the user completes the typed-reason screen.
                    showEmergencyFlow = true
                },
                onClose: { abandon() }
            )
            .navigationBarHidden(true)

        case .interrupted:
            RecordingInterruptedView(
                onTryAgain: { restartFlow() },
                onDismiss:  { abandon() }
            )
            .navigationBarHidden(true)
        }
    }
}

#Preview("Verification flow") {
    VerificationCoordinatorView(onDismiss: {})
        .environmentObject(MascotStateManager())
        .environmentObject(StreakManager())
}
