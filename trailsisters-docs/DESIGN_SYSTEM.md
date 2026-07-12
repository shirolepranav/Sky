# TrailSisters — Design System (v0.1)

**Status:** starter spec, authored ahead of visual design. These tokens are **authoritative until the owner revises them** — build against them, don't invent alternatives. If this doc and any other doc disagree on visuals, this doc wins. For product behavior, the PRD wins.

Direction (PRD §4): capable-outdoorswoman, warm but not cutesy, **AllTrails × Airbnb trust patterns**. Zero dating-app visual language: **no hearts, no pink-by-default, no swipe affordances, no flame/spark motifs — anywhere, ever.**

---

## 1. Principles

1. **Trust is the aesthetic.** Verified badges, real names, clear status pills, honest system copy. Nothing decorative that could read as flirty or gamified.
2. **Outdoors, daylight-first.** Earthy greens and warm neutrals; high legibility in sunlight (strong contrast, generous type).
3. **Tokens, never literals.** Colors from `TSColor`, type via `.tsText(_:)`, spacing from `TSSpacing`, radii from `TSRadius`. Off-scale values are bugs.
4. **One color, one meaning.** Teal = verified/trust. Orange = safety/alerts. Blue = informational/live. Green = brand/actions. Never repurpose accents decoratively.
5. **Accessibility is a launch requirement, not polish** (PRD §4): Dynamic Type everywhere, VoiceOver labels on every interactive element, 44×44 pt minimum targets, Reduce Motion honored, all text AA (4.5:1).
6. **SF Symbols only** for iconography (outline weight regular; fill for selected states). No custom icon font.

---

## 2. Color (`TSColor`)

All pairs listed as (light / dark). Every fill+label pair below is AA-verified; Phase 1 ships automated contrast tests for them.

### Brand & action
| Token | Light | Dark | Use |
|---|---|---|---|
| `pine` | `#2F6142` | `#4E8A64` | Primary buttons (white label — 7.2:1 in light), links on tinted cards, tab active |
| `pineDeep` | `#1E3D2C` | `#16281E` | Headers on imagery, map route casing, pressed states |
| `moss` | `#6E9A5B` | `#7FAA6C` | Tints, success checkmarks, progress fills on light surfaces. **Never white text on moss** |

### Meaning accents (one color, one meaning)
| Token | Light | Dark | Meaning |
|---|---|---|---|
| `verifiedTeal` | `#0E7466` | `#2C9484` | Verification ONLY: `VerifiedBadge`, verified labels, trust UI (5.7:1 w/ white) |
| `safetyOrange` | `#B4500F` | `#D96F2E` | Safety & alerts ONLY: check-in prompts, escalation banners, AQI>100, destructive-adjacent warnings (5.1:1 w/ white in light) |
| `alpine` | `#2C6E8F` | `#5299BC` | Informational/live ONLY: live-location indicators, info banners, weather links (5.6:1 w/ white in light) |
| `golden` | `#B7791F` | `#D0983F` | Caution tint (permit required, moderate AQI) — always with `ink` text on `goldenTint` |

### Tints (backgrounds for chips/banners; always `ink`-family text)
`pineTint` `#E7F0E9`/`#22301F` · `tealTint` `#E2F1EE`/`#1B2E2A` · `orangeTint` `#F9E9DD`/`#33261C` · `alpineTint` `#E4EFF5`/`#1C2A32` · `goldenTint` `#F7EEDC`/`#322B1C`

### Neutrals
| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#26332B` | `#E8EDE8` | Primary text (12.9:1 on `sand`) |
| `stone` | `#5A6B60` | `#A5B2A8` | Secondary text (5.6:1 on `sand`), icons |
| `mist` | `#E4E9E3` | `#2A342C` | Hairline dividers, card borders |
| `sand` | `#F6F4EF` | `#141A16` | App background (warm off-white — not pure white) |
| `snow` | `#FFFFFF` | `#1E2620` | Card surfaces, sheets |
| `scrim` | `#26332B` @ 40% | `#000000` @ 55% | Overlays behind sheets/photos |

### Semantic aliases
`destructive` = `safetyOrange` family (we do NOT use red — red is reserved by iOS system UI and reads alarmist; destructive confirms use orange + explicit copy). `success` = `moss`. `link` = `pine` (light) / `alpine` (dark imagery contexts).

### Hard rules
- White text ONLY on: `pine`, `pineDeep`, `verifiedTeal`, `safetyOrange`, `alpine`, `scrim`, photos-with-scrim.
- Pure `#FFFFFF` appears only as `snow` surface and button labels; pure `#000000` only inside `scrim` (dark).
- No pink anywhere in the palette. No gradients except the photo scrim.

---

## 3. Typography (`TSTextStyle`, applied via `.tsText(_:)`)

SF Pro throughout (system default; SF Pro Rounded is **not** used — rounded reads cutesy). All sizes are Dynamic Type–relative (`relativeTo:` anchors below); never fixed-point fonts.

| Token | Size/weight | Relative to | Use |
|---|---|---|---|
| `displayL` | 34 bold | .largeTitle | Screen titles (Home, wordmark contexts) |
| `titleL` | 28 bold | .title | Section heroes, trail names on trail page |
| `titleM` | 22 semibold | .title2 | Card titles, park names |
| `titleS` | 17 semibold | .headline | Row titles, button labels |
| `body` | 17 regular | .body | Default text |
| `bodyS` | 15 regular | .subheadline | Card body, chat timestamps context |
| `caption` | 13 regular | .footnote | Metadata, attribution, caveats |
| `micro` | 11 medium | .caption2 | Pills, badges, tab labels |
| `mono` | 15 regular monospaced | .subheadline | Coordinates, OTP boxes, GPX stats |

