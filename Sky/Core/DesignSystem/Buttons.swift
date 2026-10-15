// Buttons.swift
// Sky button styles — DESIGN_SYSTEM.md §7.
//
// The signature "pressable" look is a *solid offset* shadow (no blur): a hard
// shadow 2px below the button. On press the button translates down 2px and the
// shadow disappears, so it looks like it sinks into its own shadow.
//
// Use the convenience wrappers (SkyPrimaryButton, SkySecondaryButton,
// SkyCoralButton) or apply the ButtonStyle directly to any Button.
//
// Sky Pop (DESIGN_SYSTEM.md §1, §6 "Tappable outline", §7): SkyPopButtonStyle /
// SkyPopButton and SkyChipButtonStyle add a 2.5–3pt ink outline plus a hard
// ink offset shadow (0×5 buttons, 3×3 chips). Screens move to these as they
// are restyled; the classic styles above stay until every caller has moved.

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
                .animation(SkyMotion.pressEase, value: configuration.isPressed)
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
            .animation(SkyMotion.pressEase, value: configuration.isPressed)
    }
}

// MARK: - Sky Pop: shared outline + hard shadow (DESIGN_SYSTEM.md §6, §7)
//
// "Ink outline + hard offset shadow = tappable." Every Pop control draws:
//   1. its fill, 2. an ink outline on top, 3. a solid ink copy of its shape
//   behind it, shifted by `shadow` (radius 0, no blur).
// When `sunk` (pressed, or a selected chip) the control slides by `shadow`
// so it sits exactly on top of its shadow — it looks pushed in.

extension View {
    /// Apply the Sky Pop outlined look to any content.
    /// - Parameters:
    ///   - shape: the control's outline shape (rounded rect, capsule…).
    ///   - fill: background fill.
    ///   - outline: ink outline + shadow colour (`SkyColor.outline` or `.outlineOnAccent`).
    ///   - lineWidth: `SkyStroke.outline` (chips) or `.outlineHeavy` (buttons).
    ///   - shadow: `SkyPopShadow.button` or `.chip`; `.zero` for a flat sticker.
    ///   - sunk: true while pressed / selected — slides into the shadow.
    func skyPopSurface<S: InsettableShape>(
        _ shape: S,
        fill: Color,
        outline: Color = SkyColor.outline,
        lineWidth: CGFloat = SkyStroke.outline,
        shadow: CGSize = SkyPopShadow.chip,
        sunk: Bool = false
    ) -> some View {
        self
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(outline, lineWidth: lineWidth))
            // The hard shadow: a solid copy of the shape, offset behind.
            .background(shape.fill(outline).offset(sunk ? .zero : shadow))
            // Pressed: move the whole control onto its shadow.
            .offset(sunk ? shadow : .zero)
    }
}

/// Colour pairs for Pop buttons. Each pairing clears WCAG AA for its label.
enum SkyPopButtonKind {
    case primary // mossGreenAction + white label (4.6:1) — the main action
    case cream   // warmCream + ink label — secondary action ("Share sky")
    case ink     // ink + surface label — strong neutral (shield-style "Open Sky")
    case coral   // popCoral + ink label (4.7:1) — friction / "unlock anyway"

    var fill: Color {
        switch self {
        case .primary: return SkyColor.mossGreenAction
        case .cream: return SkyColor.warmCream
        case .ink: return SkyColor.ink
        case .coral: return SkyColor.popCoral
        }
    }

    var label: Color {
        switch self {
        case .primary: return .white // button labels may be pure white (CLAUDE.md rule 2)
        case .cream: return SkyColor.ink
        case .ink: return SkyColor.surface
        case .coral: return SkyColor.inkOnAccent // popCoral stays bright in dark mode
        }
    }
}

// MARK: - Sky Pop button (full-width, 3pt outline, 0×5 shadow)

struct SkyPopButtonStyle: ButtonStyle {
    var kind: SkyPopButtonKind = .primary
    /// True when the button sits on a bright Pop ground (popSky / popSun) — the
    /// outline then stays ink in dark mode instead of flipping light.
    var onAccent = false
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, kind: kind, onAccent: onAccent, fullWidth: fullWidth)
    }

    struct Content: View {
        let configuration: Configuration
        let kind: SkyPopButtonKind
        let onAccent: Bool
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SkyRadius.button, style: .continuous)
            // Disabled controls aren't tappable, so they lose the shadow (the
            // "tappable" cue) and use the muted outline.
            let outline = isEnabled
                ? (onAccent ? SkyColor.outlineOnAccent : SkyColor.outline)
                : SkyColor.inkMuted
            configuration.label
                .skyText(.button, color: isEnabled ? kind.label : SkyColor.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SkySpacing.s6)
                .padding(.vertical, SkySpacing.s3)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: SkyLayout.popButtonHeight)
                .contentShape(shape)
                .skyPopSurface(
                    shape,
                    fill: isEnabled ? kind.fill : SkyColor.inkDisabled,
                    outline: outline,
                    lineWidth: SkyStroke.outlineHeavy,
                    shadow: isEnabled ? SkyPopShadow.button : .zero,
                    sunk: configuration.isPressed
                )
                .animation(reduceMotion ? nil : SkyMotion.pressEase, value: configuration.isPressed)
        }
    }
}

