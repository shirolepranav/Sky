# Sky — Design System

This is the authoritative design spec for Sky. Values here mirror `tokens.jsx` in
the HTML prototype and `AppBranding.swift` in the PRD — if anything conflicts,
this document and `tokens.jsx` win. Build to these tokens; do not invent values.

Companion docs:
- `uploads/Sky_PRD.md` — product requirements, brand voice, `AppBranding.swift`.
- `uploads/Sky_App_Workflow.md` — per-screen behaviour and states.
- `Sky Design Standard.html` — living visual reference (open it to see everything below rendered).

---

## 1. Principles

**Sky Pop** (adopted 2026-10-15; reference: the "Sky Pop" Design canvas, boards
TodayPop / ShieldPop / CelebratePop, plus TodayPlus / StreaksPlus / LockTimePlus for
how the same rules apply to existing layouts). Sky is friendly and confident, not
sleepy: chunky ink outlines, a rounded display face and a punchier palette, still
warm and never anxious.

1. **Ink outline + hard offset shadow = tappable.** Buttons, chips, selectable tiles and badges carry a 2.5–3pt `ink` outline plus a solid ink offset shadow (see §6 "Tappable outline"). Info-only cards keep the soft hairline `divider` border, so the outline itself teaches what you can tap.
2. **Rounded display face for titles and big numbers.** Fredoka in the design (SF Rounded Heavy until it is bundled); Nunito / SF Rounded stays for body copy. See §3.
3. **Punchier palette.** `popSky`, `popCoral` and `popSun` (§2) are louder siblings of the pastel accents and keep the same meanings (principle 7).
4. **One loud moment per screen.** Each screen gets one hero block and everything else stays calm on the cream surface. Today: a full-bleed `popSky` top half with a big outlined "sticker" Nimbus and a speech bubble, over a cream bottom sheet (3pt ink top edge, 32pt top radius). Streaks: the coral hero number. Shield: the sun ground.
5. **Never pure white or pure black.** Backgrounds are warm off-whites; text is `ink #2D3748`, never `#000`.
6. **Mascot-first.** Nimbus (the cloud) is the emotional centre of almost every screen.
7. **One colour, one meaning.** Each accent maps to a single semantic role (see §2). Don't use accents decoratively.
8. **Honest, never guilt-trip.** Copy is warm but truthful. Friction is clear, not punishing.
9. **Subtle motion only.** Nimbus has a ~2s idle bob and ~0.5s state transitions. Avoid infinite decorative animation elsewhere.

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

### Sky Pop accents

| Token | Hex | Role |
|---|---|---|
| `popSky` | `#8FD3F0` | Full-bleed hero ground (Today, unlock celebration) |
| `popCoral` | `#FF7A66` | Streak (badge, streak hero). Ink label: 4.7:1 ✓ |
| `popSun` | `#FFC93C` | Verified / milestone; also the shield ground |

They don't darken in dark mode (they're grounds, not surfaces). Text on them is
`inkOnAccent` (fixed `#2D3748`) and outlines on them are `outlineOnAccent`.
`mossGreenAction` stays the fill for any button with a white label.

### Outlines

| Token | Light | Dark | Role |
|---|---|---|---|
| `outline` | `#2D3748` | `#08090D` (`darkOutline`) | Ink outline + hard shadow of tappable elements on surfaces |
| `outlineDisabled` | `#9CA3AF` | `#08090D` | Outline of a disabled Pop control (no shadow) |
| `outlineOnAccent` | `#2D3748` | `#2D3748` | Same, on a Pop ground (`popSky` / `popSun` / `popCoral`) |

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
| `darkOutline` | `#08090D` | Sky Pop outline + hard shadow on dark (deeper than `darkBg`) |

---

## 3. Typography

**Two faces.**
- **Display** — titles, big numbers, Pop button labels. Fredoka (SIL OFL) in the design; on iOS
  **SF Rounded Heavy** until Fredoka is bundled. Every style resolves its font through
  `SkyFont` (Typography.swift), so bundling Fredoka changes that one enum (plus adding the
  files under `UIAppFonts` in `Sky/Info.plist`, which the target merges with its generated plist).
- **Body** — Nunito (iOS: SF Rounded as the native equivalent). Generous line height.
  Full stack: `Nunito, -apple-system, BlinkMacSystemFont, system-ui, sans-serif`.

Display / Title XL / Title L / Title M, Button, Numeral and Numeral XL use the display face;
the rest use the body face.

