// LimitConfigurationView.swift
// S-CFG-03 · Daily Limit Configuration (Sky_App_Workflow.md §S-CFG-03).
//
// Hosts the combined/per-app mode toggle with embedded pickers:
//   S-CFG-04 · CombinedLimitContent — three hour-chips, tap to select
//   S-CFG-05 · PerAppLimitsContent  — per-token steppers (Pro; TODO Phase 14 gate)
//   S-CFG-06 · SkyToast             — "Saved. Sky's watching." confirmation
//
// Entry points: SetupFlowView (first-run) and S-SET-02 (Settings, Phase 15).
// Exit: onSave() is called after the toast finishes dismissing.

import SwiftUI
import FamilyControls
import ManagedSettings

struct LimitConfigurationView: View {
    @ObservedObject var viewModel: LimitConfigurationViewModel
    let onSave: () -> Void

    @State private var showToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkySpacing.s6) {
                Spacer(minLength: SkySpacing.s6)

                Text("Daily limit")
                    .skyText(.titleXL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("limitConfig.title")

                // S-CFG-03 · Mode toggle
                // TODO(Phase 14): gate per-app segment for free users → S-PAY-05
                Picker("Limit mode", selection: $viewModel.limitMode) {
                    Text("Combined").tag(LimitConfigurationViewModel.LimitMode.combined)
                    Text("Per app").tag(LimitConfigurationViewModel.LimitMode.perApp)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("limitConfig.modePicker")

                // Embedded content swaps with a 0.2 s cross-dissolve (S-CFG-03 spec).
                SkyCard {
                    Group {
                        if viewModel.limitMode == .combined {
                            CombinedLimitContent(seconds: $viewModel.combinedLimitSeconds)
                        } else {
                            PerAppLimitsContent(viewModel: viewModel)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.limitMode)
                }

                Text("Limits reset at midnight, your local time.")
                    .skyText(.caption, color: SkyColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("limitConfig.resetCaption")

                Spacer(minLength: SkySpacing.s6)

                SkyPrimaryButton("Save") {
                    viewModel.save()
                    showToast = true
                }
                .accessibilityIdentifier("limitConfig.save")

                Spacer(minLength: SkyLayout.bottomSafeArea)
            }
            .padding(.horizontal, SkyLayout.screenMargin)
        }
        .background(SkyColor.surface.ignoresSafeArea())
        // S-CFG-06 · Confirmation toast; onSave fires after dismissal
        .skyToast(isPresented: $showToast, message: "Saved. Sky's watching.", onComplete: onSave)
        .accessibilityIdentifier("limitConfig.root")
    }
}

// MARK: – S-CFG-04 · Combined Limit (1 h / 2 h / 3 h chips)

private struct CombinedLimitContent: View {
    @Binding var seconds: Int

    private let options: [(label: String, value: Int)] = [
        ("1 h", 3600),
        ("2 h", 7200),
        ("3 h", 10800),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SkySpacing.s4) {
            Text("How long across all selected apps each day?")
                .skyText(.bodyS, color: SkyColor.inkSoft)

            // Accessibility: underlying Picker drives VoiceOver ("One hour" etc.)
            HStack(spacing: SkySpacing.s3) {
                ForEach(options, id: \.value) { option in
                    HourChip(
                        label: option.label,
                        isSelected: seconds == option.value
                    ) {
                        withAnimation(.spring(response: 0.2)) {
                            seconds = option.value
                        }
                    }
                }
            }
            // Invisible Picker so VoiceOver users can navigate by value.
            Picker("Daily limit", selection: $seconds) {
                Text("One hour").tag(3600)
                Text("Two hours").tag(7200)
                Text("Three hours").tag(10800)
            }
            .pickerStyle(.inline)
            .frame(height: 0)
            .accessibilityHidden(false)
            .opacity(0)
        }
    }
}

// Single selectable chip for the combined-limit row.
private struct HourChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric private var chipHeight: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Text(label)
                .skyText(.headline, color: isSelected ? SkyColor.ink : SkyColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: chipHeight)
                .background(
                    RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
                        .fill(isSelected ? SkyColor.primarySky : SkyColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.clear : SkyColor.divider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(label)
    }
}

// MARK: – S-CFG-05 · Per-App Limits [Pro]

private struct PerAppLimitsContent: View {
    @ObservedObject var viewModel: LimitConfigurationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SkySpacing.s4) {
            Text("How long for each app?")
                .skyText(.label, color: SkyColor.inkSoft)

            if viewModel.appTokens.isEmpty {
                Text("No apps selected.")
                    .skyText(.body, color: SkyColor.inkSoft)
            } else {
                LazyVStack(spacing: SkySpacing.s3) {
                    ForEach(viewModel.appTokens, id: \.self) { token in
                        PerAppRow(
                            token: token,
                            minutesBinding: viewModel.minutesBinding(for: token)
                        )
                    }
                }
            }
        }
    }
}

private struct PerAppRow: View {
    let token: ApplicationToken
    @Binding var minutes: Int

    init(token: ApplicationToken, minutesBinding: Binding<Int>) {
        self.token = token
        self._minutes = minutesBinding
    }

    var body: some View {
        HStack(spacing: SkySpacing.s3) {
            Label(token)
                .labelStyle(.iconOnly)
                .font(.system(size: 28))
                .accessibilityHidden(true)

            Spacer()

            Text(minuteLabel)
                .skyText(.body)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
                .accessibilityHidden(true)

            Stepper("", value: $minutes, in: 15...240, step: 15)
                .labelsHidden()
                .accessibilityLabel("Daily limit, \(minuteLabel)")
                .accessibilityValue(minuteLabel)
        }
        .frame(minHeight: SkyLayout.minTouchTarget)
    }

    private var minuteLabel: String {
        guard minutes >= 60 else { return "\(minutes) m" }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h) h \(m) m" : "\(h) h"
    }
}

// MARK: – Previews

#Preview("S-CFG-03 Combined (default)") {
    LimitConfigurationView(
        viewModel: LimitConfigurationViewModel(),
        onSave: {}
    )
}

#Preview("S-CFG-03 Per-app (empty selection)") {
    let vm = LimitConfigurationViewModel()
    vm.limitMode = .perApp
    return LimitConfigurationView(viewModel: vm, onSave: {})
}
