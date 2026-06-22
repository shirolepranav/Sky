# Sky — Design System

**Touch grass for people who actually want to quit.**

This is the authoritative design spec for Sky. Values here mirror `tokens.jsx` in
the HTML prototype and `AppBranding.swift` in the PRD — if anything conflicts,
this document and `tokens.jsx` win. Build to these tokens; do not invent values.

Companion docs:
- `uploads/Sky_PRD.md` — product requirements, brand voice, `AppBranding.swift`.
- `uploads/Sky_App_Workflow.md` — per-screen behaviour and states.
- `Sky Design Standard.html` — living visual reference (open it to see everything below rendered).

---

## 1. Principles

1. **Calm, cute, soft.** Pastel palette, rounded forms, generous whitespace. The app should lower anxiety, not raise it.
2. **Never pure white or pure black.** Backgrounds are warm off-whites; text is `ink #2D3748`, never `#000`.
3. **Mascot-first.** Nimbus (the cloud) is the emotional centre of almost every screen.
4. **One colour, one meaning.** Each accent maps to a single semantic role (see §2). Don't use accents decoratively.
5. **Honest, never guilt-trip.** Copy is warm but truthful. Friction is clear, not punishing.
6. **Subtle motion only.** Nimbus has a ~2s idle bob and ~0.5s state transitions. Avoid infinite decorative animation elsewhere.

---

## 2. Color

### Brand palette

| Token | Hex | Role |
|---|---|---|
| `primarySky` | `#A8D8EA` | Hero, calm backgrounds, brand surfaces |
| `primarySkyDeep` | `#7AB8D0` | Hover / active state of sky elements |
| `warmCream` | `#FFF6E5` | Surfaces, shield background, chips |
| `warmCreamDeep` | `#F5EAD0` | Pressed cream surfaces |
| `mossGreen` | `#7CB342` | Tints, **nav active**, success cues **on light backgrounds** |
| `mossGreenDeep` | `#5C8A2E` | Green text/icons on white (e.g. "new personal best") |
| `mossGreenAction` | `#52822A` | **Primary button fill** — white label clears WCAG AA (4.6:1) |
| `mossGreenActionDeep` | `#3D6420` | Pressed state + solid drop-shadow under primary button |
| `coralStreak` | `#FF8A7A` | Streaks, alerts, "apps paused" urgency |
| `coralStreakDeep` | `#E5685A` | Coral button shadow / coral text on white |
| `cloudGrey` | `#B8C5D0` | Indoor / paused Nimbus, neutral states |
| `cloudGreyDeep` | `#9BA9B6` | Pressed grey |
| `sunYellow` | `#FFD66B` | Verified state, milestones, badges |
| `sunYellowDeep` | `#E5B843` | Yellow shadow / accent |

> **Why two greens?** The bright `mossGreen #7CB342` is lovely as a tint and on
> light backgrounds, but white text on it only reaches ~2.5:1 (fails WCAG AA).
> Use `mossGreenAction #52822A` for any **filled** element with a white label.

### Text

| Token | Hex | Role |
|---|---|---|
| `ink` | `#2D3748` | Primary text (never pure black) |
| `inkSoft` | `#5A6373` | Secondary text |
| `inkMuted` | `#9CA3AF` | Tertiary / captions / overlines |
| `inkDisabled` | `#CBD5E0` | Disabled fills & text |

### Surfaces

| Token | Value | Role |
|---|---|---|
| `surface` | `#FFFBF2` | Main app background (warm off-white) |
| `surfaceCard` | `#FFFFFF` | Cards on top of surface |
| `surfaceElev` | `#FFFEFB` | Elevated surfaces |
| `divider` | `rgba(45,55,72,0.08)` | Hairline dividers & card borders |

### Dark mode

