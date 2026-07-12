# CLAUDE.md

Guidance for working in the TrailSisters codebase. Read this first.

## What TrailSisters is

iOS app (SwiftUI, iOS 17+) where **verified women** find hiking partners for US
and Canadian national parks. Trip-based matching (park + overlapping dates),
group-first hikes (2–8), chat gated behind mutual connection, and a free safety
suite (check-in escalation, plan sharing, live location, offline safety cards).
Backend: Supabase (Postgres + PostGIS + RLS + Realtime + Edge Functions).
Identity: Stripe Identity (document + liveness) — **we never touch raw IDs**.
Free app, no monetization, iOS only.

## Source-of-truth documents (read before non-trivial work)

| Doc | Use it for |
|---|---|
| `TrailSisters_PRD_TechSpec.md` | Product requirements (§1–6), schema (§8), edge functions (§8.2), import pipeline (§10), compliance (§11), testing (§12) |
| `TrailSisters_App_Workflow.md` | Every screen (IDs like `S-VER-01`), journeys (`J-NN`), state machines (§3.1), gating table (§3.2), copy library (§3.3), phase-to-screen index (§3.6) |
| `TrailSisters_Development_Roadmap.md` | The 16 build phases in dependency order, with the tests each phase must ship |
| `DESIGN_SYSTEM.md` | Authoritative visual spec — tokens, components, motion, a11y |

Conflicts: **`DESIGN_SYSTEM.md` wins on visuals; the PRD wins on product
behavior.** Build phases in roadmap order — do not start Phase N+1 until
Phase N's four test sections are green.

## Non-negotiable invariants (PRD §2 — enforce in code, tests, and copy)

1. **Women-only.** Only verified, active women can see profiles, trips, hikes,
   or chat. Trans women are women; never auto-reject on an ID gender marker —
   ambiguity routes to `needs_review` for human review.
2. **Zero raw-ID storage.** The only verification fields anywhere are
   `stripe_verification_session_id`, `status` (`verification_status`),
   `verified_at`, `verification_failure_code`. No ID images, numbers, or
   biometric data in any table, bucket, or log — CI grep-audit enforces this;
   never weaken it.
3. **RLS before client code.** Every table gets RLS enabled and an RLS test
   before any client touches it. Clients read other users only via
   `public_profiles` (no DOB, phone_hash, or verification internals).
4. **Match before chat.** No messaging without an accepted connection or
   approved hike membership — RLS-enforced, RLS-tested.
5. **No swiping, no dating language.** List/card discovery with explicit
   buttons. Copy says "trail sisters", "hiking partners", "group hikes" —
   never hearts, flames, or "matches" as a noun. "Dating" must not appear in
   code comments, UI, or App Store metadata.
6. **Safety is never paywalled** and safety copy always states limits: check-in
   escalation depends on cell coverage and is not an emergency service. All
   safety SMS carry opt-out language. Enforcement never disables an in-flight
   safety plan.
7. **Privacy defaults.** Age as decade range, first names only, home region at
   city/state, GPS-derived data minimized; trusted contacts are typed in —
   **never request the Contacts permission**.
8. **Server-authoritative.** Trip windows, hike membership, verification and
   account status are enforced server-side (RLS + edge functions). Client
   checks are conveniences only.

When a product decision is ambiguous: **safety > privacy > growth**, in that
order (PRD §16.5). Flag—don't silently implement—anything needing paid services
beyond PRD §7's budget.

## Build & verify

Open `TrailSisters.xcodeproj` in Xcode 16+ (iOS 17 SDK). Prefer:

```bash
xcodebuild -project TrailSisters.xcodeproj -scheme TrailSisters \
  -destination 'generic/platform=iOS Simulator' build
```

Backend: `supabase start` for the local stack; `supabase db reset` applies all
migrations; the RLS test suite runs against local Supabase in CI and must pass
before any schema-touching PR. Edge functions: `supabase functions serve` +
Deno tests. Without full Xcode, type-check cross-platform Swift against the
macOS 14 SDK (strip `#Preview` blocks first) and say so when reporting
"verified" — that validates types, not layout/runtime.

## Code conventions

- **File header comment** on every file: what it is + the doc/section or screen
  ID it implements (e.g. `// S-TRIP-01 · Create Trip — Workflow Group F, PRD §3.5`).
- **SwiftUI + MVVM + async/await only.** No Combine unless a dependency forces it.
- **All server mutations through typed repository protocols** (PRD §9) —
  testability and future API swaps.
- **Design tokens, never literals:** `TSColor`, `.tsText(_:)`, `TSSpacing`,
  `TSRadius`, and the `TS*` component library. Off-scale values are bugs.
- **`#Preview` on every view** — light + dark, plus Dynamic Type XL for
  screens.
- Feature flags (`feature_flags` table) gate P1/P2 features and the
  verification kill-switch.
- Comment clearly and concisely — an amateur developer should be able to
  follow (PRD §16.4). Reference screens by workflow ID in comments and PRs.
- Migrations are append-only files under `supabase/migrations/`; every
  migration touching policies updates the RLS test suite in the same change.

## Gotchas

- **App Review:** women-only must be framed as a verified community under
  Guideline 1.2, with a documented review-bypass demo account for (possibly
  male) testers — keep the bypass feature-flagged and excluded from discovery.
- **Stripe Identity:** configure minimum data retention; the redaction cron
  (P1) must not run before a decision is 30 days old. The `needs_review` admin
  queue links into Stripe's dashboard — never render ID data in ours.
- **Background location** only during a user-started hike with an explicit
  purpose string; time-sensitive notifications only for safety check-ins.
- **Check-in escalation is server-side** (`safety-escalation-cron`, 5-min
  scan) — never rely on the client being alive. Offline "I'm safe" must
  reconcile (send all-clear if the cron already escalated).
- Overlap matching must stay index-backed (`trips_overlap_idx`): <200 ms at
  5k trips/park is an acceptance criterion, tested.
- Trail data carries license attribution (NPS public domain courtesy line,
  Parks Canada OGL, OSM ODbL) — keep `attribution` populated and rendered.

## Project skills

- `ts-screen` — implement a screen from the `TrailSisters_App_Workflow.md`
  catalog, wired to the design system and gating rules.
- `ts-component` — add or change a `Core/DesignSystem` component honoring
  `DESIGN_SYSTEM.md` tokens.
- `ts-backend` — schema/RLS/edge-function/cron work on Supabase with the
  mandatory RLS-test and no-raw-ID discipline.
