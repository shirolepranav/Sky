// VerificationProcessingView.swift
// S-VER-05 — Reassuring processing screen while the verification pipeline runs.
// Phase 8: accepts VerificationInput (video URL + SensorReading).
// Phase 10: default service is now RealVerificationService (Vision + DecisionEngine).
// Sky_App_Workflow.md §Part 2 S-VER-05; Tech Spec §8.5.

import SwiftUI

struct VerificationProcessingView: View {
    let input: VerificationInput
    var service: any VerificationService = RealVerificationService()
    var onSuccess: () -> Void
    var onFailure: (FailureReason) -> Void

    private let statusMessages = [
        "Checking your surroundings…",
        "Looking at the sky…",
        "Almost done…",
    ]

    @State private var statusIndex: Int = 0
    @State private var showSlowMessage: Bool = false

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            VStack(spacing: SkySpacing.s6) {
                Spacer()

                NimbusView(state: .fluffyWhite, size: 180)

                Text(statusMessages[statusIndex])
                    .skyText(.titleM)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: statusIndex)
                    .transition(.opacity)
                    .id(statusIndex)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(SkyColor.mossGreen)
                    .accessibilityValue("Processing")

                if showSlowMessage {
                    Text("Taking longer than usual…")
                        .skyText(.bodyS, color: SkyColor.inkMuted)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, SkyLayout.screenMargin)
        }
        .accessibilityIdentifier("verification.processing")
        .task { await runPipeline() }
        .onReceive(
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        ) { _ in
            statusIndex = (statusIndex + 1) % statusMessages.count
        }
    }

    private func runPipeline() async {
        // Trigger the slow-message warning after 10 seconds
        Task {
            try? await Task.sleep(for: .seconds(10))
            withAnimation { showSlowMessage = true }
        }

        let result = await service.analyze(input)
        // Video is deleted by service.analyze before returning
        switch result {
        case .success:           onSuccess()
        case .failure(let reason): onFailure(reason)
        }
    }
}

#Preview("S-VER-05") {
    VerificationProcessingView(
        input: VerificationInput(
            videoURL: URL(filePath: "/tmp/test.mov"),
            sensorReading: .unavailable
        ),
        onSuccess: {},
        onFailure: { _ in }
    )
}
