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
// Phase 14: one-shot Pro upsell (S-PAY-01) fires after the user's first
// successful verification while on the Free tier. Shown at most once, tracked
// by `hasSeenFirstVerificationPaywall` in AppStorage.

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
    @EnvironmentObject private var storeKit: StoreKitService
    @StateObject private var flowState = VerificationFlowState()
    @StateObject private var recordingVM = VideoRecordingViewModel()
    @State private var path: [VerificationStep] = []
    @State private var showCloseConfirmation = false
    @State private var showEmergencyFlow = false
    @State private var showPostVerificationPaywall = false
    /// Tracks whether this user has already seen the post-verification paywall upsell.
    @AppStorage("hasSeenFirstVerificationPaywall") private var hasSeenPaywall = false
    /// The sensor reading from the most recent recording; provides location tag for Wanderer badge.
    @State private var lastSensorReading: SensorReading? = nil

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
                onTryOutside: { showEmergencyFlow = false; path = [] }
            )
            .environmentObject(streakManager)
            .environmentObject(mascotManager)
        }
        .fullScreenCover(isPresented: $showPostVerificationPaywall) {
            PaywallView {
                showPostVerificationPaywall = false
                onDismiss()
            }
            .environmentObject(storeKit)
        }
        .navigationBarHidden(true)
    }

    // MARK: Routing

    /// Called when the user taps "Done" on S-VER-06.
    /// Shows the one-shot Pro upsell for free users on first success.
    private func handleSuccessDone() {
        if !storeKit.isPro && !hasSeenPaywall {
            hasSeenPaywall = true
            showPostVerificationPaywall = true
        } else {
            onDismiss()
        }
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
            VerificationSuccessView(onDone: { handleSuccessDone() })
                .navigationBarHidden(true)

        case .failure(let reason):
            VerificationFailureView(
                reason: reason,
                consecutiveFailures: flowState.consecutiveFailures,
                onTryAgain: {
                    flowState.resetFailures()
                    path = []
                },
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
                onTryAgain: { path = [] },
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
        .environmentObject(StoreKitService())
}