// MARK: - Sky Pop chip / selectable tile (2.5pt outline, 3×3 shadow)

/// A selectable chip or tile (e.g. lock-time options). Selected = pushed in:
/// ink fill, cream label, sitting on its shadow. Reports `.isSelected` to VoiceOver.
struct SkyChipButtonStyle: ButtonStyle {
    var isSelected = false
    var onAccent = false

    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, isSelected: isSelected, onAccent: onAccent)
    }

    struct Content: View {
        let configuration: Configuration
        let isSelected: Bool
        let onAccent: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
            let outline = onAccent ? SkyColor.outlineOnAccent : SkyColor.outline
            configuration.label
                .skyText(.button, color: isSelected ? SkyColor.surface : SkyColor.ink)
                .padding(.horizontal, SkySpacing.s4)
                .padding(.vertical, SkySpacing.s3)
                .frame(maxWidth: .infinity, minHeight: SkyLayout.minTouchTarget)
                .contentShape(shape)
                .skyPopSurface(
                    shape,
                    fill: isSelected ? SkyColor.ink : SkyColor.surfaceCard,
                    outline: outline,
                    lineWidth: SkyStroke.outline,
                    shadow: SkyPopShadow.chip,
                    sunk: isSelected || configuration.isPressed
                )
                .animation(reduceMotion ? nil : SkyMotion.pressEase, value: configuration.isPressed)
                .animation(reduceMotion ? nil : SkyMotion.pressEase, value: isSelected)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
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

/// Full-width Sky Pop button. Pass `systemImage` for a trailing icon (e.g. the
/// arrow on "Let's go outside"); it's decorative, the title is the VoiceOver label.
struct SkyPopButton: View {
    let title: String
    var kind: SkyPopButtonKind = .primary
    var systemImage: String? = nil
    var onAccent = false
    let action: () -> Void

    init(_ title: String, kind: SkyPopButtonKind = .primary, systemImage: String? = nil,
         onAccent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.systemImage = systemImage
        self.onAccent = onAccent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SkySpacing.s2) {
                Text(title)
                if let systemImage {
                    Image(systemName: systemImage)
                        .fontWeight(.heavy)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(SkyPopButtonStyle(kind: kind, onAccent: onAccent))
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

/// Gallery of the Sky Pop controls on the cream surface and on a Pop ground.
private struct SkyPopButtonGallery: View {
    @State private var lockTime = "7:30"

    var body: some View {
        ScrollView {
            VStack(spacing: SkySpacing.s6) {
                VStack(spacing: SkySpacing.s4) {
                    SkyPopButton("Let's go outside", systemImage: "arrow.right") {}
                    SkyPopButton("Share sky", kind: .cream) {}
                    SkyPopButton("Open Sky", kind: .ink) {}
                    SkyPopButton("Unlock anyway", kind: .coral) {}
                    SkyPopButton("Disabled") {}.disabled(true)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SkySpacing.s3), count: 3),
                          spacing: SkySpacing.s3) {
                    ForEach(["6:30", "7:00", "7:30", "8:00", "8:30", "9:00"], id: \.self) { time in
                        Button(time) { lockTime = time }
                            .buttonStyle(SkyChipButtonStyle(isSelected: time == lockTime))
                    }
                }
                // On a bright Pop ground the outline stays ink, even in dark mode.
                HStack(spacing: SkySpacing.s3) {
                    SkyPopButton("Share sky", kind: .cream, onAccent: true) {}
                    SkyPopButton("Done", onAccent: true) {}
                }
                .padding(SkySpacing.s5)
                .background(SkyColor.popSky, in: RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous))
            }
            .padding(SkySpacing.s6)
        }
        .background(SkyColor.surface)
    }
}

#Preview("Sky Pop buttons — light") {
    SkyPopButtonGallery().preferredColorScheme(.light)
}

#Preview("Sky Pop buttons — dark") {
    SkyPopButtonGallery().preferredColorScheme(.dark)
}
