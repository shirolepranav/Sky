// PickAppsPage.swift
// Onboarding 2: Pick Apps Preview — Sky_App_Workflow.md §S-ONB-03.
// Illustrative only — does not trigger the Family Controls picker (Phase 3).
// Shows a stylized phone with three GENERIC colored tiles; Sky never names real
// apps (privacy invariant + the screen's own copy).

import SwiftUI

struct PickAppsPage: View {
    var body: some View {
        OnboardingScaffold(page: .pickApps) {
            SkyCard {
                StylizedPhone {
                    // Three generic app tiles — token colors, never real apps.
                    HStack(spacing: SkySpacing.s3) {
                        appTile(SkyColor.primarySky)
                        appTile(SkyColor.sunYellow)
                        appTile(SkyColor.coralStreak)
                    }
                }
            }
            .frame(maxWidth: 260)
        }
    }

    private func appTile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
            .fill(color)
            .frame(width: 44, height: 44)
    }
}

/// A small stylized phone frame used in onboarding illustrations.
struct StylizedPhone<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: SkyRadius.cardSecondary, style: .continuous)
            .fill(SkyColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: SkyRadius.cardSecondary, style: .continuous)
                    .strokeBorder(SkyColor.divider, lineWidth: 1.5)
            )
            .frame(width: 132, height: 160)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(SkyColor.cloudGrey)
                    .frame(width: 34, height: 5)
                    .padding(.top, SkySpacing.s3)
            }
            .overlay { content() }
    }
}

#Preview("S-ONB-03 Pick Apps") {
    PickAppsPage()
        .background(SkyColor.warmCream)
}
