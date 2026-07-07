// EmergencyUnlockTypedReasonView.swift
// S-EMG-02 — Friction-loaded typed-reason screen. The user must type ≥ 20
// characters in a paste-blocked field AND wait 5 seconds before the "Unlock
// anyway" button becomes active. Paste attempts shake the field and show a
// toast. Newlines and any single insertion > 5 chars are silently rejected.
// Sky_App_Workflow.md S-EMG-02; Roadmap Phase 13.

import SwiftUI

struct EmergencyUnlockTypedReasonView: View {
    /// Called with the typed reason string when the user confirms.
    var onUnlock: (String) -> Void
    var onCancel: () -> Void

    @State private var reasonText: String = ""
    @State private var countdown: Int = 5
    @State private var countdownDone = false
    @State private var shaking = false
    @State private var showRejectionToast = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReady: Bool { countdownDone && reasonText.count >= 20 }

    private var counterColor: Color {
        reasonText.count >= 20 ? SkyColor.inkSoft : SkyColor.coralStreak
    }

    private var countdownLabel: String {
        countdownDone ? "Ready" : "Ready in \(countdown)…"
    }

    var body: some View {
        ZStack {
            SkyColor.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    NimbusView(state: .rainy, size: 160)
                        .padding(.top, SkySpacing.s8)
                        .padding(.bottom, SkySpacing.s6)
                        .accessibilityHidden(true)

                    Text("Tell yourself why.")
                        .skyText(.titleL)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, SkySpacing.s3)

                    Text("Type at least a sentence. Paste is off — this needs to come from you.")
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                        .padding(.bottom, SkySpacing.s6)

                    // Paste-blocked text field
                    SkyCard {
                        #if canImport(UIKit)
                        PasteBlockedTextField(
                            text: $reasonText,
                            placeholder: "I need to unlock because…",
                            maxLength: 200,
                            onRejectedInsertion: { handleRejection() }
                        )
                        .frame(minHeight: 100, alignment: .topLeading)
                        #else
                        TextEditor(text: $reasonText)
                            .frame(minHeight: 100, alignment: .topLeading)
                        #endif
                    }
                    .offset(x: shaking ? 6 : 0)
                    .animation(reduceMotion ? nil : SkyMotion.shake, value: shaking)
                    .padding(.horizontal, SkyLayout.screenMargin)

                    // Character counter + countdown row
                    HStack {
                        Text(countdownLabel)
                            .skyText(.caption, color: SkyColor.inkSoft)
                            .accessibilityLabel(countdownDone ? "Ready to unlock" : "Ready in \(countdown) seconds")

                        Spacer()

                        Text("\(reasonText.count) / 200")
                            .skyText(.caption, color: counterColor)
                            .accessibilityLabel("\(reasonText.count) of 200 characters. \(reasonText.count < 20 ? "Need \(20 - reasonText.count) more." : "Minimum met.")")
                    }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.top, SkySpacing.s2)

                    Spacer(minLength: SkySpacing.s8)
                }
            }

            // Buttons pinned to bottom
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: SkySpacing.s3) {
                    SkyCoralButton("Unlock anyway") { onUnlock(reasonText) }
                        .disabled(!isReady)
                        .opacity(isReady ? 1 : 0.45)
                        .accessibilityHint("Resets your streak and unlocks apps")
                        .accessibilityValue(isReady ? "Available" : "Not available yet")

                    SkySecondaryButton("Cancel", action: onCancel)
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
                .background(
                    SkyColor.surface
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .accessibilityIdentifier("emergency.typedReason")
        .task { await runCountdown() }
        .skyToast(
            isPresented: $showRejectionToast,
            message: "Type it out, please.",
            icon: "xmark.circle"
        )
    }

    // MARK: - Countdown

    private func runCountdown() async {
        for i in stride(from: 5, through: 1, by: -1) {
            countdown = i
            try? await Task.sleep(for: .seconds(1))
        }
        countdown = 0
        countdownDone = true
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: "Ready")
        #endif
    }

    // MARK: - Rejection feedback

    private func handleRejection() {
        showRejectionToast = true
        guard !reduceMotion else { return }
        shaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shaking = false
        }
    }
}

#Preview("S-EMG-02 — initial") {
    EmergencyUnlockTypedReasonView(onUnlock: { _ in }, onCancel: {})
}

#Preview("S-EMG-02 — dark") {
    EmergencyUnlockTypedReasonView(onUnlock: { _ in }, onCancel: {})
        .preferredColorScheme(.dark)
}
