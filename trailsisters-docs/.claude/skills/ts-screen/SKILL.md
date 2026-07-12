---
name: ts-screen
description: Implement or update a screen in the TrailSisters iOS app from the TrailSisters_App_Workflow.md catalog (screens identified like S-HOME-01, S-VER-01, S-HIKE-05). Use when building any app screen, view, or flow — onboarding, auth, verification, profile wizard, home, explore, trips, hikes, chat, safety suite, settings, moderation. Wires the screen to the TS design system and enforces gating, privacy, and brand-voice rules.
---

# Implementing a TrailSisters screen

Build a screen that matches its spec in `TrailSisters_App_Workflow.md` exactly,
using the existing design system. Do not invent layout, copy, or colors.

## 1. Gather the spec (before writing code)

1. Find the screen entry in Workflow Part 1 by its ID (e.g. `S-TRIP-01`). Read
   the full entry: Purpose, Entry/Exit points, Layout, Components, **Copy**
   (exact strings), States, Interactions, Transitions, Edge cases,
   Accessibility, Persistence, **Gating**.
2. Read the matching journeys in Part 2 and the relevant state machine in §3.1.
3. Check the gating row in §3.2 (guest / verified / warned / suspended /
   banned) — gating is enforced by RLS server-side; the screen must also
   degrade gracefully client-side (empty states, `S-EXP-05` gate sheet).
4. Check the roadmap phase (§3.6 index) so you build only what the current
   phase needs — stub later-phase sections exactly as the entry says.
5. If the spec is ambiguous or conflicts with a doc, resolve by
   **safety > privacy > growth** (PRD §16.5) — and say you did.

## 2. Build it

- **Location:** `Features/<FeatureName>/<ScreenName>View.swift` per PRD §9
  folder map, with a ViewModel (`@Observable`, async/await) beside it when the
  screen has server state.
- **Use the design system — never raw values:** `TSColor`, `.tsText(_:)`,
  `TSSpacing`, `TSRadius`, and `TS*` components (`TSPrimaryButton`, `TSCard`,
  `TSAvatar`+`VerifiedBadge`, `TSEmptyState`, `TSChip`, `TSStatusPill`, …).
- **Copy:** exact strings from the entry's Copy section / §3.3 library. Voice:
  capable outdoorswoman — never dating language, no hearts/flames, no guilt.
  Safety copy must keep the coverage caveat verbatim and untruncated.
- **States:** implement every listed state — loading, empty (always with an
  action), error, offline, moderation-pending, gated. No happy-path-only PRs.
- **No swipe gestures** in matching/discovery UI. Explicit buttons only.
- **Data access:** through the typed repository protocols; other users only
  via `public_profiles`-backed models (never a raw `profiles` select).
- **Privacy in render:** age as decade range, first names only, region at
  city/state. If a sensitive field would be needed, the design is wrong — stop.
- **Accessibility:** Dynamic Type to XL, VoiceOver labels/hints, 44×44
  targets, Reduce Motion path — per the entry's Accessibility section and
  DESIGN_SYSTEM §8 checklist.
- **File header comment:** screen name + workflow ID + phase.
- **`#Preview`s** for the key states, light + dark.

## 3. Wire it (only what the spec calls for)

- Navigation per Entry/Exit points and the deep-link table (Workflow §0.3).
- Realtime subscriptions only where the entry names them (thread, hike,
  own-status channels).
- Analytics events named in the roadmap phase (PRD §13 — no PII in payloads).

## 4. Verify

- Add/extend the tests the roadmap phase lists for this screen (route tests,
  RLS-affecting flows, snapshot for major pages).
- Build; run unit tests; for RLS-touching features run the local Supabase
  suite. Report honestly what was and wasn't verified.
