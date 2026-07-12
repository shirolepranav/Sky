---
name: ts-component
description: Add, change, or review a reusable design-system component in the TrailSisters iOS app — anything under Core/DesignSystem (TSColor tokens, TSTextStyle, spacing/radius, TSPrimaryButton, TSCard, TSAvatar, VerifiedBadge, TSChip, TSStatusPill, TSEmptyState, TSMap styling, etc.). Use when creating a shared UI primitive or adding a design token so it stays faithful to DESIGN_SYSTEM.md.
---

# Working on a TrailSisters design-system component

Components in `Core/DesignSystem` are shared primitives every screen depends
on. Keep them faithful to `DESIGN_SYSTEM.md` (the authoritative visual spec).

## Source of truth

- `DESIGN_SYSTEM.md`: principles §1, color §2, type §3, spacing/radius §4,
  components §5, motion §6, a11y §8.
- If a value isn't in that doc, it's not a token — ask (or propose a doc
  update in the same PR) before inventing one.

## Rules

1. **Tokens reference tokens.** New colors go in `TSColor` with light AND dark
   values; everything else references `TSColor` / `TSSpacing` / `TSRadius` /
   `TSTextStyle`. Never hardcode hex or off-scale numbers.
2. **AA contrast is tested, not assumed.** White labels only on the fills
   listed in DESIGN_SYSTEM §2's hard rules. Any new fill+label pair gets added
   to the automated contrast test.
3. **One color, one meaning.** `verifiedTeal` = verification only.
   `safetyOrange` = safety/alerts only. `alpine` = informational/live only.
   Don't repurpose accents decoratively. No pink, no red, no gradients
   (except photo scrim).
4. **Zero dating-app affordances.** No heart shapes, no swipe-card primitives,
   no flame/spark iconography — reject the request if asked.
5. **Trust components are non-optional.** `TSAvatar` always composes
   `VerifiedBadge` for verified members; never ship an avatar variant that
   drops it (PRD §4).
6. **Calm elevation.** `snow` surface + 1 px `mist` border; shadows only for
   floating elements per §4.
7. **Motion:** subtle, ≤ spec durations, full Reduce Motion path. Safety-
   critical UI (check-in prompt) renders instantly with no entrance animation.
8. **API shape:** match existing components — a `ButtonStyle` or small `View`
   with sensible defaults and `@ViewBuilder content` where it composes.
   SF Symbols only for icons.

## Definition of done

- Component + `#Preview` (light, dark, Dynamic Type XL, disabled/loading
  states where applicable).
- VoiceOver label/traits; 44×44 minimum target; Reduce Motion behavior.
- Contrast test entry if a new fill+label pair; snapshot test if the roadmap
  phase calls for one.
- If you changed a token's value, update `DESIGN_SYSTEM.md` in the same
  change — code and doc never drift.
