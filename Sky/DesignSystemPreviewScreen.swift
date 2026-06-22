// DesignSystemPreviewScreen.swift
// Visual QA surface for the whole design system — palette, Nimbus states, type,
// and components on one scrollable screen (Roadmap Phase 1). Faithful SwiftUI
// translation of the prototype's FoundationsCard (screens-foundations.jsx).
// In the shipped app this lives behind the debug menu.

import SwiftUI

struct DesignSystemPreviewScreen: View {
    private let palette: [(String, Color, String)] = [
        ("Primary sky", SkyColor.primarySky, "Hero, calm backgrounds"),
        ("Warm cream", SkyColor.warmCream, "Surfaces, shield"),
        ("Moss green", SkyColor.mossGreen, "Tints · nav active · success"),
        ("Coral streak", SkyColor.coralStreak, "Streak, alerts"),
        ("Cloud grey", SkyColor.cloudGrey, "Indoor Nimbus, paused"),
        ("Sun yellow", SkyColor.sunYellow, "Verified, milestones"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkySpacing.s8) {
                header
                section("Palette") { paletteGrid }
                section("Nimbus — the 5 states") { nimbusStates }
                section("Type · SF Rounded") { typeCard }
                section("Components") { componentsCard }
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, SkySpacing.s10)
        }
        .background(SkyColor.surface)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: SkySpacing.s4) {
            NimbusView(state: .fluffyWhite, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("Sky · design foundations").skyText(.titleXL)
                Text(AppBranding.appNameTagline)
                    .skyText(.bodyS, color: SkyColor.inkSoft)
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SkySpacing.s4) {
            Text(title.uppercased()).skyText(.overline, color: SkyColor.inkMuted)
            content()
        }
    }

    private var paletteGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SkySpacing.s4), count: 3),
                  spacing: SkySpacing.s4) {
            ForEach(palette, id: \.0) { name, color, hint in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
                        .fill(color)
                        .frame(height: 88)
                        .overlay(RoundedRectangle(cornerRadius: SkyRadius.chip).strokeBorder(.black.opacity(0.04)))
                    Text(name).skyText(.caption, color: SkyColor.ink)
                    Text(hint).skyText(.caption, color: SkyColor.inkSoft)
                }
            }
        }
    }

    private var nimbusStates: some View {
        SkyCard(secondary: true, padding: SkySpacing.s6) {
            HStack(alignment: .top, spacing: SkySpacing.s3) {
                ForEach(MascotState.allCases, id: \.self) { state in
                    VStack(spacing: SkySpacing.s2) {
                        NimbusView(state: state, size: 64)
                            .frame(height: 72)
                        Text(state.displayName).skyText(.caption, color: SkyColor.ink)
                        Text(state.hint)
                            .skyText(.caption, color: SkyColor.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var typeCard: some View {
        SkyCard(secondary: true, padding: SkySpacing.s6) {
            VStack(alignment: .leading, spacing: SkySpacing.s2) {
                Text("Time's up.").skyText(.display)
                Text("Title · 22 / 800").skyText(.titleM).padding(.top, 4)
                Text("Body · 17 / 500 · Nimbus is waiting outside for you.")
                    .skyText(.body)
                Text("CAPTION · 13 / 600").skyText(.caption, color: SkyColor.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var componentsCard: some View {
        SkyCard(secondary: true, padding: SkySpacing.s6) {
            VStack(spacing: SkySpacing.s4) {
                HStack(spacing: SkySpacing.s4) {
                    SkyPrimaryButton("Verify now") {}
                    SkySecondaryButton("I can't go outside") {}
                }
                HStack(spacing: SkySpacing.s4) {
                    SkyCoralButton("Unlock anyway") {}
                    SkyStreakChip(days: 12)
                        .frame(maxWidth: .infinity)
                }
                HStack(alignment: .top, spacing: SkySpacing.s2) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SkyColor.mossGreenAction)
                        .frame(width: 16, height: 16)
                    Text("Primary button fill is #52822A — a deeper moss than the #7CB342 tint so the white label clears WCAG AA (4.6:1).")
                        .skyText(.caption, color: SkyColor.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        Text("Calm, cute, soft. Never pure white or pure black. Mascot front and center across the app. Subtle motion only — Nimbus has a 2-second idle bob and 0.5s transitions between states.")
            .skyText(.caption, color: SkyColor.inkMuted)
    }
}

#Preview("Design system") {
    DesignSystemPreviewScreen()
}

#Preview("Design system · dark") {
    DesignSystemPreviewScreen()
        .preferredColorScheme(.dark)
}
