// Buttons.swift
// Sky button styles — DESIGN_SYSTEM.md §7.
//
// The signature "pressable" look is a *solid offset* shadow (no blur): a hard
// shadow 2px below the button. On press the button translates down 2px and the
// shadow disappears, so it looks like it sinks into its own shadow.
//
// Use the convenience wrappers (SkyPrimaryButton, SkySecondaryButton,
// SkyCoralButton) or apply the ButtonStyle directly to any Button.

import SwiftUI

// MARK: - Primary (mossGreenAction, white label)

struct SkyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Content(configuration: configuration) }

    struct Content: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let lifted = isEnabled && !configuration.isPressed
            configuration.label
                .skyText(.headline, color: .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, SkySpacing.s6)
                .background(
                    isEnabled ? SkyColor.mossGreenAction : SkyColor.inkDisabled,
                    in: RoundedRectangle(cornerRadius: SkyRadius.button, style: .continuous)
                )
                .offset(y: configuration.isPressed ? 2 : 0)
                .shadow(color: lifted ? SkyColor.mossGreenActionDeep : .clear,
                        radius: 0, x: 0, y: lifted ? 2 : 0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

// MARK: - Secondary (transparent, bordered)

struct SkySecondaryButtonStyle: ButtonStyle {
    var dark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .tracking(-0.2)
            .foregroundStyle(dark ? SkyColor.darkInk : SkyColor.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SkySpacing.s4)
            .padding(.horizontal, SkySpacing.s6)
            .background(.clear, in: RoundedRectangle(cornerRadius: SkyRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SkyRadius.button, style: .continuous)
                    .strokeBorder(dark ? SkyColor.darkDivider : SkyColor.ink.opacity(0.12), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Coral (destructive / "unlock anyway")

struct SkyCoralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .skyText(.headline, color: .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, SkySpacing.s6)
            .background(SkyColor.coralStreak, in: RoundedRectangle(cornerRadius: SkyRadius.button, style: .continuous))
            .offset(y: configuration.isPressed ? 2 : 0)
            .shadow(color: configuration.isPressed ? .clear : SkyColor.coralStreakDeep,
                    radius: 0, x: 0, y: configuration.isPressed ? 0 : 2)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Convenience wrappers

struct SkyPrimaryButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    var body: some View {
        Button(title, action: action).buttonStyle(SkyPrimaryButtonStyle())
    }
}

struct SkySecondaryButton: View {
    let title: String
    var dark = false
    let action: () -> Void
    init(_ title: String, dark: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.dark = dark
        self.action = action
    }
    var body: some View {
        Button(title, action: action).buttonStyle(SkySecondaryButtonStyle(dark: dark))
    }
}

struct SkyCoralButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    var body: some View {
        Button(title, action: action).buttonStyle(SkyCoralButtonStyle())
    }
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        SkyPrimaryButton("Verify now") {}
        Button("Disabled") {}.buttonStyle(SkyPrimaryButtonStyle()).disabled(true)
        SkySecondaryButton("I can't go outside") {}
        SkyCoralButton("Unlock anyway") {}
    }
    .padding(24)
    .background(SkyColor.surface)
}
