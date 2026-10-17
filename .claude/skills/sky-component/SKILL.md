---
name: sky-component
description: Add, change, or review a reusable design-system component in the Sky iOS app — anything under Sky/Core/DesignSystem (colors, typography, spacing, buttons, cards, pills, chips, progress ring, icons) or the Nimbus mascot. Use when creating a shared UI primitive, adding a design token, or adjusting button/card/mascot styling so it stays faithful to DESIGN_SYSTEM.md and tokens.jsx.
---

# Working on a Sky design-system component

Components in `Sky/Core/DesignSystem` and `Sky/Features/Mascot/NimbusView.swift`
are shared primitives. Keep them faithful to `DESIGN_SYSTEM.md` and the prototype
tokens — they are the foundation every screen depends on.

## Source of truth

- Visual spec: `DESIGN_SYSTEM.md` (color §2, type §3, spacing §4, radii §5,
  elevation §6, components §7, Nimbus §8, a11y §9).
- Prototype values: `Sky-handoff/sky/project/tokens.jsx` (the `SKY_TOKENS` object
  and `skyPrimaryBtn` / `skySecondaryBtn` / `skyCoralBtn` helpers) and
  `nimbus.jsx` for the mascot geometry.
- If a value isn't in those files, it's not a token — ask before inventing one.

## Rules

1. **Tokens reference tokens.** New colors go in `SkyColor` (ColorTokens.swift);
   everything else references `SkyColor` / `SkySpacing` / `SkyRadius` /
   `SkyTextStyle`. Never hardcode hex or off-scale numbers. `#000`/`#FFF` are
   allowed only inside Nimbus fills and button labels.
2. **AA contrast for white-on-fill.** Use `mossGreenAction` (`#52822A`) for
   filled controls with white labels; `mossGreen` is a tint/nav/checkmark color
   only. New filled+white-label components must clear 4.5:1.
3. **Calm, soft.** Hairline `divider` borders over heavy shadows. The pressable
   button shadow is a *solid offset* (`.shadow(radius: 0, y: 2)`), dropped on
   press while the control translates down 2px.
4. **One color, one meaning** (§2). Don't repurpose an accent.
5. **Motion:** subtle only; honor `accessibilityReduceMotion`.
6. **API shape:** match the existing components — a `ButtonStyle` + a thin
   convenience `View` wrapper; `SkyCard`-style `@ViewBuilder content`. Provide
   sensible defaults so call sites stay terse.

## Nimbus specifics

- `NimbusView` draws in a fixed 200×156 coordinate space via `Canvas`, scaled to
  `size`; height is always `size * 0.78`. Keep new geometry in that space.
- Five states only (`MascotState`): `cloudyGrey`, `fluffyWhite`, `sunny`,
  `rainbow`, `rainy`. Don't add states without a PRD/DESIGN_SYSTEM change.
- Per-state palette lives in `NimbusConfig`; mirror `nimbus.jsx` exactly when
  editing fills, shadows, cheeks, or expressions.

## Checklist before finishing

- [ ] Uses only tokens; no inline literals or off-scale spacing.
- [ ] File header comment cites the DESIGN_SYSTEM section it implements.
- [ ] `#Preview` covering the variants (and dark mode if behavior differs).
- [ ] Contrast checked for any white-on-fill surface.
- [ ] Reduce-Motion path handled if it animates.
- [ ] Type-checks clean (see `CLAUDE.md` → Build & verify). State that only
      compilation was verified when full Xcode isn't available.
- [ ] No regressions: existing components still reference the changed token
      correctly (grep usages if you renamed/retuned a token).