| Token | Value | Role |
|---|---|---|
| `darkBg` | `#15171F` | Deep night-sky background |
| `darkBgElev` | `#1F2230` | Elevated dark surface |
| `darkInk` | `#F0F4F8` | Primary text on dark |
| `darkInkSoft` | `#A8B3C2` | Secondary text on dark |
| `darkDivider` | `rgba(255,255,255,0.08)` | Dividers on dark |

---

## 3. Typography

**Family:** Nunito (iOS: SF Rounded as the native equivalent). Generous line height. Rounded, friendly.
Full stack: `Nunito, -apple-system, BlinkMacSystemFont, system-ui, sans-serif`.

| Style | Size / Weight | Letter-spacing | Line-height | Use |
|---|---|---|---|---|
| Display | 40 / 800 | -1.2 | 1.05 | Hero moments ("That's the stuff.") |
| Title XL | 32 / 800 | -0.6 | 1.05 | Large screen titles |
| Title L | 28 / 800 | -0.6 | 1.1 | Screen titles ("Time's up.") |
| Title M | 22 / 800 | -0.4 | 1.2 | Card titles |
| Headline | 17 / 800 | -0.2 | 1.2 | Button labels, emphasis |
| Body | 17 / 500 | 0 | 1.45 | Primary body copy |
| Body S | 15 / 500 | 0 | 1.45 | Secondary body |
| Label | 14 / 700 | 0 | 1.3 | Inline labels, chips |
| Caption | 13 / 600–700 | 0.3 | 1.4 | Metadata, hints |
| Overline | 12 / 800 | 1.2 | 1.3 | UPPERCASE section headers |
| Tab label | 10 / 700 | 0.3 | 1 | Bottom-nav labels |

---

## 4. Spacing

Use a **4pt base scale**. Compose padding/gaps from these steps — don't use off-scale values.

| Token | px | Typical use |
|---|---|---|
| `space-1` | 4 | Icon ↔ label micro-gaps |
| `space-2` | 8 | Tight gaps, chip padding-y |
| `space-3` | 12 | Stacked controls |
| `space-4` | 16 | Default gap between elements / card list gap |
| `space-5` | 20 | Card inner padding |
| `space-6` | 24 | Screen horizontal margin, button padding-x |
| `space-8` | 32 | Section spacing |
| `space-10` | 40 | Large section spacing / card padding (foundations) |

**Fixed layout constants**
- Screen horizontal margin: **24** (some card-led screens use 16).
- Bottom safe-area inset: **34**.
- Minimum touch target: **44 × 44** (never smaller).

---

## 5. Radii

| Token | px | Use |
|---|---|---|
| `rChip` | 14 | Chips, small tiles, swatches |
| `rBtn` | 18 | Buttons |
| `rCard` | 24 | Primary cards |
| (card-secondary) | 20 | Inner / secondary cards |
| pill | 999 | Status pills, streak chips, badges |
| device | 48 | Phone frame only |

---

## 6. Elevation

Shadows are soft and low-spread, tinted toward `ink` (or the accent for coloured cards). Avoid heavy/hard shadows.

| Level | Shadow | Use |
|---|---|---|
| Flat | `none` + `1px solid divider` | Most cards (border, not shadow) |
| Raised-1 | `0 1px 2px rgba(45,55,72,0.04)` | Subtle card lift |
| Raised-2 | `0 2px 8px rgba(45,55,72,0.04)` | Floating chips |
| Accent glow | `0 4px 20px rgba(255,138,122,0.15)` | Celebratory cards (tint matches accent) |
| Button | `0 2px 0 <buttonDeep>` | **Solid offset**, not blur — gives the "pressable" look |

---

## 7. Components

### Primary button
- Fill `mossGreenAction #52822A`, label `#FFFFFF`, **17 / 800**, letter-spacing -0.2.
- Radius `rBtn (18)`, padding `18 × 24`, full-width by default.
- Shadow: solid offset `0 2px 0 #3D6420`.
- **Pressed:** translate down ~2px, drop the offset shadow.
- **Disabled:** fill `inkDisabled #CBD5E0`, no shadow.

