// VerificationCoordinatorView.swift
// Navigation host for the full verification flow (S-VER-01 through S-VER-08).
// Replaces VerificationPlaceholderView with the same external signature
// (onDismiss closure) so SkyApp.swift requires only a one-line swap.
// Sky_App_Workflow.md §Part 2, §0.3 deep-link router.

import SwiftUI

// MARK: - Navigation step enum

private enum VerificationStep: Hashable {
    case permissionPreflight
    case recording
    case processing(URL, SensorReading)
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

    @StateObject private var flowState = VerificationFlowState()
    @StateObject private var recordingVM = VideoRecordingViewModel()
    @State private var path: [VerificationStep] = []
    @State private var showCloseConfirmation = false

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
            Button("Cancel", role: .destructive) { onDismiss() }
            Button("Keep going", role: .cancel) {}
        }
        .navigationBarHidden(true)
    }

    // MARK: Routing

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
                onFinished:    { url, reading in path.append(.processing(url, reading)) },
                onCancelled:   { path = []; onDismiss() },
                onInterrupted: { path.append(.interrupted) }
            )
            .navigationBarHidden(true)

        case .processing(let url, let reading):
            VerificationProcessingView(
                input: VerificationInput(videoURL: url, sensorReading: reading),
                onSuccess: { path.append(.success) },
                onFailure: { reason in
                    flowState.recordFailure()
                    path.append(.failure(reason))
                }
            )
            .navigationBarHidden(true)

        case .success:
            VerificationSuccessView(onDone: { onDismiss() })
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
                    // Phase 13 wires the real emergency unlock flow.
                    // For now, dismiss and let SkyApp present the placeholder.
                    onDismiss()
                },
                onClose: { onDismiss() }
            )
            .navigationBarHidden(true)

        case .interrupted:
            RecordingInterruptedView(
                onTryAgain: { path = [] },
                onDismiss:  { onDismiss() }
            )
            .navigationBarHidden(true)
        }
    }
}

#Preview("Verification flow") {
    VerificationCoordinatorView(onDismiss: {})
}