| Style | Size / Weight | Letter-spacing | Line-height | Use |
|---|---|---|---|---|
| Display | 40 / 800 | -1.2 | 1.05 | Hero moments ("That's the stuff.") |
| Title XL | 32 / 800 | -0.6 | 1.05 | Large screen titles |
| Title L | 28 / 800 | -0.6 | 1.1 | Screen titles ("Time's up.") |
| Title M | 22 / 800 | -0.4 | 1.2 | Card titles |
| Button | 20 / 800 | -0.2 | 1.1 | Sky Pop button & chip labels (display face) |
| Numeral XL | 64 / 800 | -1.5 | 0.95 | Hero numbers: streak count, lock time (display face) |
| Numeral | 32 / 800 | -0.5 | 1 | Stat-tile numbers: "0/200", "5 sec" (display face) |
| Headline | 17 / 800 | -0.2 | 1.2 | Classic button labels, emphasis |
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
| `sheet` | 32 | Sky Pop bottom sheet (top corners only) |
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
| Button (classic) | `0 2px 0 <buttonDeep>` | **Solid offset**, not blur — gives the "pressable" look |
| Pop button | `0 5px 0 outline` + 3pt outline | Sky Pop full-width buttons |
| Pop chip / tile / badge | `3px 3px 0 outline` + 2.5pt outline | Sky Pop chips, selectable tiles, badges |

### Tappable outline (Sky Pop)

**Ink outline + hard offset shadow means "you can tap this".** The rule is what
keeps the louder look legible:

- **Gets it:** buttons, chips, selectable tiles, badges. Outline `SkyStroke.outlineHeavy`
  (3pt) on buttons, `SkyStroke.outline` (2.5pt) on chips/tiles/badges. Shadow is a solid
  copy of the shape in the outline colour, radius 0: `SkyPopShadow.button` (0×5) or
  `SkyPopShadow.chip` (3×3).
- **Pressed:** the element translates by the shadow offset into its shadow and the shadow
  goes to 0, so it looks pushed in. A *selected* chip stays pushed in.
- **Disabled:** fill `inkDisabled`, outline `outlineDisabled`, no shadow (it isn't tappable).
- **Does not get it:** info-only cards and stat tiles. They keep the hairline `divider`
  border. An outline *without* a shadow is allowed only for a flat "sticker" label on a
  Pop ground (e.g. the date pill on Today); it is not tappable and has no shadow.
- **Dark mode:** on surfaces the outline is `outline`, which becomes near-black `darkOutline`
  (deeper than `darkBg`): a dark rim and dark drop, never a light halo around controls.
  On a Pop ground it is `outlineOnAccent` (stays ink).
- Swift: `View.skyPopSurface(_:fill:outline:lineWidth:shadow:sunk:)` draws it;
  `SkyPopButtonStyle`, `SkyChipButtonStyle`, `SkyPopPill` and `SkyPopStreakBadge` use it.

---

## 7. Components

### Primary button
- Fill `mossGreenAction #52822A`, label `#FFFFFF`, **17 / 800**, letter-spacing -0.2.
- Radius `rBtn (18)`, padding `18 × 24`, full-width by default.
- Shadow: solid offset `0 2px 0 #3D6420`.
- **Pressed:** translate down ~2px, drop the offset shadow.
- **Disabled:** fill `inkDisabled #CBD5E0`, no shadow.

### Sky Pop button (`SkyPopButton` / `SkyPopButtonStyle`)
- Full-width, min height 58, radius `rBtn (18)`, label **Button** style (20, display face).
- 3pt outline + `0 5px 0` hard shadow (§6 "Tappable outline").
- Kinds (all clear AA): `primary` `mossGreenAction` + white · `cream` `warmCream` + ink ·
  `ink` ink + surface label · `coral` `popCoral` + ink.
- On a Pop ground pass `onAccent: true` so the outline stays ink in dark mode.

### Sky Pop chip / selectable tile (`SkyChipButtonStyle`)
- Radius `rChip (14)`, min 44pt tall, `surfaceCard` fill, ink label (Button style).
- 2.5pt outline + `3px 3px 0` hard shadow. **Selected:** ink fill, surface label, pushed
  into its shadow; reports `.isSelected` to VoiceOver.

### Sky Pop pill & streak badge (`SkyPopPill`, `SkyPopStreakBadge`)
- Capsule, 2.5pt outline, **Label** text. `raised: true` (badge) adds the 3×3 shadow;
  flat stickers have none.
- Streak badge: `popCoral` fill, sun-filled ink flame, display-face count, raised.

### Sky Pop bottom sheet (`SkyPopSheet`)
- Cream `surface`, top corners `sheet (32)`, 3pt `outlineOnAccent` top edge only, runs into the
  bottom safe area. Sits under a full-bleed Pop hero.

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
