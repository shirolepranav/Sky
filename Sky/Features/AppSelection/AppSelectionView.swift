// AppSelectionView.swift
// S-CFG-01 · App Selection Root (Sky_App_Workflow.md §S-CFG-01) and its embedded
// S-CFG-02 FamilyActivityPicker sheet.
//
// Entry point to picking which apps to limit. Presents Apple's opaque picker;
// Sky shows only a count + token icons (never names). Persists the selection to
// the App Group on dismiss.

import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @ObservedObject var viewModel: AppSelectionViewModel
    /// Invoked when the user taps "Continue" with a valid selection.
    let onContinue: () -> Void

    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: SkySpacing.s8) {
            Spacer(minLength: SkySpacing.s6)

            Text("Which apps do you want to limit?")
                .skyText(.titleXL)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("appSelection.title")

            summaryCard

            Spacer(minLength: SkySpacing.s6)

            VStack(spacing: SkySpacing.s3) {
                SkyPrimaryButton(viewModel.isEmpty ? "Choose apps" : "Edit selection") {
                    isPickerPresented = true
                }
                .accessibilityIdentifier("appSelection.choose")

                Button("Continue", action: onContinue)
                    .buttonStyle(SkyPrimaryButtonStyle())
                    .disabled(!viewModel.canContinue)
                    .accessibilityIdentifier("appSelection.continue")
            }
        }
        .padding(.horizontal, SkyLayout.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SkyColor.surface.ignoresSafeArea())
        .accessibilityIdentifier("appSelection.root")
        // S-CFG-02 · Apple-owned picker. Persist on dismiss.
        .sheet(isPresented: $isPickerPresented, onDismiss: viewModel.persistSelection) {
            FamilyActivityPicker(selection: $viewModel.selection)
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        SkyCard {
            VStack(spacing: SkySpacing.s4) {
                if viewModel.needsRedo {
                    Label {
                        Text("Your app selection needs to be redone after an iOS update.")
                            .skyText(.body, color: SkyColor.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(SkyColor.coralStreak)
                    }
                } else if viewModel.isEmpty {
                    Text("No apps selected yet.")
                        .skyText(.body, color: SkyColor.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("\(viewModel.count) apps selected")
                        .skyText(.titleM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityValue("\(viewModel.count) apps")
                    selectedTokens
                }
            }
        }
        .accessibilityIdentifier("appSelection.summary")
    }

    /// Token icons for the current selection (no names — Sky can't see them).
    @ViewBuilder
    private var selectedTokens: some View {
        let appTokens = Array(viewModel.selection.applicationTokens)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SkySpacing.s3) {
                ForEach(appTokens, id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 28))
                }
            }
        }
    }
}

#Preview("S-CFG-01 App Selection (empty)") {
    AppSelectionView(viewModel: AppSelectionViewModel(), onContinue: {})
}
