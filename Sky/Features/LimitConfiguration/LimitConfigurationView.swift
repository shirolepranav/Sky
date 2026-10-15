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
//
// Sky Pop (Sky Pop canvas board "LockTimePlus"): the chosen time is the loud
// moment — a popSun block with the time in the display face — then six
// common morning times as outlined chips (the selected one pushed in), an
// "Other time" menu for the full range, Pop lock-day chips, and a Pop
// "Lock at <time>" button.

import SwiftUI

struct LimitConfigurationView: View {
    @ObservedObject var viewModel: LimitConfigurationViewModel
    let onSave: () -> Void

    @EnvironmentObject private var storeKit: StoreKitService

    @State private var showToast = false
    @State private var showPaywall = false

    /// Quick picks shown as chips — the usual just-woke-up times. Only ones the
    /// view model allows are shown; every other time is in the "Other time" menu.
    private static let quickPicks = [6 * 60 + 30, 7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30, 9 * 60]
        .filter { LimitConfigurationViewModel.lockTimeOptions.contains($0) }

    private var timeLabel: String { SharedDefaults.lockTimeLabel(minutes: viewModel.lockTimeMinutes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkySpacing.s6) {
                Spacer(minLength: SkySpacing.s6)

                VStack(alignment: .leading, spacing: SkySpacing.s2) {
                    Text("When should your apps nap?")
                        .skyText(.titleXL)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("limitConfig.title")

                    Text("Each day at this time your selected apps pause. A short walk outside unlocks them until the next day.")
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // The loud moment: the chosen time on a sun block (info, not tappable).
                VStack(spacing: SkySpacing.s1) {
                    Text(timeLabel)
                        .skyText(.numeralXL, color: SkyColor.inkOnAccent)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("every morning")
                        .skyText(.headline, color: SkyColor.inkOnAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(SkySpacing.s6)
                .background(SkyColor.popSun, in: RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Lock time \(timeLabel), every morning")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SkySpacing.s3), count: 3),
                          spacing: SkySpacing.s3) {
                    ForEach(Self.quickPicks, id: \.self) { minutes in
                        Button(SharedDefaults.lockTimeLabel(minutes: minutes)) {
                            viewModel.lockTimeMinutes = minutes
                        }
                        .buttonStyle(SkyChipButtonStyle(isSelected: viewModel.lockTimeMinutes == minutes))
                    }
                }
                .accessibilityIdentifier("limitConfig.quickPicks")

                // Full range (every 30 min) for anyone outside the usual mornings.
                Picker(selection: $viewModel.lockTimeMinutes) {
                    ForEach(LimitConfigurationViewModel.lockTimeOptions, id: \.self) { minutes in
                        Text(SharedDefaults.lockTimeLabel(minutes: minutes)).tag(minutes)
                    }
                } label: {
                    Text("Other time")
                }
                .pickerStyle(.menu)
                .tint(SkyColor.mossGreenDeep)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("limitConfig.timePicker")

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

                SkyPopButton("Lock at \(timeLabel)") {
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

// One weekday toggle: a Pop chip, pushed in when the day is on. The chip
// style is already 44pt tall and reports `.isSelected` to VoiceOver.
private struct DayChip: View {
    let label: String
    let accessibilityName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .skyText(.headline, color: isSelected ? SkyColor.surface : SkyColor.ink)
        }
        // Seven across, so the compact (narrow-padding) chip.
        .buttonStyle(SkyChipButtonStyle(isSelected: isSelected, compact: true))
        .accessibilityLabel(accessibilityName)
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