Line limits: prefer wrapping over truncation for safety copy (coverage caveats, escalation text must never truncate).

---

## 4. Spacing, Radius, Layout

- **`TSSpacing`** (4-pt scale): `xxs 4 · xs 8 · s 12 · m 16 · l 20 · xl 24 · xxl 32 · huge 40`. Screen horizontal margin: `m (16)`. Card internal padding: `m`. Section gap: `xl`.
- **`TSRadius`**: `s 8` (chips, thumbnails) · `m 12` (buttons, fields) · `l 16` (cards, sheets) · `pill 999` (pills, badges, chips-selected).
- **Elevation:** cards use `snow` surface + 1 px `mist` border. Shadows only on floating elements (toast, active-hike pill): `y2 blur8 @ ink 8%`. No heavy drop shadows.
- Buttons are full-width by default within the content margin; height 52 pt (44 pt minimum for compact variants).
- Tab bar: 5 items, SF Symbols (`house`, `map`, `plus.circle.fill` (center, `pine`), `bubble.left.and.bubble.right`, `person.crop.circle`), labels in `micro`.

---

## 5. Core Components

| Component | Spec |
|---|---|
| `TSPrimaryButton` | `pine` fill, white `titleS` label, radius `m`, 52 pt. Pressed: `pineDeep`. Disabled: 40% opacity. Loading: label→spinner |
| `TSSecondaryButton` | `snow` fill, 1.5 px `pine` border, `pine` label |
| `TSDestructiveButton` | `orangeTint` fill, `safetyOrange` label; irreversible confirms use solid `safetyOrange` + white |
| `TSCard` | `snow`, radius `l`, 1 px `mist` border, padding `m`. `@ViewBuilder content` |
| `TSAvatar` | Circle, sizes 32/44/64/96. **Always composes `VerifiedBadge`** (bottom-trailing) for verified members — there is no verified-member avatar without it (PRD §4) |
| `VerifiedBadge` | `checkmark.shield.fill` white on `verifiedTeal` circle, 40% of avatar diameter (min 16 pt). Standalone inline variant: badge + "Verified" `micro` label |
| `TSBadge` | Capability badges (WFR `cross.case.fill`, satellite `antenna.radiowaves.left.and.right`, Host `figure.hiking`): `tealTint`/`pineTint` pill, icon + `micro` label |
| `TSChip` / `TSChipGroup` | Selectable: `snow`+`mist` border → selected `pineTint`+`pine` border+`pine` text. Radio or multi semantics declared |
| `TSStatusPill` | Hike/trip states: open `pineTint` · full `goldenTint` · confirmed `tealTint` · in progress `alpineTint` · completed `mist` · cancelled `orangeTint` |
| `TSDifficultyPill` | easy `moss` dot · moderate `golden` dot · hard `safetyOrange` dot · very hard `pineDeep` dot; dot + `micro` label on `snow` pill (color-blind-safe: label always present) |
| `TSStatTile` | `mono`/`titleM` value + `caption` label, on `TSCard` grid |
| `TSEmptyState` | SF Symbol (48 pt, `stone`), one line `body`, one supporting `bodyS stone`, and **always ≥1 action button** (PRD §4) |
| `TSBanner` | Full-width tinted banner (alert/AQI/offline): tint bg + `ink` text + leading icon; dismissible where non-critical |
| `TSToast` | Floating capsule bottom, `ink` bg (light) / `snow` (dark), auto-dismiss 2.5 s, VoiceOver announced |
| `TSProgressRing` | 6 pt stroke, `pine` on `mist` track; completeness variant shows % in `titleM` |
| `TSListRow` | 52 pt min height, leading icon `stone`, `titleS` title, optional `bodyS stone` subtitle, chevron |
| `TSMap` | MapLibre wrapper. Style: muted terrain basemap; trail route `pine` 3 pt over `snow` 5 pt casing; trailhead pin `pine`; member live dots `alpine`. Light + dark styles required |
| `ElevationProfileChart` | Area fill `pineTint`, line `pine` 2 pt, scrub handle `pine`; `accessibilityChartDescriptor` mandatory |

---

## 6. Motion

- Standard transitions: 0.25 s ease-out. Sheets/covers: system defaults.
- Celebration moments (verification success, hike complete): single confetti/checkmark burst ≤1.2 s — dignified, not slot-machine.
- Live indicators (in-progress pulse, live-location dot): 2 s gentle pulse loop.
- **Reduce Motion:** freeze loops, replace bursts with crossfade, keep all state changes visible statically.
- No parallax, no spring overshoot on safety-critical screens (check-in prompt appears instantly, no animation).

---

## 7. Voice in UI (summary — full copy in Workflow §3.3)

Capable, warm, direct. "Trail sisters", "hiking partners", "group hikes" — never "matches" as a noun, never dating vocabulary. Safety copy states limits plainly (coverage caveat). Empty states encourage, never guilt.

---

## 8. Accessibility Checklist (per screen, enforced in review)

- [ ] All interactive elements have VoiceOver labels (+ hints where non-obvious)
- [ ] Dynamic Type to accessibility XL without clipped/overlapping text
- [ ] Contrast AA for every text/fill pair (automated test for tokens; manual for imagery overlays)
- [ ] Touch targets ≥ 44×44 pt
- [ ] Reduce Motion path implemented
- [ ] Time-critical UI (check-in prompt) announced via `AccessibilityNotification.Announcement`
- [ ] Color never the sole signal (difficulty pills carry labels; status pills carry text)