### Secondary button
- Transparent fill, label `inkSoft` (dark: `darkInk`), **16 / 700**.
- Border `1.5px solid rgba(45,55,72,0.12)` (dark: `darkDivider`).
- Radius 18, padding `16 × 24`, full-width.

### Coral button (destructive / "unlock anyway")
- Fill `coralStreak #FF8A7A`, label `#FFFFFF`, **17 / 800**.
- Radius 18, padding `18 × 24`, shadow `0 2px 0 #E5685A`.

### Card
- Fill `surfaceCard #FFFFFF`, radius `rCard (24)`, `1px solid divider`, padding 20.
- Inner/secondary cards: radius 20.

### Status pill
- Pill (radius 999), `warmCream` or white fill, **14 / 700**, padding `10 × 18`.
- Often leads with an 8×8 dot whose colour signals state (coral = paused, etc.).

### Bottom tab bar
- Frosted: `rgba(255,251,242,0.92)` + `backdrop-filter: blur(20px) saturate(160%)` (dark: `rgba(21,23,31,0.85)`).
- Top hairline `divider`; bottom padding 34 (safe area).
- 3 tabs: Today / Streaks / Settings. **Active = `mossGreen`**, inactive = `inkMuted` (dark: `darkInkSoft`).
- Today shows a red dot when `isCurrentlyBlocked && !verifiedToday`.

### Progress ring
- SVG, rotated -90°, round line-caps. Track is the accent at ~15–18% opacity; fill is the accent.

### Custom shield (blocking screen)
The screen shown when a blocked app is opened. Sky uses the **warm-invitation** pattern — friendly and honest, never cold or punishing. (This is the canonical direction; do not build a flat grey "firm" variant.)
- **Background:** soft vertical gradient `warmCream → surface (#FFFBF2) → primarySky @ ~13%`, with 2–3 blurred white cloud shapes. Never a flat cool grey — keep it inside the warm palette.
- **Mascot:** Nimbus `fluffyWhite` at ~220, centred and looking out; small "☁ Sky" brand pill above it.
- **Copy:** headline in `Title L` ("Nimbus is outside."); warm-but-truthful body in `Body`, max ~2 lines.
- **Streak chip:** white @ 70% with a coral hairline — a gentle reminder, not a guilt-trip.
- **Actions:** primary `Go outside to unlock`; below it a quiet **text-only** escape ("I can't go outside right now") — no border/fill, `inkSoft`, 14 / 600.

---

## 8. Nimbus (mascot)

A cloud character, pronoun "they". One mascot, five states. Transition between states over ~0.5s; idle bob ~2s loop.

| State | Trigger |
|---|---|
| Cloudy (grey) | Default · not yet verified today |
| Fluffy (white) | Idle · under budget |
| Sunny | After successful verification |
| Rainbow | Streak milestone reached |
| Rainy | Emergency unlock used |

---

## 9. Accessibility

- **Contrast:** white text on a filled element must reach **4.5:1** (use `mossGreenAction`, not `mossGreen`). Large/bold text ≥ 3:1.
- **Touch targets:** minimum **44 × 44 pt**.
- **Never pure black or pure white** — use `ink` and the warm surface tokens.
- **Motion:** respect `prefers-reduced-motion`; the idle bob and state transitions should pause/shorten when set.
- Active nav label currently uses bright `mossGreen` on cream (~2.3:1) — **known low-contrast item**, prefer the deeper green or pair colour with the bold weight + icon for legibility.

---

## 10. Token source of truth

In the prototype, all tokens live in **`tokens.jsx`** as `SKY_TOKENS`, plus the button-style
helpers `skyPrimaryBtn()`, `skySecondaryBtn()`, `skyCoralBtn()`. In the app, they mirror
`AppBranding.swift` (PRD §11). Renaming the app or mascot requires editing only `AppBranding.swift`.
