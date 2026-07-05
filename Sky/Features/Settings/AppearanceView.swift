// AppearanceView.swift
// S-SET-10 — Appearance picker. Three selectable rows (System / Light / Dark)
// that write AppearanceManager.mode, which SkyApp applies app-wide via
// .preferredColorScheme. The adaptive SkyColor tokens recolor everything.
// Sky_App_Workflow.md S-SET-10; Roadmap Phase 16.

import SwiftUI

struct AppearanceView: View {
    @EnvironmentObject private var appearance: AppearanceManager

    var body: some View {
        List {
            Section {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearance.mode = mode
                    } label: {
                        row(for: mode)
                    }
                    .accessibilityIdentifier("appearance.row.\(mode.rawValue)")
                }
            } footer: {
                Text("Choose how Sky looks. “System” follows your device’s light or dark setting automatically.")
                    .skyText(.caption, color: SkyColor.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("appearance.root")
    }

    private func row(for mode: AppearanceMode) -> some View {
        let isSelected = appearance.mode == mode
        return HStack(spacing: SkySpacing.s4) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 20))
                .foregroundStyle(SkyColor.mossGreenDeep)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title).skyText(.body, color: SkyColor.ink)
                Text(mode.subtitle).skyText(.caption, color: SkyColor.inkSoft)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SkyColor.mossGreen)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title). \(mode.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("S-SET-10 — Light") {
    NavigationStack { AppearanceView() }
        .environmentObject(AppearanceManager())
}

#Preview("S-SET-10 — Dark") {
    NavigationStack { AppearanceView() }
        .environmentObject(AppearanceManager())
        .preferredColorScheme(.dark)
}
