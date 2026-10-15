// LimitConfigurationView.swift
// S-CFG-03 · Lock time (Sky_App_Workflow.md §S-CFG-03; DAILY_LOCK_PLAN.md Phase D).
//
// Every day at the chosen time the selected apps pause, and stay paused until the
// user takes a short walk outside. Lock days (weekends off, etc.) are Pro —
// S-PAY-05 appears on a free user's tap.
//
//   S-CFG-06 · SkyToast — "Saved." confirmation
//
// Entry points: SetupFlowView (first-run), S-SET-02 (Settings), Today's no-limit state.
// Exit: onSave() is called after the toast finishes dismissing.

import SwiftUI

struct LimitConfigurationView: View {
    @ObservedObject var viewModel: LimitConfigurationViewModel
    let onSave: () -> Void

    @EnvironmentObject private var storeKit: StoreKitService

    @State private var showToast = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkySpacing.s6) {
                Spacer(minLength: SkySpacing.s6)

                Text("When should your apps pause?")
                    .skyText(.titleXL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("limitConfig.title")

                Text("Each day at this time your selected apps pause. A short walk outside unlocks them until the next day.")
                    .skyText(.body, color: SkyColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                SkyCard {
                    Picker("Lock time", selection: $viewModel.lockTimeMinutes) {
                        ForEach(LimitConfigurationViewModel.lockTimeOptions, id: \.self) { minutes in
                            Text(SharedDefaults.lockTimeLabel(minutes: minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .accessibilityIdentifier("limitConfig.timePicker")
                }

                VStack(alignment: .leading, spacing: SkySpacing.s3) {
                    HStack {
                        Text("Lock days").skyText(.label, color: SkyColor.inkSoft)
                        if !storeKit.isPro {
                            Label("Pro", systemImage: "lock.fill")
                                .labelStyle(.titleAndIcon)
                                .skyText(.caption, color: SkyColor.inkMuted)
                        }
                    }
                    HStack(spacing: SkySpacing.s2) {
                        ForEach(LimitConfigurationViewModel.orderedWeekdays, id: \.self) { weekday in
                            DayChip(
                                label: Calendar.current.veryShortWeekdaySymbols[weekday - 1],
                                accessibilityName: Calendar.current.weekdaySymbols[weekday - 1],
                                isSelected: viewModel.lockWeekdays.contains(weekday)
                            ) {
                                viewModel.toggleWeekday(weekday, isPro: storeKit.isPro)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("limitConfig.days")

                Text("If the new time has already passed today, your apps pause now.")
                    .skyText(.caption, color: SkyColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("limitConfig.resetCaption")

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
        .skyToast(isPresented: $showToast, message: "Saved. Nimbus will see you outside ☁", onComplete: onSave)
        // S-PAY-05 · Lock days Pro gate
        .sheet(isPresented: $viewModel.showsLockDaysProGate) {
            InContextProGateView(
                featureTitle: "Choosing lock days is a Pro feature.",
                onSeePro: {
                    viewModel.showsLockDaysProGate = false
                    showPaywall = true
                },
                onDismiss: { viewModel.showsLockDaysProGate = false }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environmentObject(storeKit)
        }
        .accessibilityIdentifier("limitConfig.root")
    }
}

// One weekday toggle. 44 pt minimum, selected = primarySky fill.
private struct DayChip: View {
    let label: String
    let accessibilityName: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric private var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Text(label)
                .skyText(.headline, color: isSelected ? SkyColor.inkOnAccent : SkyColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: size)
                .background(
                    RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
                        .fill(isSelected ? SkyColor.primarySky : SkyColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : SkyColor.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: – Previews

#Preview("S-CFG-03 Lock time") {
    LimitConfigurationView(viewModel: LimitConfigurationViewModel(), onSave: {})
        .environmentObject(StoreKitService())
}

#Preview("S-CFG-03 Lock time · dark") {
    LimitConfigurationView(viewModel: LimitConfigurationViewModel(), onSave: {})
        .environmentObject(StoreKitService())
        .preferredColorScheme(.dark)
}
