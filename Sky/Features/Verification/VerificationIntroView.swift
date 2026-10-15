// VerificationIntroView.swift
// S-VER-01 — Briefs the user before recording begins, with a live step count
// toward the walk the step check needs (DAILY_LOCK_PLAN.md Phase E).
// Sky_App_Workflow.md §Part 2 S-VER-01.

import CoreMotion
import SwiftUI

/// Live steps over the last `stepWindowSeconds`, for display only — the decision
/// re-queries the pedometer when recording ends.
@MainActor
private final class RecentStepsModel: ObservableObject {
    @Published var steps: Int?
    private let pedometer = CMPedometer()

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let from = Date().addingTimeInterval(-VerificationThresholds.stepWindowSeconds)
        pedometer.startUpdates(from: from) { [weak self] data, _ in
            let count = data?.numberOfSteps.intValue
            Task { @MainActor in self?.steps = count }
        }
    }

    func stop() { pedometer.stopUpdates() }
}

struct VerificationIntroView: View {
    var onPrimary: () -> Void
    var onClose: () -> Void

    private struct BulletItem {
        let icon: String
        let text: String
    }

    @StateObject private var recent = RecentStepsModel()

    private let bullets: [BulletItem] = [
        BulletItem(icon: "figure.walk",
                   text: "Take a short walk outside — about \(VerificationThresholds.minRecentSteps) steps."),
        BulletItem(icon: "sun.max",
                   text: "Then film \(VerificationThresholds.clipSeconds) seconds, from the ground up to the sky."),
        BulletItem(icon: "lock",
                   text: "Everything stays on your phone."),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            SkyColor.surface.ignoresSafeArea()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SkyColor.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, SkySpacing.s5)
            .padding(.leading, SkySpacing.s4)
            .accessibilityLabel("Close")

            // Main content
            VStack(spacing: 0) {
                Spacer(minLength: SkySpacing.s10)

                NimbusView(state: .fluffyWhite, size: 200)
                    .padding(.bottom, SkySpacing.s6)

                Text("Ready to head outside?")
                    .skyText(.titleL)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)

                VStack(alignment: .leading, spacing: SkySpacing.s4) {
                    ForEach(bullets, id: \.icon) { bullet in
                        HStack(alignment: .top, spacing: SkySpacing.s3) {
                            Image(systemName: bullet.icon)
                                .font(.system(size: 17))
                                .foregroundColor(SkyColor.mossGreen)
                                .frame(width: 24)
                            Text(bullet.text)
                                .skyText(.body, color: SkyColor.inkSoft)
                        }
                    }
                }
                .padding(.horizontal, SkyLayout.screenMargin)

                if let steps = recent.steps {
                    let goal = VerificationThresholds.minRecentSteps
                    Text(steps >= goal ? "\(steps) steps — you're ready ☀" : "\(steps) of \(goal) steps")
                        .skyText(.headline, color: steps >= goal ? SkyColor.mossGreen : SkyColor.inkSoft)
                        .monospacedDigit()
                        .padding(.top, SkySpacing.s5)
                        .accessibilityIdentifier("verification.intro.steps")
                }

                Spacer()

                SkyPrimaryButton("I'm outside", action: onPrimary)
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.intro")
        .onAppear { recent.start() }
        .onDisappear { recent.stop() }
    }
}

#Preview("S-VER-01") {
    VerificationIntroView(onPrimary: {}, onClose: {})
}

#Preview("S-VER-01 dark") {
    VerificationIntroView(onPrimary: {}, onClose: {})
        .preferredColorScheme(.dark)
}
