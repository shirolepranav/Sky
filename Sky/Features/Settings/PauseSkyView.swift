// PauseSkyView.swift
// S-SET-03 [Pro] — Friction-loaded path to remove all shields for 24 hours,
// limited to once per week. Reuses the emergency-unlock typed-confirmation
// pattern: a paste-blocked field (≥20 chars) plus a 5-second countdown gate.
// The typed reason is stored on-device only via EmergencyLogStore (kind = .pause).
// Sky_App_Workflow.md S-SET-03; Roadmap Phase 15.

import SwiftUI

struct PauseSkyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var store = SharedDefaults()
    @State private var reasonText = ""
    @State private var countdown = 5
    @State private var countdownDone = false
    @State private var shaking = false
    @State private var showRejectionToast = false
    @State private var showConfirmToast = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReady: Bool { countdownDone && reasonText.count >= 20 }
    private var counterColor: Color {
        reasonText.count >= 20 ? SkyColor.inkSoft : SkyColor.coralStreak
    }
    private var countdownLabel: String {
        countdownDone ? "Ready" : "Ready in \(countdown)…"
    }

    var body: some View {
        Group {
            if let next = store.nextPauseAvailableDate {
                alreadyPausedView(next: next)
            } else {
                confirmView
            }
        }
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Pause Sky")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pause.root")
    }

    // MARK: - Confirm (typed reason)

    private var confirmView: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    NimbusView(state: .cloudyGrey, size: 150)
                        .padding(.top, SkySpacing.s6)
                        .padding(.bottom, SkySpacing.s5)
                        .accessibilityHidden(true)

                    Text("Pause Sky for 24 hours?")
                        .skyText(.titleL)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, SkySpacing.s3)

                    Text("This removes all shields for a day. Use this when life genuinely requires it — like travel or a work emergency. Tell yourself the reason.")
                        .skyText(.body, color: SkyColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                        .padding(.bottom, SkySpacing.s6)

                    SkyCard {
                        #if canImport(UIKit)
                        PasteBlockedTextField(
                            text: $reasonText,
                            placeholder: "Why are you pausing?",
                            maxLength: 200,
                            accessibilityLabelText: "Tell us why you're pausing. Paste is disabled. Type at least 20 characters.",
                            onRejectedInsertion: { handleRejection() }
                        )
                        .frame(minHeight: 100, alignment: .topLeading)
                        #else
                        TextEditor(text: $reasonText)
                            .frame(minHeight: 100, alignment: .topLeading)
                        #endif
                    }
                    .offset(x: shaking ? 6 : 0)
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.05).repeatCount(4, autoreverses: true),
                        value: shaking
                    )
                    .padding(.horizontal, SkyLayout.screenMargin)

                    HStack {
                        Text(countdownLabel)
                            .skyText(.caption, color: SkyColor.inkSoft)
                        Spacer()
                        Text("\(reasonText.count) / 200")
                            .skyText(.caption, color: counterColor)
                    }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.top, SkySpacing.s2)

                    Spacer(minLength: SkySpacing.s8)
                }
            }

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: SkySpacing.s3) {
                    SkyCoralButton("Pause Sky") { confirmPause() }
                        .disabled(!isReady)
                        .opacity(isReady ? 1 : 0.45)
                        .accessibilityHint("Removes all shields for 24 hours")

                    SkySecondaryButton("Cancel") { dismiss() }
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
                .background(SkyColor.surface.ignoresSafeArea(edges: .bottom))
            }
        }
        .task { await runCountdown() }
        .skyToast(isPresented: $showRejectionToast, message: "Type it out, please.", icon: "xmark.circle")
        .skyToast(isPresented: $showConfirmToast, message: "Paused. See you tomorrow ☁️") { dismiss() }
    }

    // MARK: - Already paused this week

    private func alreadyPausedView(next: Date) -> some View {
        VStack(spacing: SkySpacing.s5) {
            Spacer()
            NimbusView(state: .fluffyWhite, size: 140)
                .accessibilityHidden(true)
            Text("Already paused this week")
                .skyText(.titleL)
                .multilineTextAlignment(.center)
            Text("You already paused once this week. Next pause available \(formatted(next)).")
                .skyText(.body, color: SkyColor.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SkyLayout.screenMargin)
            Spacer()
            SkySecondaryButton("Close") { dismiss() }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
        }
    }

    // MARK: - Logic

    private func confirmPause() {
        let now = Date()
        store.pauseStartedAt = now
        store.lastPauseDate = now
        store.isCurrentlyBlocked = false

        ShieldService.unlockApps()

        let cal = Calendar.current
        EmergencyLogStore.shared.add(
            EmergencyUnlockEntry(
                id: UUID(),
                date: now,
                typedReason: reasonText,
                dayOfWeek: cal.component(.weekday, from: now),
                hourOfDay: cal.component(.hour, from: now),
                kind: .pause
            )
        )

        showConfirmToast = true
    }

    private func runCountdown() async {
        for i in stride(from: 5, through: 1, by: -1) {
            countdown = i
            try? await Task.sleep(for: .seconds(1))
        }
        countdown = 0
        countdownDone = true
    }

    private func handleRejection() {
        showRejectionToast = true
        guard !reduceMotion else { return }
        shaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shaking = false }
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

#Preview("S-SET-03 — confirm") {
    NavigationStack { PauseSkyView() }
}
