# TrailSisters — App Workflow Specification

*Companion to `TrailSisters_PRD_TechSpec.md` (PRD + Tech Spec, cited as "PRD §n"), `TrailSisters_Development_Roadmap.md`, and `DESIGN_SYSTEM.md`.*

This document enumerates **every screen, every component, every state, every interaction, and every navigation path** in TrailSisters v1.0 (P0 scope, with P1 screens marked). It is written to be fed page-by-page into an AI coding assistant alongside the roadmap, so each phase can be implemented without re-deriving UX decisions.

---

## How to Use This Document

1. **Per-phase builds.** Open the Phase-to-Screen Index (§3.6) and pull only the screens flagged for the phase you're building. Feed those screens (Part 1) + the relevant journeys (Part 2) + the relevant cross-cutting refs (Part 3) into the AI session, together with `CLAUDE.md`.
2. **Reference, don't duplicate.** Thresholds, schema, API contracts, and copy invariants live in the PRD. This document points at them; it never re-states data-model details.
3. **Treat screen IDs as stable.** `S-VER-01` is the verification intro forever. Renaming requires updating every reference.
4. **Copy strings are normative.** All quoted user-facing text in this doc is v1.0 copy. `Localizable.strings` keys mirror the screen IDs. All copy must read as **activity-partner finding, never dating** (PRD §2.5, §4) — no hearts, no "matches made", no swipe language.
5. **Annotations.** `[P0]` / `[P1]` mark PRD priority. `[Phase N]` marks the roadmap phase that introduces the screen. `[Guest-visible]` marks the few screens an unverified account may see.

---

## Conventions

| Notation | Meaning |
|---|---|
| `S-XXX-NN` | iOS screen identifier (Part 1) |
| `W-XXX-NN` | Public web page identifier (no login; served by edge function/Worker) |
| `A-ADM-NN` | Internal admin-dashboard page (web; Appendix A) |
| `J-NN` | End-to-end user journey (Part 2) |
| `[Phase N]` | Introduced or substantively modified in Roadmap Phase N |
| `→ S-XXX-NN` | Navigates to that screen |
| `⤴ S-XXX-NN` | Returns to that screen |
| `❶ … ❷ …` | Numbered step in a journey |
| `↻` | Recurring/automatic server action (cron, webhook) |

---

## Glossary

- **Verified** — the account passed Stripe Identity document + liveness check (PRD §6). Only verified, active women can see profiles, trips, hikes, or chat.
- **Guest preview** — a signed-in but unverified account browsing parks/trails read-only. Never sees any user content.
- **Trip** — "I will be at [park] from [start] to [end]" — the matching object (PRD §3.5).
- **Hike** — a concrete plan: trail + date + start time + group of 2–8 (PRD §3.6).
- **Connection** — mutual link created by an accepted trip-match request; gates 1:1 chat (PRD §2.4).
- **Safety plan** — the per-hike record driving plan-share, check-in escalation, and live share (PRD §3.8, schema `safety_plans`).
- **Trusted contact** — manually entered name + phone (max 3); receives SMS links. Never sourced from the Contacts API.
- **Overlap** — another verified woman's active trip at the same park with ≥1 shared day.
- **Flagship parks** — launch-focus five: Zion, Yosemite, Glacier, Grand Canyon, Banff (PRD §10.4).
- **needs_review** — verification outcome routed to a human admin under the trans-inclusive policy (PRD §6.4); never auto-rejected on ID gender marker.

---

# Part 0 — Foundations

## 0.1 Navigation Model

```
TrailSistersApp (@main)
└── AppRouter (top-level route state)
    ├── Splash (first frame only, < 200ms)                    S-ONB-01
    ├── OnboardingHost (full-screen, replaces root)
    │   ├── Value carousel (3 pages)                          S-ONB-02…04
    │   ├── Auth (Apple / email)                              S-AUTH-01…02
    │   ├── Legal acceptance                                  S-LEGAL-01
    │   ├── Age gate (DOB)                                    S-AGE-01
    │   ├── Phone + OTP                                       S-AUTH-03…04
    │   ├── Verification                                      S-VER-01…05
    │   └── Profile wizard                                    S-PROF-01…06
    └── MainTabView (5 tabs, permanent once reached)
        ├── Home     (NavigationStack)                        S-HOME-*
        ├── Explore  (NavigationStack)                        S-EXP-*
        ├── Plan     (hub; pushes create flows)               S-PLAN-*, S-TRIP-*, S-HIKE-*
        ├── Chats    (NavigationStack)                        S-CHAT-*
        └── Profile  (NavigationStack)                        S-ME-*, S-SAFE-*
            ├── .sheet            ← Report, Say hi, Join request, Share plan
            ├── .fullScreenCover  ← Stripe Identity sheet, Active hike mode,
            │                        Account deletion, Suspended/banned interstitial
            └── .overlay          ← Toasts, check-in prompt banner
```

- **Onboarding is resumable, not sticky.** `AppRouter` derives the route from server state on every cold launch (see 0.2): a user who quit at OTP resumes at OTP; a `pending` verification resumes at `S-VER-03`. Nothing about progression is trusted client-side (PRD §2.8).
- **Tab bar is permanent** once the user is verified with a complete-enough profile (required fields done). Modals cover the tab bar, never replace it.
- **Guest preview** mounts `MainTabView` with only **Explore** fully functional; Home/Plan/Chats show verify-gate empty states (`S-EXP-05` pattern) and Profile shows setup status.
- **Stripe Identity, active-hike mode, deletion, and ban interstitials are full-screen covers** — weighty, uninterruptable. `.sheet` is reserved for non-blocking compose/detail actions.
- **No swipe gestures anywhere in matching UI** (PRD §2.5). Carousels page by tap/swipe only in onboarding.

## 0.2 Cold-Launch Route Table

Evaluated top-to-bottom on every cold launch (server state wins over cache):

| # | Condition (server-authoritative) | Route |
|---|---|---|
| 1 | No Supabase session | `S-ONB-02` (first run) or `S-AUTH-01` (returning) |
| 2 | Session, ToS version not accepted | `S-LEGAL-01` |
| 3 | Session, no DOB on record | `S-AGE-01` |
| 4 | DOB < 18 years | Block + delete flow (`S-AGE-01` error state) |
| 5 | Phone not confirmed | `S-AUTH-03` |
| 6 | `verification_status = unverified` | `S-VER-01` |
| 7 | `verification_status = pending` | `S-VER-03` |
| 8 | `verification_status = failed` | `S-VER-04` |
| 9 | `verification_status = needs_review` | `S-VER-05` |
| 10 | `account_status = suspended` | `S-MOD-03` (suspended variant) |
| 11 | `account_status = banned` | `S-MOD-03` (banned variant; session killed ≤60 s) |
| 12 | Required profile fields incomplete | `S-PROF-01` (resume at first incomplete step) |
| 13 | Active safety plan past `expected_return_at` | MainTab + check-in prompt overlay (`S-SAFE-04`) |
| 14 | Otherwise | MainTab → Home (`S-HOME-01`) |

Guest preview is entered *from* `S-VER-01` ("Browse parks first") and re-checks rows 6–9 whenever the user taps any gated action.

## 0.3 Deep-Link & Push Routing

URL scheme `trailsisters://` + Universal Links. Push payloads carry `kind` + target id (PRD §3.11).

| Link / push kind | Route |
|---|---|
| `match_request` | `S-HOME-02` (requests inbox) |
| `match_accepted` | `S-CHAT-02` (the new DM thread) |
| `hike_join_request` | `S-HIKE-03` (host view, members section) |
| `hike_approved` / `hike_updated` / `hike_cancelled` | `S-HIKE-02` |
| `hike_reminder` (T-24h / T-2h) | `S-HIKE-02` |
| `message` | `S-CHAT-02` (thread) |
| `trip_nudge` (T-14/5/2d) | `S-TRIP-03` (own trip, overlaps list) |
| `safety_checkin` (time-sensitive) | `S-SAFE-04` prompt (also actionable from lock screen: "I'm safe") |
| `moderation_outcome` | `S-NOTIF-01` |
| `trailsisters://trail/{id}` | `S-EXP-03` |
| `trailsisters://hike/{id}` | `S-HIKE-02` (RLS decides what's visible) |

All deep links re-run the route table first — an unverified or banned user never lands past the gate.

## 0.4 Design Primitives (reference only)

Defined in `DESIGN_SYSTEM.md`; the catalog references them by name: `TSPrimaryButton`, `TSSecondaryButton`, `TSDestructiveButton`, `TSCard`, `TSAvatar` (always renders `VerifiedBadge` overlay), `TSBadge` (capability badges: WFR, satellite, host), `TSChip`, `TSEmptyState` (icon + line + action button — every empty state proposes an action, PRD §4), `TSDifficultyPill`, `TSBanner` (AQI/alert), `TSToast`, `TSListRow`, `TSSegment`, `TSMap` (MapLibre wrapper), `ElevationProfileChart`, `TSStatTile`.

State machines for verification, trips, hikes, membership, safety plans, and moderation are normative in §3.1.

---
# Part 1 — Screen Catalog

## Group A — Onboarding, Auth & Legal

### S-ONB-01 · Splash / First-Launch Router · [Phase 0, wired Phase 4]

**Purpose.** Near-instant routing frame that evaluates the cold-launch route table (0.2). Never shown > ~200 ms.

**Entry points.** App cold launch (always).

**Exit points.** Any row of the route table.

**Layout.** Full-screen `parchment` background; centered wordmark "TrailSisters" with the mountain-ridge logotype mark above it.

**Components.** Logotype asset, wordmark in `TSTextStyle.displayL`.

**Copy.** Wordmark only.

**States.** Single. If session refresh takes > 300 ms, show a subtle progress indicator below the wordmark; never block > 3 s — fall back to cached route with a background re-check.

**Interactions.** None.

**Transitions.** Crossfade (0.25 s) into destination.

**Edge cases.** Offline cold launch with a cached verified session → route to MainTab from cache, re-validate when connectivity returns; a suspension/ban discovered on re-validation immediately presents `S-MOD-03`.

**Accessibility.** `accessibilityLabel("TrailSisters is starting")`; skipped by VoiceOver if route resolves < 100 ms.

**Persistence.** Reads cached session + cached `verification_status`/`account_status`.

**Gating.** N/A.

---

### S-ONB-02 · Value Carousel 1: "Find your trail sisters" · [Phase 4]

**Purpose.** Introduce the core promise: hiking partners for the parks you're going to.

**Entry points.** ← `S-ONB-01` first run.

**Exit points.** Swipe/“Next” → `S-ONB-03`. "Sign in" (returning users) → `S-AUTH-01`.

**Layout.** Full-bleed illustration (two women on a ridgeline trail, warm dawn palette — photographic or flat illustration, zero romance visual language), title + body in lower third, page dots, `TSPrimaryButton` "Next", text button "I already have an account".

**Components.** `TSPrimaryButton`, `PageIndicator` (3 dots).

**Copy.**
- Title: **"Find your trail sisters."**
- Body: *"Post the park and dates of your next trip, and meet verified women who'll be on the same trails at the same time."*

**States.** Single.

**Interactions.** Swipe or Next advances. Carousel is the only swipeable surface in the app.

**Transitions.** `TabView(.page)` slide.

**Edge cases.** None.

**Accessibility.** Illustration `accessibilityHidden(true)`; title + body read as the page.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-03 · Value Carousel 2: "Verified women only" · [Phase 4]

**Purpose.** Communicate trust pillar #1 (PRD §4: must land in ≤2 screens): every member is a verified woman, and we never store IDs.

**Entry points.** ← `S-ONB-02`.

**Exit points.** → `S-ONB-04`. ← back-swipe.

**Layout.** Centered `VerifiedBadge` motif at 96 pt over a soft card stack of anonymized profile silhouettes; title + body; page dots; "Next".

**Components.** `VerifiedBadge` (large), `TSCard`, `TSPrimaryButton`.

**Copy.**
- Title: **"Every member is a verified woman."**
- Body: *"Each account passes a government-ID and live selfie check, handled by a secure third party. Your ID is never stored by TrailSisters — we only ever see the result."*

**States.** Single.

**Interactions.** Swipe/Next.

**Transitions.** Page slide.

**Edge cases.** None.

**Accessibility.** Badge motif hidden from VoiceOver; copy read in full — this is the trust-critical sentence, don't truncate.

**Persistence.** None.

**Gating.** N/A.

---

### S-ONB-04 · Value Carousel 3: "Safety built in" · [Phase 4]

**Purpose.** Trust pillar #2: the free safety suite.

**Entry points.** ← `S-ONB-03`.

**Exit points.** "Get started" → `S-AUTH-01`.

**Layout.** Illustration of the check-in timer + share-plan cards; title + body; page dots; `TSPrimaryButton` "Get started".

**Components.** `TSPrimaryButton`, illustration.

**Copy.**
- Title: **"Safety is built in — and always free."**
- Body: *"Share your hike plan with trusted contacts, set a check-in timer, and share live location with your group. No paywalls on safety, ever."*

**States.** Single.

**Interactions.** Get started → auth.

**Transitions.** Page slide in; push to `S-AUTH-01`.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None.

**Gating.** N/A.

---

### S-AUTH-01 · Sign In / Create Account · [Phase 4]

**Purpose.** Primary auth choice. Sign in with Apple is the visually primary CTA (required — PRD §3.1, §11).

**Entry points.** ← `S-ONB-04` · ← `S-ONB-02` "I already have an account" · cold-launch row 1.

**Exit points.** Apple success → `S-LEGAL-01` (new) or route table (returning) · "Continue with email" → `S-AUTH-02`.

**Layout.** Wordmark top third; `SignInWithAppleButton` (black, full width) as the first button; `TSSecondaryButton` "Continue with email" below; legal footnote linking Terms + Privacy (read-only preview; acceptance happens at `S-LEGAL-01`).

**Components.** `SignInWithAppleButton`, `TSSecondaryButton`.

**Copy.**
- Header: **"Welcome to TrailSisters"**
- Sub: *"A community of verified women who hike together."*
- Footnote: *"By continuing you'll be asked to accept our Terms of Service and Privacy Policy."*

**States.** Default · Apple-auth in flight (button spinner, others disabled) · error toast on failure.

**Interactions.** Apple → ASAuthorization flow → Supabase `signInWithIdToken`. Email → `S-AUTH-02`.

**Transitions.** Push.

**Edge cases.** Apple credential revoked → treat as signed out, show toast *"Apple sign-in was cancelled or revoked. Try again or use email."* Duplicate email between Apple/email providers → Supabase account-linking rules; surface *"That email is already registered — sign in with the method you used before."*

**Accessibility.** Buttons ≥ 44 pt; VoiceOver announces Apple button per HIG.

**Persistence.** Supabase session on success.

**Gating.** N/A.

---

### S-AUTH-02 · Email Sign Up / Sign In · [Phase 4]

**Purpose.** Secondary email/password path with mode toggle.

**Entry points.** ← `S-AUTH-01`.

**Exit points.** Success → `S-LEGAL-01` (new) or route table (returning) · "Forgot password" → reset email sheet · ⤴ `S-AUTH-01`.

**Layout.** Segmented "Create account / Sign in", email + password fields, primary button, forgot-password text button (sign-in mode only).

**Components.** `TSSegment`, `TSTextField` (email, password w/ reveal), `TSPrimaryButton`.

**Copy.** Errors: *"That doesn't look like an email address."* · *"Password needs at least 10 characters."* · *"Email or password didn't match."* Reset sheet confirmation: *"Check your inbox — we sent a reset link."*

**States.** Default · validating (inline) · submitting · error banner · reset-sent toast.

**Interactions.** Submit → Supabase email auth. Password field uses `.newPassword`/`.password` text-content types for keychain integration.

**Transitions.** Push/pop.

**Edge cases.** Unconfirmed email (if confirmation enabled) → *"Confirm your email first — link resent."* Rate-limited → *"Too many tries. Wait a minute and try again."*

**Accessibility.** Errors announced via `AccessibilityNotification.Announcement`.

**Persistence.** Session on success.

**Gating.** N/A.

---

### S-LEGAL-01 · Terms, Risk & Community Agreement · [Phase 4]

**Purpose.** Versioned acceptance of ToS (incl. assumption of risk, arbitration, class-action waiver — content from lawyer, PRD §5) plus the zero-tolerance community pledge (App Store 1.2).

**Entry points.** ← auth success (new account) · cold-launch row 2 whenever `accepted_tos_version < current` (re-prompt on changes).

**Exit points.** Accept → `S-AGE-01` (new) or prior location (re-prompt) · Decline → signed out to `S-AUTH-01`.

**Layout.** Scrollable summary card with the three key points as checklist rows (community rules; assumption of outdoor risk; ID verification by third party), links to full Terms + Privacy in an in-app browser, single checkbox "I agree to the Terms of Service and community guidelines", `TSPrimaryButton` "Agree and continue" (disabled until checked), text button "Decline".

**Components.** `TSCard`, `TSCheckboxRow`, `TSPrimaryButton`.

**Copy.**
- Header: **"Our agreement"**
- Rows: *"Zero tolerance for harassment, impersonation, or objectionable content — accounts are removed."* · *"Hiking has inherent risks. You're responsible for your own safety decisions."* · *"Identity checks are performed by a secure third party. TrailSisters never stores your ID."*
- Decline confirm: *"You can't use TrailSisters without agreeing. Sign out?"*

**States.** Unchecked (CTA disabled) · checked · submitting · re-prompt variant (header: **"We've updated our terms"** + diff summary line).

**Interactions.** Accept writes `accepted_tos_version` + timestamp server-side.

**Transitions.** Push.

**Edge cases.** Server write fails → keep user on screen with retry toast; never proceed on client-only acceptance.

**Accessibility.** Checkbox is a real toggle with label; links focusable.

**Persistence.** `profiles.accepted_tos_version` (server; add to schema in Phase 0).

**Gating.** Blocks everything until accepted.

---

### S-AGE-01 · Date-of-Birth Gate (18+) · [Phase 4]

**Purpose.** Enforce 18+ (PRD §3.1, §5). DOB also feeds the age-range display (never shown raw).

**Entry points.** ← `S-LEGAL-01` · cold-launch row 3.

**Exit points.** ≥18 → `S-AUTH-03` · <18 → blocked error state → account deletion.

**Layout.** Title, wheel-style date picker (default ~25 years back), privacy note, `TSPrimaryButton` "Continue".

**Components.** `DatePicker(.wheel)`, `TSPrimaryButton`.

**Copy.**
- Title: **"When were you born?"**
- Note: *"Your exact birthday is never shown. Other members only see an age range, like '30s'."*
- Under-18 block: **"TrailSisters is for adults 18+."** *"Your account and data will be deleted."* Button: "Delete my account".

**States.** Default · under-18 blocked (destructive path only) · submitting.

**Interactions.** Continue writes DOB server-side; server validates ≥18 (client check is a convenience only, PRD §2.8).

**Transitions.** Push.

**Edge cases.** DOB is immutable after set (support-only edits); attempting a second write is rejected server-side.

**Accessibility.** Picker adjustable via VoiceOver rotor.

**Persistence.** `profiles.date_of_birth` (server).

**Gating.** Blocks progression.

---

### S-AUTH-03 · Phone Number Entry · [Phase 4]

**Purpose.** Bot gate + one-account-per-number (PRD §3.1, §6 anti-catfish). Required before verification spend.

**Entry points.** ← `S-AGE-01` · cold-launch row 5.

**Exit points.** → `S-AUTH-04` (OTP sent) · ⤴ back.

**Layout.** Title, country-code selector (US/CA prominent) + phone field, note, `TSPrimaryButton` "Send code".

**Components.** `TSTextField` (phone pad), country selector, `TSPrimaryButton`.

**Copy.**
- Title: **"Verify your phone"**
- Note: *"One account per number — it keeps the community real. We never show your number to anyone."*
- Error (in use): *"That number is already linked to another account. If it's yours, sign in to that account or contact support."*

**States.** Default · sending · sent (auto-advance) · error.

**Interactions.** Send → Supabase Auth phone provider (Twilio) OTP. Number normalized to E.164; server stores only `phone_hash` (sha256) for uniqueness (schema §8).

**Transitions.** Push to OTP.

**Edge cases.** VoIP/burner numbers rejected by Twilio lookup where enabled → same "can't use this number" error. Rate limit: 3 sends / 10 min.

**Accessibility.** Phone field `.telephoneNumber` content type.

**Persistence.** `phone_hash` server-side on confirm (never raw number in `profiles`).

**Gating.** Blocks verification step.

---

### S-AUTH-04 · SMS Code Entry · [Phase 4]

**Purpose.** Confirm OTP.

**Entry points.** ← `S-AUTH-03`.

**Exit points.** Success → `S-VER-01` · "Change number" ⤴ `S-AUTH-03`.

**Layout.** Six-box OTP field (auto-fill from Messages via `.oneTimeCode`), resend timer text, "Change number" text button.

**Components.** `TSOTPField`, `TSPrimaryButton` (auto-submits on 6th digit).

**Copy.**
- Title: **"Enter the 6-digit code"**
- Sub: *"Sent to {masked number}"*
- Resend: *"Resend code"* (enabled after 30 s: *"Resend in {n}s"*)
- Error: *"That code didn't match. Try again."* · Expired: *"Code expired — we sent a new one."*

**States.** Entry · verifying · error (boxes shake, clear) · resend cooldown.

**Interactions.** Auto-fill, auto-submit, resend.

**Transitions.** Push to `S-VER-01` with a brief success check animation.

**Edge cases.** 5 failed attempts → force resend + 60 s lockout.

**Accessibility.** OTP boxes exposed as a single text field to VoiceOver.

**Persistence.** Phone confirmed flag server-side.

**Gating.** Blocks verification step.

---

## Group B — Identity Verification (PRD §6)

### S-VER-01 · Verification Intro · [Phase 5] [Guest-visible]

**Purpose.** Explain the ID + liveness check, the no-storage promise, and the trans-inclusive policy; entry to the Stripe sheet; offers guest preview.

**Entry points.** ← `S-AUTH-04` · cold-launch row 6 · any gated action tapped in guest preview.

**Exit points.** "Verify now" → `S-VER-02` · "Browse parks first" → MainTab in guest preview (Explore only) · Help Center link (in-app browser).

**Layout.** Large `VerifiedBadge` motif; three checklist rows (government ID · live selfie check · result only, never your ID); policy line with Help Center link; `TSPrimaryButton` "Verify now — about 2 minutes"; `TSSecondaryButton` "Browse parks first".

**Components.** `VerifiedBadge`, `TSCard` checklist, buttons.

**Copy.**
- Title: **"One quick check, one safe community"**
- Rows: *"Scan your government ID"* · *"Take a short live selfie — like Face ID"* · *"Stripe handles the check. TrailSisters never sees or stores your ID."*
- Policy: *"Trans women are women and are welcome here. If the automated check can't confirm your account, a human reviews it under our inclusive policy — you won't be rejected because of the marker on your ID."*
- Guest note under secondary button: *"You can browse parks and trails now. You'll need to verify to see members, trips, or hikes."*

**States.** Default · verification kill-switch ON (feature flag, PRD §6 cost control): primary button replaced by *"Verifications are briefly paused — we'll notify you the moment yours can start."* + notify-me toggle.

**Interactions.** Verify now → create session (S-VER-02). Browse parks first → guest preview.

**Transitions.** Push / root swap to MainTab (guest).

**Edge cases.** Re-verification requested by admin (PRD §3.2) reuses this screen with header **"Please re-verify your account"** and no guest option.

**Accessibility.** Checklist rows read as one list; policy line must be reachable (not truncated).

**Persistence.** None client-side.

**Gating.** Entry gate to the entire social product.

---

### S-VER-02 · Stripe Identity Sheet (hosted) · [Phase 5]

**Purpose.** Run Stripe Identity's native document + liveness flow. We build only the wrapper.

**Entry points.** ← `S-VER-01` "Verify now".

**Exit points.** Sheet completes/cancels → `S-VER-03` (submitted) or ⤴ `S-VER-01` (cancelled).

**Layout.** Loading interstitial ("Connecting to Stripe…") then Stripe's `IdentityVerificationSheet` (full-screen). No custom chrome over Stripe UI.

**Components.** `StripeIdentity.IdentityVerificationSheet`.

**Copy.** Interstitial: *"Opening secure verification…"* Failure to create session: *"Couldn't start verification. Check your connection and try again."*

**States.** Creating session (spinner) · Stripe sheet presented · create-session error.

**Interactions.** Client calls `POST /edge/create-verification-session`; edge function creates a VerificationSession with `require_matching_selfie: true, require_live_capture: true` (PRD §6.2) and returns the client secret; present sheet.

**Transitions.** Sheet dismissal → `S-VER-03` if `flowCompleted`, back otherwise.

**Edge cases.** Session creation must be idempotent per user (reuse an open session). Camera permission denied inside Stripe flow → Stripe handles; on return show hint *"Verification needs camera access — enable it in Settings."*

**Accessibility.** Stripe sheet's own; interstitial labeled.

**Persistence.** `stripe_verification_session_id` written server-side by the edge function. **Nothing else — no images, no numbers, no templates (PRD §2.2, §3.2 AC).**

**Gating.** N/A.

---

### S-VER-03 · Verification Pending · [Phase 5] [Guest-visible]

**Purpose.** Hold state while Stripe processes (usually seconds–minutes; webhook-driven).

**Entry points.** ← `S-VER-02` · cold-launch row 7.

**Exit points.** ↻ webhook flips status → auto-advance to `S-PROF-01` (verified) / `S-VER-04` (failed) / `S-VER-05` (needs_review) · "Browse parks while you wait" → guest preview.

**Layout.** Soft animated progress motif (slow pulse on the badge outline), title, body, secondary button to guest preview.

**Components.** Badge motif, `TSSecondaryButton`.

**Copy.**
- Title: **"Checking… this usually takes a minute"**
- Body: *"Stripe is confirming your ID and selfie. We'll notify you the moment it's done — you don't need to keep the app open."*

**States.** Pending (default) · long-running (>15 min): body adds *"Sometimes checks take a little longer. Hang tight — we'll ping you."*

**Interactions.** Realtime subscription on own profile `verification_status` + push fallback.

**Transitions.** Auto-advance with a short success/failure transition.

**Edge cases.** Status flips while app backgrounded → push notification (`verification` kind) routes correctly on tap.

**Accessibility.** Pulse respects Reduce Motion (static badge).

**Persistence.** None client-side.

**Gating.** Social product still locked.

---

### S-VER-04 · Verification Failed · [Phase 5]

**Purpose.** Explain failure kindly, offer retry.

**Entry points.** ↻ webhook `failed` · cold-launch row 8.

**Exit points.** "Try again" → `S-VER-02` (new session) · "Contact support" (mail link) · guest preview.

**Layout.** Neutral (not red-alarm) card with reason bucket, retry button, support link.

**Components.** `TSCard`, `TSPrimaryButton`, `TSSecondaryButton`.

**Copy.**
- Title: **"We couldn't verify that attempt"**
- Reason buckets (from `verification_failure_code`): document unreadable → *"Your ID photo was blurry or cropped. Good light and a dark background help."* · selfie mismatch → *"The selfie didn't match the ID photo clearly. Remove hats/glasses and try again."* · generic → *"Something didn't check out. You can try again — it's free for you."*
- Support: *"Questions? Our inclusive verification policy is in the Help Center, or write to support."*

**States.** Per reason bucket. After 3 failed attempts → retry button replaced by *"Let's sort this out together"* → support (prevents cost bleed + frustration).

**Interactions.** Retry creates a fresh Stripe session.

**Transitions.** Push.

**Edge cases.** None beyond attempt cap.

**Accessibility.** Reason text announced on appear.

**Persistence.** Attempt count server-side.

**Gating.** Social product locked.

---

### S-VER-05 · Human Review In Progress · [Phase 5] [Guest-visible]

**Purpose.** The `needs_review` state — warm, non-accusatory holding screen (trans-inclusive policy, PRD §6.4).

**Entry points.** ↻ webhook routes to `needs_review` · cold-launch row 9.

**Exit points.** ↻ admin decision → `S-PROF-01` (approved) or `S-VER-04`-style final decline · guest preview · Help Center link.

**Layout.** Calm card, timeline row ("Submitted → Human review → Decision"), guest-preview button.

**Components.** `TSCard`, timeline, `TSSecondaryButton`.

**Copy.**
- Title: **"A human is taking a look"**
- Body: *"The automated check couldn't finish on its own, so one of our team is reviewing your verification personally — usually within 24 hours. This is normal and doesn't mean anything is wrong."*
- Policy line: *"Trans women are women. Reviews follow our inclusive policy — read it in the Help Center."*

**States.** Waiting · >24 h variant adds *"Taking longer than we'd like — thanks for your patience. Support can help if you're stuck."*

**Interactions.** Realtime/push on decision.

**Transitions.** Auto-advance.

**Edge cases.** None.

**Accessibility.** Standard.

**Persistence.** None client-side.

**Gating.** Social product locked.

---
## Group C — Profile Setup Wizard (PRD §3.3)

Wizard shell: progress bar ("Step n of 6"), Back, and — on optional steps only — "Skip for now". Required steps cannot be skipped. Resume at first incomplete step (route table row 12). Every field writes through the typed repository; completeness recomputed server-side by trigger.

### S-PROF-01 · Wizard 1: The Basics · [Phase 6]

**Purpose.** Required identity basics.

**Entry points.** ← verification success · route table row 12.

**Exit points.** → `S-PROF-02`.

**Layout.** Fields: first name · pronouns (optional selector: she/her, they/them, custom, "prefer not to show") · home region (city/state autocomplete, stored as text at city/state granularity only).

**Components.** `TSTextField`, `TSChip` selector, region autocomplete.

**Copy.**
- Title: **"Let's set up your profile"**
- Privacy note: *"Only your first name is ever shown. Your home region appears as city + state — never an exact location."* (PRD §2.7)

**States.** Default · invalid (empty first name).

**Interactions.** Continue validates + saves.

**Edge cases.** Emoji/whitespace-only names rejected: *"Enter your real first name — it's what your trail sisters will call you."*

**Accessibility.** Labels + hints on all fields.

**Persistence.** `profiles.first_name`, `pronouns`, `home_region`.

**Gating.** Required.

---

### S-PROF-02 · Wizard 2: How You Hike · [Phase 6]

**Purpose.** Required capability fields — the matching substrate (capability-first, not dating, PRD §3.3).

**Entry points.** ← `S-PROF-01`.

**Exit points.** → `S-PROF-03` · ⤴ back.

**Layout.** Four single-select chip groups: Experience (Beginner / Intermediate / Advanced / Expert) · Typical pace (Casual <2 mph / Steady 2–3 mph / Fast 3+ mph) · Comfortable distance (<5 / 5–10 / 10–15 / 15+ mi) · Comfortable elevation gain (<1,000 / 1,000–2,500 / 2,500+ ft).

**Components.** `TSChipGroup` ×4.

**Copy.**
- Title: **"How do you like to hike?"**
- Sub: *"Honest answers make better hiking partners — there's no wrong level."*

**States.** Default · incomplete (CTA disabled until all four picked).

**Interactions.** Chip select; Continue saves.

**Edge cases.** None.

**Accessibility.** Chip groups as radio groups.

**Persistence.** `experience_level`, `pace`, `distance_comfort`, `elevation_comfort`.

**Gating.** Required.

---

### S-PROF-03 · Wizard 3: Trail Details (optional) · [Phase 6]

**Purpose.** Optional capability & logistics fields that power compatibility and badges.

**Entry points.** ← `S-PROF-02`.

**Exit points.** → `S-PROF-04` · "Skip for now".

**Layout.** Collapsible sections: Terrain experience (multi: scrambling, snow/microspikes, exposure/heights, river crossings, high altitude, desert) · Hike types (day hikes, backpacking, peak-bagging, trail running, photography walks, birding) · Start times (dawn/morning/afternoon/flexible) · Camping experience (none→expert) · Certifications & gear (first aid/WFR toggle → badge; satellite communicator toggle → badge; navigation confidence 1–5) · Logistics (has car / can drive to trailheads / open to carpool; brings a dog / dog-friendly) · Languages · Trail vibe (quiet/chatty/either; group size small 2–3 / medium 4–6 / any).

**Components.** `TSChipGroup`, `TSToggleRow`, `TSStepper`.

**Copy.** Title: **"The details that make a great group"** · Badge hint: *"Self-declared certifications show as badges on your profile."*

**States.** All optional.

**Interactions.** Save-on-continue.

**Edge cases.** None.

**Accessibility.** Sections are headers; VoiceOver jumps by rotor.

**Persistence.** Corresponding `profiles.*` optional columns (schema §8).

**Gating.** Optional.

---

### S-PROF-04 · Wizard 4: Photos · [Phase 6]

**Purpose.** Primary photo (face visible, required) + up to 5 more; on-device face check; moderation pipeline.

**Entry points.** ← `S-PROF-03`.

**Exit points.** → `S-PROF-05` (primary uploaded) · back.

**Layout.** 3×2 photo grid, slot 0 marked "Main photo — your face". Each slot: add via PhotosPicker/camera, delete, reorder by drag handle (not swipe).

**Components.** `TSPhotoGrid`, `PhotosPicker`.

**Copy.**
- Title: **"Add your photos"**
- Rules line: *"Your main photo must clearly show your face — it's part of keeping the community real. Photos are reviewed automatically before they're visible."*
- Face-check fail: *"We couldn't find a face in that photo. Pick one where your face is clearly visible."*
- Moderation-pending chip on slots: *"Reviewing…"* · rejected: *"Not approved — try another photo."*

**States.** Empty · uploading (progress ring per slot) · pending moderation · approved · rejected.

**Interactions.** On-device Vision face detection gates slot 0 before upload (PRD §6 anti-catfish). Upload → Storage → `moderate-media` hook → status via Realtime.

**Edge cases.** Offline: queue upload, allow continuing; slot shows "Waiting for connection". Oversized images downscaled client-side (max 2048 px).

**Accessibility.** Slots labeled "Photo 1 of 6, main photo" etc.

**Persistence.** `profile_photos` rows.

**Gating.** Primary photo required to finish wizard; others optional.

---

### S-PROF-05 · Wizard 5: Prompts · [Phase 6]

**Purpose.** Up to 3 short prompts (pick + answer) for texture without dating-style bios.

**Entry points.** ← `S-PROF-04`.

**Exit points.** → `S-PROF-06` · "Skip for now".

**Layout.** Three prompt cards; each opens a picker of prompt questions ("My most memorable hike…", "My ideal trail day…", "I'm working toward…", "The gear I never leave behind…", "My favorite park so far…") + 140-char answer field. Optional 500-char bio field below.

**Components.** `TSCard`, prompt picker sheet, `TSTextEditor` (counted).

**Copy.** Title: **"A little trail personality"** · Sub: *"Pick up to three prompts. Skip anything — you can add them later."*

**States.** 0–3 filled.

**Interactions.** Standard.

**Edge cases.** Profanity screen on save (server; borderline → moderation queue, not hard block).

**Accessibility.** Character count announced at 20 remaining.

**Persistence.** `profiles.prompts` (jsonb, max 3), `bio`.

**Gating.** Optional.

---

### S-PROF-06 · Wizard 6: Done + Completeness · [Phase 6]

**Purpose.** Celebrate, show completeness meter, explain the ≥80% ranking boost, hand off to Home.

**Entry points.** ← `S-PROF-05`.

**Exit points.** "Start exploring" → MainTab `S-HOME-01` · "Finish the last {n}%" → deep link to first incomplete optional section in `S-ME-02`.

**Layout.** Verified avatar preview (their photo + `VerifiedBadge`), completeness ring with %, checklist of missing optional items, primary CTA.

**Components.** `TSAvatar`, `TSProgressRing`, `TSListRow`, `TSPrimaryButton`.

**Copy.**
- Title: **"You're in, {first name} ☑"**
- Body: *"You're part of a community of verified women who hike together."*
- Meter hint: *"Profiles that are 80%+ complete rank higher when other members look for partners."* (PRD §3.3 AC)

**States.** <80% (checklist shown) · ≥80% ("Complete profile" label + subtle confetti, Reduce Motion-aware).

**Interactions.** CTA → Home.

**Edge cases.** None.

**Accessibility.** Ring value announced as percent.

**Persistence.** `profiles.completeness` (server-computed).

**Gating.** N/A.

---

## Group D — Home (feed)

### S-HOME-01 · Home Feed · [Phase 8, enriched 9, 12]

**Purpose.** The daily surface: your upcoming trips/hikes, date overlaps for your trips, pending requests, and suggestions. Answers "what's happening for me?"

**Entry points.** Tab 1 · route table row 14 · post-wizard.

**Exit points.** Overlap card → `S-USER-01` · trip card → `S-TRIP-03` · hike card → `S-HIKE-02`/`03` · requests row → `S-HOME-02` · bell icon → `S-NOTIF-01` · empty-state CTA → `S-TRIP-01`.

**Layout.** NavigationStack root, large title "Home", bell with unread badge. Sections (in order, hidden when empty):
1. **Needs your attention** — pending requests row ("{n} requests waiting") + safety prompts.
2. **Your next hike** — hero `HikeCard` (trail, date, group avatars, status pill).
3. **Your trips** — horizontal `TripCard`s with live overlap count ("4 women overlap").
4. **New overlaps for you** — vertical list of `OverlapCard`s (avatar + first name + age range + experience/pace chips + shared dates), sorted per PRD §3.5 (overlap length, then compatibility). Buttons: "Say hi" → `S-TRIP-04`; "Invite to my hike" (only if user hosts an open hike at that park) → invite variant of `S-TRIP-04`.
5. **Open group hikes at your parks** — `HikeCard`s for public hikes during the user's trip windows.

**Components.** `TSCard` variants (`TripCard`, `HikeCard`, `OverlapCard`), `TSAvatar`, `TSChip`, `TSEmptyState`.

**Copy.** Section headers as above. Overlap subtitle pattern: *"At {park} · {n} shared days ({Mon d}–{Mon d})"*.

**States.**
- Default (any sections present).
- **Empty (no trips)** — `TSEmptyState`: *"Where are you headed next?"* / *"Post a trip and we'll find verified women who'll be there when you are."* / button "Post a trip" → `S-TRIP-01`; secondary "Browse flagship parks" → `S-EXP-01` (PRD §3.5 AC: never a blank screen).
- **Trips but no overlaps** — trips section + *"No overlaps yet. Trips at {flagship park suggestions} match most often — and flexible dates help."*
- Loading skeletons · offline (cached content + stale banner).

**Interactions.** Pull-to-refresh. All cards tap-through. **No swipe actions.**

**Transitions.** Push.

**Edge cases.** Blocked users never appear (RLS). A card whose target was deleted/cancelled shows toast *"That's no longer available."* and refreshes.

**Accessibility.** Cards are single accessibility elements with composed labels ("Sarah, 30s, verified, Zion, 3 shared days, October 4 to 6").

**Persistence.** Feed cache (SwiftData) for offline render.

**Gating.** Verified only (guests routed per 0.2).

---

### S-HOME-02 · Requests Inbox · [Phase 8, 9]

**Purpose.** One place for incoming/outgoing trip-match requests ("Say hi") and hike join requests.

**Entry points.** ← `S-HOME-01` requests row · push `match_request` / `hike_join_request`.

**Exit points.** Accept trip request → new DM thread `S-CHAT-02` · approve hike request → `S-HIKE-03` · requester avatar → `S-USER-01`.

**Layout.** Segmented "Received / Sent". Rows: avatar + name + context line + note preview + [Accept]/[Decline] (trip) or [Approve]/[Decline] (hike).

**Components.** `TSSegment`, `TSListRow`, inline buttons.

**Copy.** Context lines: *"wants to say hi · your Zion trip, Oct 3–7"* · *"asked to join · Angels Landing, Oct 5"*. Decline confirm: *"Decline quietly? She won't be notified — the request just expires."* Accept toast: *"You're connected! Say hello 👋"* (no hearts, ever).

**States.** Default · empty (*"No requests right now. Overlaps show up on Home as your trip dates get closer."*) · acting (row spinner).

**Interactions.** Accept/decline are transactional; accept trip-match → server creates `connections` row + `dm` thread; approve hike member → membership `approved` + group-chat access (PRD §3.6 AC).

**Transitions.** Accept trip → push thread.

**Edge cases.** Request already withdrawn/expired → row dissolves with toast. Hike now full → approve fails with *"Your hike is full — remove someone first or raise the group size."*

**Accessibility.** Row buttons individually focusable.

**Persistence.** Server truth; badge counts via Realtime `user:{id}`.

**Gating.** Verified only.

---

## Group E — Explore (parks & trails) (PRD §3.4)

### S-EXP-01 · Explore Root: Parks · [Phase 7] [Guest-visible]

**Purpose.** Browse/search all US + Canadian national parks; map/list toggle; flagship parks first.

**Entry points.** Tab 2 · guest preview default tab · empty-state CTAs.

**Exit points.** Park → `S-EXP-02` · search result trail → `S-EXP-03`.

**Layout.** Search field ("Parks or trails"), map/list toggle. List: flagship section ("Great places to start") then A–Z by state/province with country section headers. Map: MapLibre with park centroids as markers, cluster on zoom-out. Each `ParkRow`: name, state/province, trail count, thumbnail.

**Components.** `TSMap`, `TSSearchField`, `ParkRow`, `TSSegment`.

**Copy.** Search placeholder: *"Search parks or trails"*. Flagship header: *"Great places to start"*.

**States.** List/map · searching (typeahead) · offline (cached parks + banner *"Offline — showing saved parks"*) · guest (identical; parks/trails are public content).

**Interactions.** Marker tap → park callout → park page. Search hits parks and trails.

**Transitions.** Push.

**Edge cases.** Location permission is NOT requested here (only for hike-day features) — sorting is alphabetical/flagship, not "near me" (PRD §1.2: park visitors aren't local).

**Accessibility.** Map has a "Browse as list" always available; markers labeled.

**Persistence.** Parks/trails cached in SwiftData on first load (bundled seed for flagship parks).

**Gating.** Public content — fully guest-visible.

---

### S-EXP-02 · Park Page · [Phase 7] [Guest-visible]

**Purpose.** One park: description, alerts, seasonal notes, and its trails.

**Entry points.** ← `S-EXP-01` · trip/hike cards' park links.

**Exit points.** Trail row → `S-EXP-03` · "Post a trip here" → `S-TRIP-01` (park pre-filled; guests hit verify gate `S-EXP-05`) · alert row → alert detail sheet.

**Layout.** Hero image/map header with park boundary; name + state; **NPS/Parks Canada alerts** banner list (collapsible); description; seasonal notes; trails list with `TSDifficultyPill`, length, gain; filter bar (difficulty, length, gain, dogs); sticky footer `TSPrimaryButton` "Post a trip here".

**Components.** `TSMap` (boundary), `TSBanner` (alerts), `TrailRow`, `TSDifficultyPill`, filter chips → `S-EXP-04`.

**Copy.** Alerts header: *"Park alerts"*. Attribution footer: *"Data: National Park Service"* / Parks Canada attribution (PRD §10).

**States.** Default · alerts-loading (park renders without blocking, PRD §3.9 AC) · offline (cached; alerts show *"Alerts unavailable offline"*).

**Interactions.** Filter chips modify trail list in place.

**Transitions.** Push.

**Edge cases.** Park with zero imported trails: *"Trail data for this park is coming soon."* + still allows trip posting.

**Accessibility.** Alerts announced as "warning" trait.

**Persistence.** Cached park + trails.

**Gating.** Guest-visible; "Post a trip here" gated.

---

### S-EXP-03 · Trail Page · [Phase 7; conditions section Phase 15] [Guest-visible]

**Purpose.** The full trail dossier (PRD §3.4): stats, map, elevation, weather/AQI/sun, permits, safety card, conditions (P1), and "Plan a hike here".

**Entry points.** ← `S-EXP-02` · search · hike cards · deep link `trailsisters://trail/{id}`.

**Exit points.** "Plan a hike here" → `S-HIKE-01` (trail pre-filled; guest → `S-EXP-05`) · "Offline safety card" → `S-SAFE-06` · permit link (in-app browser) · condition report (P1) → report composer.

**Layout.** Top → bottom:
1. Map header: route geometry drawn on `TSMap`, trailhead pin.
2. Title block: name, park, `TSDifficultyPill`, route type.
3. Stat row (`TSStatTile` ×4): length, elevation gain, est. duration (Naismith), difficulty score.
4. `ElevationProfileChart` (interactive scrub).
5. **Conditions & weather card:** current + 7-day (Open-Meteo), sunrise/sunset + golden hour (on-device solar math), AQI chip — banner variant when AQI > 100: *"Air quality is poor today (AQI {n}) — often wildfire smoke. Check alerts before you go."*
6. Trailhead card: coordinates (tap to copy / open in Maps), parking notes, permit flag + link.
7. Recent conditions (P1): tag chips + notes, newest first, 30-day window.
8. Sticky footer: `TSPrimaryButton` "Plan a hike here" · `TSSecondaryButton` "Save offline safety card".

**Components.** `TSMap`, `TSStatTile`, `ElevationProfileChart`, `TSBanner`, `TSCard`, `TSChip`.

**Copy.** Weather-stale label: *"Updated {n}h ago — forecast may have changed."* Permit row: *"Permit required — check availability"*.

**States.** Default · weather/AQI failed (card shows cached-with-stale-label or *"Forecast unavailable"* — page never blocks, PRD §3.9 AC) · offline (fully cached render if previously viewed, PRD §3.4 AC) · guest (identical minus gated CTAs).

**Interactions.** Scrub elevation chart (haptic ticks); stat tiles static; coordinate row copy/open-in-Maps.

**Transitions.** Push; safety card as sheet.

**Edge cases.** Missing elevation data (import gap) → hide chart, keep length. `dogs_allowed = null` renders "Dogs: unknown — check park rules".

**Accessibility.** Chart has audio-graph support via `accessibilityChartDescriptor`; stat tiles labeled with units.

**Persistence.** Full trail page cached on view (SwiftData) incl. last weather payload.

**Gating.** Guest-visible; "Plan a hike here" gated.

---

### S-EXP-04 · Trail Filters Sheet · [Phase 7] [Guest-visible]

**Purpose.** Filter a park's trail list (park, difficulty, length, gain, dogs — PRD §3.4).

**Entry points.** ← `S-EXP-02` filter bar.

**Exit points.** "Show {n} trails" ⤴ `S-EXP-02` · "Reset".

**Layout.** Medium-detent sheet: difficulty chips, length range slider (mi/km per locale), gain range slider, "Dogs allowed" toggle (tri-state: any/yes/no-where-known).

**Components.** `TSChipGroup`, `TSRangeSlider`, `TSToggleRow`, `TSPrimaryButton` (live count).

**Copy.** CTA: *"Show {n} trails"* · zero: *"No trails match — loosen a filter"* (CTA disabled).

**States.** Live-updating count.

**Interactions.** Filters apply on dismiss; persisted per park for the session.

**Edge cases.** None.

**Accessibility.** Sliders adjustable.

**Persistence.** In-memory.

**Gating.** Guest-visible.

---

### S-EXP-05 · Verify Gate Interstitial (guest) · [Phase 5] [Guest-visible]

**Purpose.** The single reusable gate shown when a guest taps any member-only action (post trip, plan hike, view members, chats tab, home tab).

**Entry points.** Any gated action in guest preview.

**Exit points.** "Verify now" → `S-VER-01`/`S-VER-02` (resumes wherever their verification state is) · "Not now" ⤴ dismiss.

**Layout.** Sheet: `VerifiedBadge` motif, one-liner, primary + dismiss.

**Components.** Sheet, `TSPrimaryButton`.

**Copy.**
- Title: **"Verify to join the community"**
- Body: *"Trips, hikes, and chats are for verified members — that's what keeps TrailSisters safe. It takes about 2 minutes."*
- Context variants: posting a trip → *"…so only verified women see your travel plans."*

**States.** Variants per verification state: unverified (verify CTA) · pending (*"Your check is still running — we'll notify you."*) · needs_review (*"A human is reviewing your verification."*) · failed (retry CTA).

**Interactions.** Single CTA.

**Transitions.** Sheet.

**Edge cases.** None.

**Accessibility.** Standard sheet.

**Persistence.** None.

**Gating.** Is the gate.

---
## Group F — Plan Tab & Trips (PRD §3.5)

### S-PLAN-01 · Plan Hub · [Phase 8, 9]

**Purpose.** The center tab: create a trip or hike, and manage your existing ones.

**Entry points.** Tab 3 (center, "+" styled).

**Exit points.** "Post a trip" → `S-TRIP-01` · "Plan a group hike" → `S-HIKE-01` · trip row → `S-TRIP-03` · hike row → `S-HIKE-02`/`03`.

**Layout.** Two large action cards on top ("Post a trip" with calendar-mountain icon; "Plan a group hike" with group icon), then "Your trips" (active, with overlap counts) and "Your hikes" (hosting + joined, status pills), then collapsed "Past" section.

**Components.** `TSCard` action variant, `TripCard`, `HikeCard`, `TSStatusPill`.

**Copy.** Action card subtitles: *"Tell verified women when you'll be at a park"* · *"Pick a trail, set a time, build your group"*. Empty: *"Nothing planned yet — where to next?"*

**States.** Default · empty · guest → `S-EXP-05`.

**Interactions.** Straight navigation.

**Transitions.** Push.

**Edge cases.** Archived/cancelled items only under "Past".

**Accessibility.** Action cards are buttons.

**Persistence.** Server truth + cache.

**Gating.** Verified only.

---

### S-TRIP-01 · Create Trip · [Phase 8]

**Purpose.** Post "I'll be at [park], [dates]" — the matching object.

**Entry points.** ← `S-PLAN-01` · Home empty state · `S-EXP-02` "Post a trip here" (park pre-filled).

**Exit points.** "Post trip" → `S-TRIP-03` (fresh trip, overlaps loading) · cancel confirm ⤴.

**Layout.** Single scrollable form:
1. Park picker (search sheet; pre-filled when launched from a park).
2. Date range (calendar range picker; max 12 months out; end ≥ start).
3. Intent note, optional, 280 chars ("What are you hoping for?").
4. Target trails, optional multi-select from the park's trails.
5. Visibility: "All verified women" (default) / "Women with similar experience" (PRD §3.5).
6. `TSPrimaryButton` "Post trip".

**Components.** Park search sheet, `TSCalendarRange`, `TSTextEditor`, trail multi-select, `TSSegment`.

**Copy.**
- Title: **"Post a trip"**
- Note placeholder: *"e.g. Solo trip, hoping to do Angels Landing and a couple of moderate day hikes. Happy to carpool from Springdale."*
- Visibility explainer: *"Similar experience = within one level of yours."*
- Success toast: *"Trip posted — we'll show you overlaps as they appear."*

**States.** Default · validating · submitting · error banner.

**Interactions.** Server validates dates (future, ≤12 mo, end≥start — PRD §2.8: server-authoritative).

**Transitions.** Push to trip detail on success.

**Edge cases.** Duplicate trip (same park, overlapping own dates) → warn *"You already have a trip at {park} covering these dates. Post anyway?"* Past dates rejected server-side.

**Accessibility.** Calendar range fully VoiceOver-operable.

**Persistence.** `trips` row; draft kept in memory on cancel-confirm decline.

**Gating.** Verified only.

---

### S-TRIP-02 · My Trips List · [Phase 8]

**Purpose.** All of the user's trips (active/archived/cancelled).

**Entry points.** ← `S-PLAN-01` "Your trips" see-all.

**Exit points.** Row → `S-TRIP-03`.

**Layout.** List of `TripCard`s: park, dates, overlap count, status pill. Past/cancelled collapsed.

**Components.** `TripCard`, `TSStatusPill`.

**Copy.** Archived auto-label: *"Ended {date}"*.

**States.** Default · empty (CTA "Post a trip").

**Interactions.** Tap-through only (**no swipe-to-delete**; deletion lives in `S-TRIP-03`).

**Edge cases.** Trips auto-archive after end date (↻ server) — list reflects on refresh.

**Accessibility.** Standard list.

**Persistence.** Cache.

**Gating.** Verified only.

---

### S-TRIP-03 · Trip Detail + Overlaps · [Phase 8]

**Purpose.** Own-trip hub: edit/cancel, and the ranked list of overlapping verified women.

**Entry points.** ← trip cards anywhere · push `trip_nudge`.

**Exit points.** Overlap card → `S-USER-01` · "Say hi" → `S-TRIP-04` · "Invite to my hike" → `S-TRIP-04` invite variant · Edit → `S-TRIP-01` in edit mode · park name → `S-EXP-02`.

**Layout.** Header card (park, dates, note, target trails chips, visibility, edit/cancel menu). Section **"Women who overlap"**: `OverlapCard` list sorted by overlap length then compatibility (PRD §3.5), each showing avatar (+`VerifiedBadge`), first name, age range, experience + pace chips, shared-days line, capability badges, and the two action buttons.

**Components.** `TSCard`, `OverlapCard`, `TSChip`, context menu.

**Copy.**
- Overlaps header: *"Women who overlap with your dates"*
- Empty overlaps: *"No overlaps yet. Most matches appear 2–6 weeks before a trip. Flagship parks like Zion and Banff match most — and flexible dates help."* + button "Adjust dates".
- Cancel confirm: *"Cancel this trip? Overlaps and pending requests will be withdrawn."*

**States.** Overlaps loaded · empty (never blank — PRD AC) · loading skeleton · archived trip (read-only, banner *"This trip has ended"*).

**Interactions.** Pull-to-refresh overlaps. "Invite to my hike" only visible if user hosts an `open` hike at this park.

**Transitions.** Push / sheets.

**Edge cases.** Overlap disappears (her trip cancelled/blocked) between render and tap → toast + refresh. Editing dates re-runs matching; note in edit mode: *"Changing dates updates your overlaps."*

**Accessibility.** Overlap cards composed labels as in `S-HOME-01`.

**Persistence.** Server; overlap list not cached beyond session (privacy).

**Gating.** Verified only; visibility respects `similar_experience` setting both directions.

---

### S-TRIP-04 · "Say Hi" / Invite Compose Sheet · [Phase 8, invite variant Phase 9]

**Purpose.** Send a trip-match request (optionally with a note), or invite her to one of your hikes.

**Entry points.** ← `OverlapCard` buttons (`S-HOME-01`, `S-TRIP-03`) · ← `S-USER-01` action bar.

**Exit points.** Send ⤴ with toast · cancel.

**Layout.** Sheet: her mini-profile row (avatar, name, shared-dates line), 280-char note field, send button. Invite variant adds a hike picker (your open hikes at that park) above the note.

**Components.** Sheet, `TSTextEditor`, `TSPrimaryButton`, hike picker rows.

**Copy.**
- Say-hi title: **"Say hi to {name}"** · placeholder: *"e.g. Hi! I'm doing Angels Landing on the 5th and looking for one more early starter."* · button "Send" · toast *"Sent! You'll hear back if she accepts."*
- Invite title: **"Invite {name} to your hike"** · button "Send invite".
- One-per-target rule error: *"You've already reached out for this trip."* (schema unique constraint)

**States.** Compose · sending · sent.

**Interactions.** Send creates `trip_match_requests` row (or hike invite = pre-approved join request flow). Note passes text moderation (borderline → queue, not blocked).

**Transitions.** Sheet dismiss + toast.

**Edge cases.** She blocked you between render and send → generic *"Couldn't send right now."* (never reveal blocks — PRD privacy).

**Accessibility.** Sheet titled; count announced.

**Persistence.** Server row.

**Gating.** Verified only; requires a qualifying overlap (server-enforced).

---

## Group G — Group Hikes (PRD §3.6)

### S-HIKE-01 · Create Hike · [Phase 9]

**Purpose.** Turn a trail + date + time into a joinable plan (2–8 women).

**Entry points.** ← `S-PLAN-01` · `S-EXP-03` "Plan a hike here" (trail pre-filled) · `S-TRIP-03` context.

**Exit points.** "Publish hike" → `S-HIKE-03` (host view) · save as draft ⤴.

**Layout.** Form:
1. Trail picker (park → trail; pre-filled from context) with mini trail stat row.
2. Date + start time (park's timezone shown explicitly: "8:00 AM — Zion time").
3. Group size limit stepper (2–8, **default 4**; UI nudges 3+ per PRD §2.3: sizes 2 shows hint *"Groups of 3+ tend to feel safest and are easiest to fill."*).
4. Pace + experience expectations (chips, defaults from host profile).
5. Meetup point: default chip "Trailhead" selected; free-text field appears if "Somewhere else" chosen, with nudge *"Meeting at the trailhead is the safest default."*
6. Description (1,000 chars).
7. Visibility: Public to verified women / Invite-only.
8. `TSPrimaryButton` "Publish hike" · text button "Save draft".

**Components.** Trail picker sheet, `DatePicker`, `TSStepper`, `TSChipGroup`, `TSTextEditor`, `TSSegment`.

**Copy.** Title: **"Plan a group hike"**. Timezone line always visible. Success toast: *"Hike published — you'll get requests as women find it."*

**States.** Default · draft (resumable from `S-PLAN-01`) · submitting · edit mode (title "Edit hike"; members notified on save — PRD §3.6).

**Interactions.** Server rejects past date/time in park tz (PRD AC). Estimated duration (from trail) shown to seed check-in defaults later.

**Transitions.** Push to host view.

**Edge cases.** Trail with permit flag → inline notice *"This trail requires a permit — every member needs her own."*

**Accessibility.** Stepper announces "Group size, 4 of 8 max".

**Persistence.** `hikes` row (status `draft`/`open`); host auto-inserted as `hike_members` role `host`.

**Gating.** Verified only.

---

### S-HIKE-02 · Hike Detail (member/requester view) · [Phase 9]

**Purpose.** The public face of a hike: what, when, who; request to join; member view adds group chat + day-of controls.

**Entry points.** ← Home/Explore/Plan cards · push `hike_approved`/`hike_updated`/`hike_reminder` · deep link.

**Exit points.** "Request to join" → `S-HIKE-04` · host/member avatars → `S-USER-01` · trail block → `S-EXP-03` · "Group chat" (members) → `S-CHAT-02` · "Start hike" (members, day-of) → `S-HIKE-05` · "Share my plan" (members) → `S-SAFE-03`.

**Layout.** Trail map header; title (trail + park); date/time (park tz) + countdown; status pill; host row (avatar + "Host" badge); stat row (length/gain/difficulty/est. duration); pace + experience expectation chips; meetup point card; description; **Group** section (approved member avatars, "{n} of {max} spots filled", spots-left pips); action area by relationship:
- Non-member, `open`: `TSPrimaryButton` "Request to join".
- Requested: disabled pill *"Requested — waiting for host"* + "Withdraw".
- Member: "Group chat" + (day-of) "Start hike" + "Share my plan".
- `full`: *"This hike is full"* + "See other hikes at {park}".

**Components.** `TSMap`, `HikeCard` internals, `TSAvatar` row, `TSStatusPill`, buttons.

**Copy.** Day-of banner (members, hike date): *"Today's the day. Set your safety plan before you lose signal."* Cancelled banner: *"The host cancelled this hike."*

**States.** open · full · confirmed · in_progress (live badge; member live-locations if opted in) · completed (→ recap variant) · cancelled (read-only) · requester/member/non-member variants as above.

**Interactions.** Request → `S-HIKE-04`. Members see membership changes live (Realtime `hike:{id}`).

**Transitions.** Push/sheets; "Start hike" → full-screen `S-HIKE-05`.

**Edge cases.** Removed member loses chat + detail access immediately (RLS — PRD §3.6 AC); screen degrades to non-member variant with toast. Invite-only hike: visible only to invitees; others get 404-style *"This hike isn't available."*

**Accessibility.** Countdown announced sparingly (on focus only).

**Persistence.** Cache for offline day-of reference (meetup point, time, trail).

**Gating.** Verified only.

---

### S-HIKE-03 · Hike Detail (host view) · [Phase 9]

**Purpose.** Superset of `S-HIKE-02` with host controls: requests, roster, edit, confirm, cancel.

**Entry points.** ← own hike cards · push `hike_join_request`.

**Exit points.** As `S-HIKE-02` + Edit → `S-HIKE-01` edit mode · requests row → inline approve/decline · "Cancel hike" confirm.

**Layout.** Adds above Group section: **Requests** ({n} pending rows: avatar, name, capability chips, note, [Approve]/[Decline]). Roster rows get overflow menu (View profile / Remove from hike). Footer: "Confirm hike" (when ≥2 members incl. host and host is ready) · "Cancel hike" (destructive).

**Components.** As `S-HIKE-02` + request rows, context menus, `TSDestructiveButton`.

**Copy.**
- Approve toast: *"{name} is in — she's been added to the group chat."*
- Remove confirm: *"Remove {name}? She'll lose access to the group chat and be notified."*
- Confirm explainer: *"Confirming locks the plan and notifies everyone. You can still cancel if things change."*
- Cancel confirm: *"Cancel this hike? All {n} members will be notified."*

**States.** By hike status; requests section hidden when `full` (with hint to raise size or remove).

**Interactions.** Approve/decline/remove/confirm/cancel are transactional server mutations (PRD §3.6 AC); auto `full` when spots fill; edits notify members.

**Transitions.** Inline.

**Edge cases.** Approving when full → error per `S-HOME-02`. Host cannot leave her own hike — only cancel or (P2) transfer.

**Accessibility.** Request rows: buttons individually labeled ("Approve Maya's request").

**Persistence.** Server.

**Gating.** Host only (RLS).

---

### S-HIKE-04 · Join Request Sheet · [Phase 9]

**Purpose.** Request to join with an optional note that helps the host decide.

**Entry points.** ← `S-HIKE-02` "Request to join".

**Exit points.** Send ⤴ (button becomes "Requested") · cancel.

**Layout.** Sheet: hike summary row, your capability summary as chips (*"The host sees your profile — here's the short version"*), 280-char note, send.

**Components.** Sheet, `TSChip`, `TSTextEditor`, `TSPrimaryButton`.

**Copy.** Title: **"Request to join"** · placeholder: *"e.g. Steady 2.5 mph, done 3 hikes at this elevation, happy to drive."* · toast *"Request sent — {host name} will review it."*

**States.** Compose · sending · sent.

**Interactions.** Creates `hike_members` row status `requested`.

**Edge cases.** Hike filled while composing → *"This hike just filled up."*; experience-expectation mismatch shows soft warning (never a hard block): *"The host asked for {level}+ — you can still request."*

**Accessibility.** Standard sheet.

**Persistence.** Server row.

**Gating.** Verified only; blocked pairs can't see each other's hikes at all (RLS).

---

### S-HIKE-05 · Active Hike Mode (day-of) · [Phase 11]

**Purpose.** Full-screen "Start hike" mode that activates the safety suite (PRD §3.6, §3.8): check-in timer, live share, quick access to group + safety card.

**Entry points.** ← `S-HIKE-02/03` "Start hike" (hike date only) · notification `safety_checkin`.

**Exit points.** "Complete hike" → `S-HIKE-06` · minimize (persistent pill on tab bar returns here) · does NOT exit on app kill — plan stays active server-side.

**Layout.** Dark-optimized full-screen: elapsed timer top; big status card — expected return time + check-in countdown; toggle rows: **Live location to group** (in-app) and **Live link to trusted contacts** (tokenized web link); buttons: "Group chat", "Offline safety card", "Share my plan" (if not yet shared); prominent `TSPrimaryButton` "Complete hike"; small "I need to bail" → leaves plan active but marks user off-hike (returns to `S-HIKE-02`).

**Components.** Timer, `TSToggleRow`, `TSCard`, buttons; background `location` mode ONLY while this mode is active and user enabled a share (PRD §9 notes).

**Copy.**
- On start (if no safety plan yet) auto-presents `S-SAFE-04` setup: *"Set your expected return so we can check on you."* Default = trail est. duration × 1.3 (PRD §3.8.3).
- Live-share rows: *"Group members can see your location during the hike"* · *"Trusted contacts get a private link — expires automatically."*
- Battery note: *"Location updates are battery-friendly (significant changes only)."*
- Coverage caveat (always visible, small): *"Check-ins and alerts depend on cell coverage. This is not an emergency service — in an emergency call 911."*

**States.** Active (default) · check-in due (`S-SAFE-04` prompt overlays) · overdue-escalated (banner *"We've texted your trusted contacts your last known location."*) · offline (all local features work; queued state syncs on reconnect).

**Interactions.** Toggles start/stop CLLocation significant-change updates; location written to `safety_plans.last_known_location` every 5 min while sharing (schema §8.3). "Complete hike" stops everything (PRD §3.8.4).

**Transitions.** Full-screen cover; minimizes to a pill.

**Edge cases.** 24 h auto-stop on live share (↻ server) even if never completed. Multiple members each have their own plan/timers. Airplane mode: timers run locally; escalation is server-side regardless (PRD §3.8 AC).

**Accessibility.** Timer not announced continuously; check-in prompt is time-sensitive + strongly announced.

**Persistence.** `safety_plans` row is the truth; local mirror for offline.

**Gating.** Approved members only; hike date only.

---

### S-HIKE-06 · Complete Hike Flow · [Phase 11; conditions step Phase 15]

**Purpose.** Wrap up: stats, optional trail-condition report (P1), kudos, private no-show flags (PRD §3.6).

**Entry points.** ← `S-HIKE-05` "Complete hike" · host "Complete" on `S-HIKE-03` post-date.

**Exit points.** Done → `S-HIKE-02` completed recap · skip any step.

**Layout.** Stepped sheet:
1. **Done!** — celebratory header, hike summary (trail, date, group avatars), stats if GPX recorded (P1).
2. **Trail conditions** (P1) — tag chips (snow, mud, downed trees, high water crossing, trail clear, crowded, bugs, wildlife sighting) + optional note/photo.
3. **Kudos** — tap companions to send a kudo (*"Great trail sister"* — one per member, optional).
4. **Anything off?** — quiet row: *"Someone didn't show?"* → private no-show flag per absent member.

**Components.** Sheet steps, `TSChipGroup`, avatar toggle grid.

**Copy.** Header: **"Hike complete 🏔"** · No-show note: *"Flags are private. Repeated no-shows lead to warnings."* (3 flags → warning ↻ server, PRD §3.6)

**States.** Steps skippable; conditions step hidden pre-P1.

**Interactions.** Completing sets hike `completed` (host action) / member marks own completion; safety plan → `checked_in`; live shares stop.

**Edge cases.** Completing with an overdue check-in resolves the escalation state and (if escalated) sends the all-clear SMS.

**Accessibility.** Step progress announced.

**Persistence.** `hikes.status`, `trail_conditions` (P1), kudos + no-show rows.

**Gating.** Members only.

---
## Group H — Chat (PRD §3.7)

### S-CHAT-01 · Threads List · [Phase 10]

**Purpose.** All DM threads (from accepted trip matches) and hike group threads.

**Entry points.** Tab 4 · push `message` (list level).

**Exit points.** Row → `S-CHAT-02` · avatar → `S-USER-01`.

**Layout.** Search-filter field; rows: avatar (group threads: stacked avatars + trail name), name/title, last-message preview, timestamp, unread dot, muted icon. Hike threads titled "{trail name} · {Mon d}".

**Components.** `TSListRow`, `TSAvatar`, unread badge.

**Copy.** Empty state: *"Chats open when a connection is made — accept a 'say hi' or join a hike, and you'll see it here."* + buttons "See requests" → `S-HOME-02` / "Find a hike" → `S-EXP-01`.

**States.** Default · empty · offline (cached list + banner).

**Interactions.** Long-press row → context menu: Mute/unmute, (DM only) View profile, Report, Block. **No swipe actions.**

**Transitions.** Push.

**Edge cases.** Thread with blocked user disappears entirely (bidirectional hide, PRD §3.7). Hike thread of a cancelled hike stays readable 7 days, read-only banner *"This hike was cancelled — chat is closed."*

**Accessibility.** Rows composed labels incl. unread state.

**Persistence.** Thread list + last N messages cached.

**Gating.** Verified only; participants only (RLS).

---

### S-CHAT-02 · Thread (DM & group) · [Phase 10]

**Purpose.** Realtime messaging: text + photos; safety affordances on every message.

**Entry points.** ← `S-CHAT-01` · accept toast deep link · `S-HIKE-02` "Group chat" · push `message`.

**Exit points.** Header → `S-USER-01` (DM) / `S-HIKE-02` (group) · report sheet `S-MOD-01` · back.

**Layout.** Header: avatar(s) + name/title + (group) member count; message list (bubbles, sender name in groups, day separators); composer: text field + photo button + send. Media messages render with a "Reviewing…" shimmer until moderation passes (<10 s p95 — PRD §3.7 AC), then the image.

**Components.** Message bubbles, `PhotosPicker`, composer, typing indicator (Realtime), moderation shimmer.

**Copy.**
- First-DM safety header (system row, DM only, once): *"You're connected because your trips overlap at {park}. Meet at trailheads, share your plan, and trust your gut. Safety tips →"* (links `S-SAFE-01`).
- Media rejected: *"Photo not shared — it didn't pass review."*
- Toxicity soft-flag (sender side, borderline): message sends but *"This message was flagged for review."* (server queues; PRD §3.7: don't hard-block borderline).

**States.** Default · sending (ghost bubble) · failed (retry tap) · media pending/approved/rejected · offline (queued outbox, "Waiting to send") · read-only (cancelled-hike or removed-member grace view: composer hidden).

**Interactions.** Long-press any message → Copy / **Report** (`S-MOD-01` with message target). Send: optimistic insert + Realtime broadcast; client profanity hint underlines before send (client hint only).

**Transitions.** Push; photo viewer full-screen on tap.

**Edge cases.** Removed hike member loses read+write instantly (RLS); her past messages remain for others. Blocked mid-thread → thread vanishes from both sides. Pagination: 50/page, infinite scroll up.

**Accessibility.** New messages announced when thread open; sender + time in labels.

**Persistence.** Messages cached (SwiftData) for offline read; outbox queue.

**Gating.** Participants only — connection (DM) or approved membership (group), RLS-tested (PRD §3.7 AC).

---

## Group I — Safety Suite (PRD §3.8 — all free, always)

### S-SAFE-01 · Safety Center · [Phase 11; checklist interactive P1]

**Purpose.** Home for safety tools + static education content (partner-vetting tips, trailhead-meeting guidance, wildlife basics, 10 essentials, Leave No Trace, report links).

**Entry points.** ← Profile tab row · chat safety header link · onboarding completion tip.

**Exit points.** Tool rows → `S-SAFE-02/03/04/05/06` · article rows → article reader · "Report a member" → `S-MOD-01`.

**Layout.** **Your tools** section: Trusted contacts (with count), Share my plan (enabled when an upcoming hike exists), Check-in timer, Live location, Offline safety cards (saved count). **Learn** section: article rows (Meeting a new hiking partner · Trailhead meetups · Wildlife basics · The 10 essentials · Leave No Trace). Footer: "Report a member" + support link.

**Components.** `TSListRow`, `TSCard`, article reader (markdown).

**Copy.** Header: **"Safety Center"** · Sub: *"Every tool here is free — always."* Coverage caveat footer as in `S-HIKE-05`.

**States.** Default; tool rows show setup state ("2 of 3 contacts added").

**Interactions.** Navigation only.

**Edge cases.** None.

**Accessibility.** Articles support Dynamic Type fully.

**Persistence.** Article content bundled (offline-readable).

**Gating.** Verified only (content itself is harmless, but tools are member-bound).

---

### S-SAFE-02 · Trusted Contacts · [Phase 11]

**Purpose.** Manage up to 3 manually-entered contacts (name + phone). **Never** reads the address book (PRD §5, §9).

**Entry points.** ← `S-SAFE-01` · first "Share my plan"/check-in setup without contacts.

**Exit points.** ⤴ back · continue setup flow that launched it.

**Layout.** Up to 3 contact cards (name, masked phone, delete); "Add contact" form (name + phone fields — plain text fields, no contacts-picker button anywhere); explainer card.

**Components.** `TSCard`, `TSTextField`, `TSDestructiveButton` (delete).

**Copy.**
- Explainer: *"Trusted contacts get SMS links when you share a plan or miss a check-in. They don't need the app. We text them only when you ask us to — every SMS includes opt-out instructions."*
- Add hint: *"Type their details — we never access your phone's contacts."*
- Delete confirm: *"Remove {name} from your trusted contacts?"*

**States.** 0–3 contacts · add form validating (E.164) · limit reached (add hidden).

**Interactions.** CRUD → `trusted_contacts` (server + local).

**Edge cases.** Duplicate number rejected. Landline/undeliverable detected on first send → row badge *"Couldn't deliver last SMS"*.

**Accessibility.** Standard forms.

**Persistence.** Server + local mirror (offline visibility).

**Gating.** Verified only.

---

### S-SAFE-03 · Share My Plan · [Phase 11]

**Purpose.** One tap from a hike → SMS/share-sheet to trusted contacts with the tokenized plan page (PRD §3.8.2).

**Entry points.** ← `S-HIKE-02/05` "Share my plan" · `S-SAFE-01`.

**Exit points.** Sent ⤴ with toast · manage contacts → `S-SAFE-02`.

**Layout.** Sheet: plan preview card (trail, park, trailhead coords + map thumbnail, start time, expected return, group size, companion first names); contact checkboxes (default all); buttons "Text my contacts" (server SMS via Twilio) and "Share another way…" (iOS share sheet with the tokenized URL).

**Components.** Sheet, plan card, `TSCheckboxRow`, buttons.

**Copy.**
- SMS body (server template): *"{name} shared her hike plan with you via TrailSisters: {trail}, {park}. Starts {time}, expected back {time}. Live plan: {short URL}. Reply STOP to opt out."*
- Toast: *"Plan sent to {n} contacts."*
- No contacts yet → inline `S-SAFE-02` embed first.

**States.** Preview · sending · sent · partial failure (*"Couldn't reach {name} — check the number."*).

**Interactions.** Creates/updates `safety_plans` row + `share_token`; SMS via `send-safety-sms` edge function.

**Edge cases.** Re-sharing regenerates page content, same token; revoking (from `S-SAFE-05`) kills the link.

**Accessibility.** Plan card read as summary.

**Persistence.** `safety_plans`.

**Gating.** Members of a hike (or a solo plan from a trail page — allowed: hike_id nullable in schema).

---

### S-SAFE-04 · Check-In Timer · [Phase 11]

**Purpose.** Expected-return timer with server-side escalation (PRD §3.8.3): T+0 prompt → +30 min grace → SMS to trusted contacts with last-known location.

**Entry points.** ← `S-HIKE-05` start (auto) · `S-SAFE-01` · time-sensitive push "Are you safe?" · cold-launch row 13.

**Exit points.** Confirmed safe ⤴ · adjust time · cancel plan.

**Layout.** Setup state: expected-return time picker (default trail est. × 1.3), contact summary, explainer, "Start check-in". Active state: countdown card + "I'm back — I'm safe" big button + "Add 30 minutes". Prompt state (T+0): full-screen-priority overlay: **"Are you safe?"** with "I'm safe" (huge) / "Need more time (+30 min)".

**Components.** Time picker, countdown, `TSPrimaryButton` (oversized), time-sensitive notification actions ("I'm safe" actionable from lock screen — PRD §15 mitigation).

**Copy.**
- Explainer: *"If you don't check in within 30 minutes of this time, we'll text your trusted contacts your last known location — as soon as your phone has coverage. This is not an emergency service."*
- Escalation SMS (server): *"TrailSisters safety alert: {name} hasn't checked in from her hike ({trail}, {park}) expected back {time}. Last known location: {maps link, ~time}. This is an automated alert — try contacting her. If concerned, contact {park emergency number}. Reply STOP to opt out."*
- Escalated in-app banner: *"We've alerted your trusted contacts. Tap 'I'm safe' to send the all-clear."*
- All-clear SMS: *"{name} has checked in safe. — TrailSisters"*

**States.** setup · active (counting) · prompt (T+0) · grace (30 min) · escalated · checked_in · cancelled.

**Interactions.** All state transitions mirrored server-side; **escalation fires from `safety-escalation-cron` (server), never client-only** (PRD §3.8 AC). "I'm safe" works from lock-screen action without opening the app.

**Edge cases.** Offline at T+0: local notification still prompts; if user confirms safe offline, confirmation syncs on reconnect — if cron already escalated, auto-send all-clear. No trusted contacts → cannot start; inline add flow.

**Accessibility.** Prompt buttons enormous + VoiceOver-first; time-sensitive announcement.

**Persistence.** `safety_plans.status`, `expected_return_at`.

**Gating.** Verified only.

---

### S-SAFE-05 · Live Location Sharing · [Phase 11]

**Purpose.** Control both live-share channels during an active hike: group (in-app) and trusted contacts (tokenized web) (PRD §3.8.4).

**Entry points.** ← `S-HIKE-05` toggles (this is their detail/settings surface) · `S-SAFE-01`.

**Exit points.** ⤴ back.

**Layout.** Two toggle cards with status: **Group members** ("{n} members can see you on the hike map") and **Trusted contacts link** (link row with copy button + "Revoke link"); auto-stop explainer; battery note.

**Components.** `TSToggleRow`, link row, `TSDestructiveButton` (revoke).

**Copy.** Auto-stop: *"Sharing stops automatically when you complete the hike, or after 24 hours — whichever comes first."* Revoke toast: *"Link revoked — it no longer works."*

**States.** Off · group-only · contacts-only · both · revoked link (regenerate available).

**Interactions.** Toggles drive significant-change location updates; positions publish to `hike:{id}:loc` (approved members only) and `safety_plans.last_known_location` every 5 min (schema §8.3).

**Edge cases.** Location permission "While Using" only → background caveat shown: *"For sharing to continue with the screen off, allow 'Always' — we only use it during a hike you started."* Denied → toggles disabled with Settings link.

**Accessibility.** Toggle states announced.

**Persistence.** `safety_plans.live_share_enabled`, token.

**Gating.** Active-hike members.

---

### S-SAFE-06 · Offline Safety Card · [Phase 11; auto-bundled with P1 park downloads]

**Purpose.** Downloadable per-trail card usable with zero connectivity (PRD §3.8.5).

**Entry points.** ← `S-EXP-03` "Save offline safety card" · `S-HIKE-05` · `S-SAFE-01` saved list.

**Exit points.** ⤴ back.

**Layout.** High-contrast, screenshot-friendly single card: trailhead coordinates (large, monospaced) · nearest ranger station + phone · park emergency number · nearest hospital · cell-coverage caveat · the user's own plan summary (return time, contacts) when one exists. "Save to Photos" button.

**Components.** `TSCard` (print-style), share/save buttons.

**Copy.** Caveat: *"Cell coverage in parks is unreliable. Screenshot this card or save it — it works without any signal."*

**States.** With/without personal plan section · saved confirmation.

**Interactions.** Save renders to image → Photos (permission prompt with purpose string).

**Edge cases.** Curated fields missing for non-flagship park → rows show *"Check at ranger station"* rather than blank.

**Accessibility.** Large-type layout by default.

**Persistence.** Card cached locally on first view (guaranteed offline render).

**Gating.** Card data public; personal section member-only.

---

### W-SHARE-01 · Public Plan Status Page (web, no login) · [Phase 11]

**Purpose.** The tokenized, expiring page trusted contacts open from SMS (PRD §3.8.2; served by `share-page` edge function/Worker — not RLS).

**Entry points.** SMS / shared URL with token.

**Exit points.** None (static page).

**Layout.** Mobile-first single page: status banner (On the hike / Overdue — contacts alerted / Checked in safe / Plan ended); hiker first name; trail + park; start + expected return (contact's local time + park time); trailhead map link; group size + companion first names; **last known location** (map link + timestamp) shown only while live share to contacts is enabled; footer: what-to-do guidance + park emergency number + TrailSisters explainer.

**Copy.** Overdue variant: *"{name} hasn't checked in yet. Her phone may be out of coverage — that's common on trails. Try texting her. If you're seriously concerned, call {park emergency number}."*

**States.** active · overdue/escalated · checked-in · expired/revoked (*"This link has expired."* — no data).

**Edge cases.** Token invalid/expired → generic expired page, zero information leak. Page auto-refreshes every 60 s.

**Accessibility.** Semantic HTML, large text, no JS required for core content.

**Persistence.** Renders from `safety_plans` via service role; token is the only key; links expire and are revocable (PRD §3.8 AC).

**Gating.** Token possession.

---
## Group J — Profiles, Settings & Moderation

### S-ME-01 · Profile Tab Root (own) · [Phase 6, enriched 11–13]

**Purpose.** Own profile preview + gateway to editing, safety, settings.

**Entry points.** Tab 5.

**Exit points.** "Edit profile" → `S-ME-02` · "Preview as others see it" → `S-USER-01` self-preview · Safety Center → `S-SAFE-01` · Settings → `S-ME-03` · completeness ring → first incomplete section of `S-ME-02`.

**Layout.** Header: `TSAvatar` (large, `VerifiedBadge`), first name + age range, home region, completeness ring + label; capability chips row; badges row (WFR, satellite, host); list rows: Edit profile · Preview profile · Safety Center · Notifications inbox · Settings.

**Components.** `TSAvatar`, `TSProgressRing`, `TSChip`, `TSBadge`, `TSListRow`.

**Copy.** Completeness under 80%: *"{n}% complete — 80%+ profiles rank higher"*.

**States.** Default · photo pending moderation (avatar shows shimmer + "Reviewing").

**Interactions.** Navigation.

**Edge cases.** `warned` account shows dismissible banner: *"Your account received a warning. Review our community guidelines."*

**Accessibility.** Ring % announced.

**Persistence.** Own profile cached.

**Gating.** Any signed-in state (guests see setup progress instead).

---

### S-ME-02 · Edit Profile · [Phase 6]

**Purpose.** Edit everything from the wizard in one grouped form.

**Entry points.** ← `S-ME-01` · `S-PROF-06` "finish" link.

**Exit points.** Save ⤴ · discard confirm.

**Layout.** Sections mirroring wizard steps 1–5 (basics · how you hike · trail details · photos · prompts+bio), each collapsible, pre-filled.

**Components.** Same field components as wizard.

**Copy.** Save toast: *"Profile updated."* DOB row is read-only: *"Age range comes from your date of birth (not editable)."*

**States.** Clean · dirty (save bar appears) · saving · photo moderation states inline.

**Interactions.** Section saves are atomic per save-bar tap; completeness re-computed server-side.

**Edge cases.** Removing primary photo requires promoting another face-passing photo first.

**Accessibility.** As wizard.

**Persistence.** `profiles`, `profile_photos`.

**Gating.** Verified only (guests can't reach it — wizard runs post-verification).

---

### S-ME-03 · Settings Root · [Phase 13, 14]

**Purpose.** Account, privacy, notifications, blocked list, legal, support, sign out, deletion.

**Entry points.** ← `S-ME-01`.

**Exit points.** Notification settings → `S-ME-04` · Blocked members → blocked list (inline screen: unblock rows) · Delete account → `S-ME-05` · legal/help rows → in-app browser · Sign out confirm.

**Layout.** Grouped list: **Account** (email/Apple ID row read-only, phone row read-only) · **Privacy** (pronoun display toggle; "Show my region" toggle) · **Notifications** → `S-ME-04` · **Community** (Blocked members · Community guidelines · Report a problem) · **Legal** (Terms · Privacy policy · Licenses/attribution incl. trail-data attribution) · **Support** (Help Center · Contact support — published support contact, App Store 1.2) · Sign out · Delete account (destructive, at bottom).

**Components.** `TSListRow`, `TSToggleRow`, `TSDestructiveButton`.

**Copy.** Sign-out confirm: *"Sign out of TrailSisters?"*

**States.** Default.

**Interactions.** Standard.

**Edge cases.** Blocked list empty state: *"You haven't blocked anyone."* Unblock confirm: *"Unblock {name}? You'll be able to see each other again. Existing connections are not restored."*

**Accessibility.** Standard grouped list.

**Persistence.** Settings server-side (multi-device).

**Gating.** Signed-in.

---

### S-ME-04 · Notification Settings · [Phase 12]

**Purpose.** Granular per-category toggles (PRD §3.11).

**Entry points.** ← `S-ME-03` · `S-NOTIF-01` gear.

**Exit points.** ⤴ back.

**Layout.** Toggle groups: Matching (trip-match requests/accepts · trip nudges) · Hikes (join requests/approvals · changes & cancellations · reminders T-24h/T-2h) · Messages (per-thread mute lives in threads) · Community (moderation outcomes) · **Safety** (check-in prompts — toggle shown LOCKED-ON with row note while any hike is active).

**Components.** `TSToggleRow`, section headers.

**Copy.** Safety lock note: *"Safety check-ins can't be turned off while a hike is active."* (PRD §3.11) System-permission-off banner: *"Notifications are off in iOS Settings — safety alerts can't reach you. Fix in Settings →"*

**States.** Default · system-denied banner · safety-locked.

**Interactions.** Toggles sync server-side (`notification_prefs`).

**Edge cases.** Time-sensitive entitlement used only by check-ins (PRD §3.11 AC) — no toggle exposes it elsewhere.

**Accessibility.** Standard toggles.

**Persistence.** Server prefs.

**Gating.** Signed-in.

---

### S-ME-05 · Account Deletion Flow · [Phase 14]

**Purpose.** In-app deletion (Apple requirement; PRD §5): deletes profile, media, message content (tombstoned), trips/hikes memberships; retains minimal legal audit rows.

**Entry points.** ← `S-ME-03` · under-18 block path.

**Exit points.** Deleted → signed-out `S-AUTH-01` with farewell toast · cancel ⤴.

**Layout.** Step 1: what-gets-deleted checklist + what's retained (*"a minimal record of bans and legal holds, per our Terms"*) + alternatives row ("Just want a break? You can sign out instead."). Step 2: type first name to confirm + `TSDestructiveButton` "Delete my account permanently". Step 3: progress → done.

**Components.** Checklist, confirm field, destructive button.

**Copy.**
- Title: **"Delete your account"**
- Body: *"This is permanent. Your profile, photos, trips, hikes, and messages are deleted. Messages you sent appear as 'deleted member' to others."*
- Active-hike warning: *"You're in {n} upcoming hikes — members will be notified you've left."*

**States.** Review · confirm · deleting (blocking) · error retry.

**Interactions.** Calls `delete-account` edge function (transactional server flow).

**Edge cases.** Offline → refuse to start (*"Deletion needs a connection."*). Host of upcoming hikes → hikes cancelled with member notifications, listed explicitly before confirm.

**Accessibility.** Destructive semantics on buttons.

**Persistence.** Everything (that's the point).

**Gating.** Signed-in.

---

### S-USER-01 · Member Profile (other) · [Phase 6, actions 8–9]

**Purpose.** Another verified woman's profile — capability-first, privacy-preserving (PRD §2.7: age range only, no last name, no exact location, photos hidden from unverified).

**Entry points.** ← overlap cards, rosters, chats, requests.

**Exit points.** "Say hi" → `S-TRIP-04` (when a qualifying overlap exists) · "Invite to my hike" → invite variant · overflow → Report `S-MOD-01` / Block `S-MOD-02` · photo grid → viewer.

**Layout.** Photo pager (approved photos only); name + age range + pronouns (if she opted in) + `VerifiedBadge` inline ("Verified" label on first view); home region (city/state); capability grid (experience, pace, distance, elevation as labeled tiles); badges (WFR, satellite, languages, LNT); terrain/hike-type chips; prompts cards; **shared-context card** when applicable (*"Her trip overlaps yours at {park}: {n} shared days"* / *"Member of {hike}"*); action bar per context; overflow menu (Report · Block).

**Components.** Photo pager, `TSStatTile`, `TSChip`, `TSBadge`, `TSCard`, action bar.

**Copy.** Verified tooltip (tap badge): *"Verified via government ID + live selfie check by Stripe. TrailSisters never stores IDs."*

**States.** Full (with shared context + actions) · no-context (viewing from a public hike roster: profile visible, "Say hi" hidden — chat requires connection, PRD §2.4) · self-preview (banner *"This is how others see you"*, actions hidden).

**Interactions.** Report/Block always available from overflow (PRD §3.10).

**Edge cases.** Her account suspended/deleted since render → *"This profile isn't available."* Sensitive fields are absent from the API payload entirely (`public_profiles` view — PRD §8.1), not hidden client-side.

**Accessibility.** Photo pager with indexed labels; capability tiles labeled.

**Persistence.** Not cached beyond session (privacy).

**Gating.** Verified viewers only — enforced by RLS; unverified API access must return nothing (PRD §3.1 AC).

---

### S-MOD-01 · Report Sheet · [Phase 13]

**Purpose.** Report any profile, message, photo, hike, or trip (PRD §3.10); queue latency <5 s.

**Entry points.** Overflow menus, message long-press, hike/trip detail menus, Safety Center.

**Exit points.** Submitted → confirmation state ⤴ · optional "Also block {name}" → `S-MOD-02`.

**Layout.** Sheet: category list (radio) — Impersonation or not a woman · Harassment · Safety concern · Spam · Inappropriate content · No-show · Other; free-text detail (required for Other); target preview row; submit.

**Components.** Sheet, radio rows, `TSTextEditor`, `TSPrimaryButton`.

**Copy.**
- Title: **"Report"**
- Reassurance: *"Reports are confidential — she won't know it came from you."*
- Confirmation: **"Thank you — we've got it."** *"Our team reviews every report, almost always within 24 hours. We'll notify you when it's actioned."* + "Also block her" button (profile/message targets).
- Impersonation category note: *"Accounts that aren't women are permanently removed."*

**States.** Category select · detail · submitting · confirmed.

**Interactions.** Insert into `reports` (insert-only RLS); reporter gets `moderation_outcome` notification later.

**Edge cases.** Duplicate report of same target by same user within 24 h → still accepted, deduped server-side.

**Accessibility.** Radio semantics; confirmation announced.

**Persistence.** `reports` row.

**Gating.** Verified only.

---

### S-MOD-02 · Block Confirmation · [Phase 13]

**Purpose.** Block a member: bidirectional invisibility, connection removal, no future matching (PRD §3.10).

**Entry points.** Overflow menus · report confirmation.

**Exit points.** Blocked ⤴ (originating surface refreshes with her content gone) · cancel.

**Layout.** Alert-style sheet: consequences list + confirm.

**Copy.**
- Title: **"Block {name}?"**
- Body: *"You won't see each other anywhere — profiles, trips, hikes, or chats. Any connection is removed. She won't be told she's blocked."*
- If in a shared upcoming hike: *"You're both in {hike}. Blocking hides her for you but doesn't remove either of you from the hike — you may prefer to leave the hike or tell the host."*

**States.** Confirm · blocking · done toast (*"Blocked."*).

**Interactions.** Insert `blocks` row; RLS makes both invisible everywhere immediately.

**Edge cases.** Shared-hike nuance above (deliberate: blocking ≠ hike membership change).

**Accessibility.** Destructive confirm semantics.

**Persistence.** `blocks`.

**Gating.** Verified only.

---

### S-MOD-03 · Suspended / Banned Interstitial · [Phase 13]

**Purpose.** Full-screen lock for `suspended` / `banned` accounts (route rows 10–11). Banned sessions killed ≤60 s (PRD §3.10 AC).

**Entry points.** Route table · Realtime account-status flip mid-session.

**Exit points.** Suspended: none until `suspension_until` (then normal routing) · support link · Banned: support link only; sign-out.

**Layout.** Neutral full-screen: status title, reason category, duration (suspended), appeal/support link, community-guidelines link.

**Copy.**
- Suspended: **"Your account is paused until {date}"** *"Reason: {category}. Repeated issues lead to permanent removal. If you think this is a mistake, contact support."*
- Banned: **"Your account has been removed"** *"Reason: {category}. This decision can be appealed through support."*

**States.** Suspended (dated) · banned (final).

**Interactions.** Nothing else reachable; push unregistered on ban.

**Edge cases.** Mid-hike suspension: safety features (check-in escalation, live-share links already active) run to completion server-side — enforcement never disables an in-flight safety plan.

**Accessibility.** Full text announced.

**Persistence.** Server truth.

**Gating.** Is the gate.

---

## Group K — Notifications

### S-NOTIF-01 · Notification Inbox · [Phase 12]

**Purpose.** In-app mirror of all pushes (PRD §3.11): requests, approvals, changes, nudges, moderation outcomes.

**Entry points.** ← Home bell · push tap fallback.

**Exit points.** Row → its deep-link target (0.3 table) · gear → `S-ME-04`.

**Layout.** Chronological list, unread tinted; rows: kind icon, one-line text, timestamp. Kind icons per category (match, hike, message, safety, moderation).

**Components.** `TSListRow`, kind icons, gear button.

**Copy.** Row templates: *"{name} said hi · your {park} trip"* · *"{name} accepted — say hello!"* · *"{name} asked to join {trail}"* · *"You're in! {host} approved you for {trail}"* · *"{trail} was updated by the host"* · *"Reminder: {trail} tomorrow {time}"* · *"Your trip to {park} is in 5 days — {n} women overlap"* · *"Your report was actioned. Thank you for keeping TrailSisters safe."* Empty: *"Nothing yet — activity about your trips and hikes lands here."*

**States.** Default · empty · offline (cached).

**Interactions.** Tap marks read + routes. "Mark all read" toolbar.

**Edge cases.** Target deleted → toast *"That's no longer available."*

**Accessibility.** Unread state in labels.

**Persistence.** `notifications` table; badge count via Realtime.

**Gating.** Verified only.

---

## Appendix A — Admin Dashboard (internal web; Next.js or Retool) · [Phase 13]

Lower-fidelity specs — internal tool, but a **launch requirement** (App Store 1.2 evidence; PRD §3.10). Auth: admin allowlist (Supabase service role behind SSO). Every action writes `moderation_audit`.

### A-ADM-01 · Reports Queue
Open reports, oldest first, **SLA timer column surfacing items >12 h in red** (target action <24 h). Filters: category, target type, status. Row → A-ADM-04 with report context. Bulk dismiss for spam waves.

### A-ADM-02 · Flagged Media & Text Queue
Grid of media failing/flagged by Sightengine/Hive + toxicity-flagged messages. Actions: approve · remove content · remove + warn · escalate to A-ADM-04. Shows model scores + context (thread/profile).

### A-ADM-03 · Verification Review Queue (`needs_review`)
Queue of ambiguous verifications. Shows: Stripe session link (review happens **in Stripe's dashboard** — no ID data ever rendered in ours; PRD §2.2), signal summary (liveness pass, doc validity, mismatch reason code), account age/phone-uniqueness flags. Actions: approve (→ `verified`) · decline (→ `failed` + reason) · request re-verification. Inclusive-policy reminder banner pinned: *"Never decline on an ID gender marker alone."*

### A-ADM-04 · Member Detail & Enforcement
One member: profile snapshot, report history, prior actions, hikes/trips counts, no-show flags. Enforcement ladder buttons: Warn → Suspend 7d → Suspend 30d → Ban (impersonation category: direct Ban). Ban triggers session kill + content hide ≤60 s (PRD AC). Free-text reason required; all actions audited.

### A-ADM-05 · Audit Log & Ops
Filterable `moderation_audit` view; verification kill-switch toggle (feature flag, PRD §6 cost control); daily counters (reports actioned, SLA breaches, verifications by outcome).

---
## Group L — P1 Fast-Follow Screens · [Phase 15]

### S-EXP-06 · Download Park (offline pack) · [Phase 15] [P1]

**Purpose.** "Download park" — tile pack + trails + safety cards for full offline use (PRD §3.12; ≤60 MB/park, zooms 8–14).

**Entry points.** ← `S-EXP-02` download button (visible P1+) · Settings storage list.

**Exit points.** ⤴ back; downloads continue in background.

**Layout.** Sheet: park name, size estimate, contents checklist (map tiles · {n} trails · safety cards), progress bar during download, "Remove download" when complete; managed list variant in Settings ("Offline parks", per-park size + remove).

**Copy.** *"Works completely offline: trail pages, maps, and safety cards."* Wi-Fi hint when on cellular: *"{size} MB — connect to Wi-Fi?"* (proceed allowed).

**States.** Not downloaded · downloading (pausable) · complete · update available (tiles refreshed quarterly) · storage-full error.

**Interactions.** Fetch PMTiles pack from R2 + per-park GeoJSON bundle; store locally; MapLibre source switches to local automatically.

**Edge cases.** Download interrupted → resumes; partial packs never render as complete. **AC (PRD §3.12): full trail page + map + safety card usable in airplane mode after download.**

**Accessibility.** Progress announced at 25% steps.

**Persistence.** Local pack registry.

**Gating.** Guest-visible (content is public).

---

### S-EXP-07 · Trail Condition Report · [Phase 15] [P1]

**Purpose.** Standalone + post-hike condition reports (PRD §3.14).

**Entry points.** ← `S-EXP-03` "Report conditions" (P1) · `S-HIKE-06` step 2.

**Exit points.** Submit ⤴ with toast · cancel.

**Layout.** Sheet: tag chips (snow · mud · downed trees · water crossing high · trail clear · crowded · bugs · wildlife sighting), hiked-on date (default today), optional 500-char note, optional photo.

**Copy.** Toast: *"Thanks — hikers after you will see this."* (renders on trail page within 1 min; photos post-moderation — PRD AC.)

**States.** Compose · submitting · sent.

**Interactions.** Insert `trail_conditions`; photo through moderation pipeline.

**Edge cases.** Reports auto-expire from the trail-page summary after 30 days (↻ server query window).

**Accessibility.** Chips multi-select semantics.

**Persistence.** `trail_conditions`.

**Gating.** Verified only.

---

### S-HIKE-07 · GPX Recording & Stats · [Phase 15] [P1]

**Purpose.** Track recording during active hike; post-hike stats + GPX export (PRD §3.13).

**Entry points.** ← `S-HIKE-05` "Record my track" toggle (P1) · completed-hike recap stats tile.

**Exit points.** Export via share sheet · ⤴.

**Layout.** In active mode: live strip (distance · elevation gain · duration · pace) above the status card. Post-hike: stats card + mini track map + "Export GPX" + lifetime totals row.

**Copy.** Battery note: *"Adaptive GPS keeps a 6-hour recording under ~15% battery."* (PRD AC — verify on device.)

**States.** Recording · paused (auto on stationary) · saved · export sheet.

**Interactions.** Core Location background updates (only while user-started hike active); adaptive sampling; GPX file via `ShareLink`.

**Edge cases.** Recording survives app termination via location relaunch; storage-full guard.

**Accessibility.** Live strip values labeled with units.

**Persistence.** Local track store; totals server-side.

**Gating.** Members during active hike.

---

# Part 2 — End-to-End User Journeys

## J-01 · Install → Verified Member (target < 8 min, PRD §3.1 AC)

❶ `S-ONB-01` → carousel `S-ONB-02…04` ❷ `S-AUTH-01` Sign in with Apple ❸ `S-LEGAL-01` accept ❹ `S-AGE-01` DOB ❺ `S-AUTH-03/04` phone + OTP ❻ `S-VER-01` → `S-VER-02` Stripe doc + liveness (~2 min) ❼ `S-VER-03` pending → ↻ webhook `verified` ❽ Wizard `S-PROF-01…06` (required steps ≈ 2 min) ❾ `S-HOME-01` empty state → "Post a trip". Timer instrumentation: `signup_started` → `verification_passed` → `profile_completed_pct` (PRD §13).

## J-02 · Guest Preview → Conversion

❶ At `S-VER-01`, "Browse parks first" ❷ Explore freely (`S-EXP-01…04`) — zero user content visible ❸ Taps "Post a trip here" → `S-EXP-05` gate ❹ "Verify now" → resumes verification at her current state ❺ on verified, returns to the park page she left, CTA now live.

## J-03 · Trip → Overlap → Say Hi → Chat (the core loop, PRD §3.5)

❶ `S-TRIP-01` post trip (Zion, Oct 3–7) ❷ `S-TRIP-03` overlaps populate (index-backed query) ❸ Views `S-USER-01`, taps "Say hi" → `S-TRIP-04` note + send ❹ Her side: push `match_request` → `S-HOME-02` → Accept ❺ ↻ server creates `connections` + `dm` thread ❻ both get `S-CHAT-02`; sender push `match_accepted` ❼ they plan → one creates a hike (J-04).

## J-04 · Create Hike → Fill Group → Confirm

❶ `S-HIKE-01` from trail page (Angels Landing, Oct 5, 6:30 AM, max 4) ❷ publish → `open`; appears in park-matched members' `S-HOME-01` §5 ❸ requests arrive → host `S-HIKE-03` approves 2, declines 1 ❹ approved members enter group chat ❺ host taps Confirm → `confirmed`, everyone notified ❻ T-24h/T-2h reminders ↻.

## J-05 · Day-Of: Start → Check-In → Complete

❶ Hike day: day-of banner on `S-HIKE-02` ❷ "Start hike" → `S-HIKE-05`; check-in setup `S-SAFE-04` (return 4:30 PM = est × 1.3) ❸ optionally `S-SAFE-03` share plan SMS; toggles live share ❹ hike happens (offline OK) ❺ back in coverage, "Complete hike" → `S-HIKE-06` stats/kudos ❻ plan → `checked_in`; live share stops; `hike → completed`.

## J-06 · Check-In Escalation (no response)

❶ Plan active, expected return 4:30 PM ❷ T+0: time-sensitive push "Are you safe?" (+ lock-screen "I'm safe" action) ❸ no response by 5:00 PM AND phone unreachable ❹ ↻ `safety-escalation-cron` (5-min scan) marks `escalated`, `send-safety-sms` texts trusted contacts with last known location + park emergency number ❺ `W-SHARE-01` flips to Overdue ❻ she regains signal at 5:20, taps "I'm safe" → all-clear SMS, plan `checked_in`. Variant: she confirmed safe offline at 4:40 → sync on reconnect; if cron already fired, auto all-clear.

## J-07 · Share Plan With a Non-App Contact

❶ `S-SAFE-03` from hike ❷ SMS with tokenized link ❸ contact opens `W-SHARE-01` — no login, sees plan + status ❹ link expires when plan ends/24 h or on revoke (`S-SAFE-05`).

## J-08 · Report → Moderation → Outcome

❶ Long-press message → `S-MOD-01`, category Harassment ❷ row in `reports` <5 s → `A-ADM-01` queue ❸ admin reviews thread context, actions: warn (ladder) ❹ `moderation_audit` row ❺ reporter push *"Your report was actioned"* → `S-NOTIF-01` ❻ target sees warning banner (`S-ME-01`). SLA clock target <24 h.

## J-09 · Block

❶ `S-USER-01` overflow → `S-MOD-02` confirm ❷ `blocks` row; RLS hides both directions everywhere ❸ DM thread vanishes both sides; matching excludes pair permanently ❹ shared-hike nuance surfaced if applicable.

## J-10 · needs_review Verification (inclusive path)

❶ Stripe webhook reports ambiguous/mismatched signals ❷ ↻ edge fn sets `needs_review` — never auto-reject on marker (PRD §6.4) ❸ user sees `S-VER-05` ❹ admin reviews in `A-ADM-03` (via Stripe dashboard, no ID data in ours) ❺ approve → push → wizard; decline → final state + support path.

## J-11 · Host Cancels a Hike

❶ `S-HIKE-03` cancel + confirm ❷ status `cancelled`; members pushed `hike_cancelled` ❸ group chat read-only for 7 days ❹ member Home cards clear; her trip remains active for new plans.

## J-12 · Account Deletion

❶ `S-ME-03` → `S-ME-05` review (upcoming-hike impacts listed) ❷ type-name confirm ❸ `delete-account` edge fn: profile+media purge, messages tombstoned, memberships removed, hosted hikes cancelled+notified, audit stub retained ❹ signed out; App Store compliant.

## J-13 · Suspension & Ban Experience

❶ Enforcement in `A-ADM-04` ❷ suspended: next request/Realtime flip → `S-MOD-03` dated lock; auto-restore after `suspension_until` ❸ banned: sessions killed + content hidden ≤60 s; interstitial final; safety plans in flight still complete (never strand a hiker).

## J-14 · Trip Urgency Nudges

❶ ↻ `trip-nudges-cron` daily: trips at T-14/T-5/T-2 ❷ push *"Your trip is in 5 days — 3 women overlap"* ❸ tap → `S-TRIP-03` overlaps ❹ archive ↻ after end date.

---

# Part 3 — Cross-Cutting References

## 3.1 Global State Machines (normative)

### Verification (`profiles.verification_status`)
```
unverified → pending → verified
                    ↘ failed → (retry) pending
                    ↘ needs_review → verified | failed
verified → (admin re-verification request) pending
```
Only webhook/edge/admin transitions — never client-set (PRD §2.8).

### Account (`profiles.account_status`)
```
active → warned → suspended(7d|30d) → active (auto at suspension_until)
any → banned (terminal; impersonation = direct)
```

### Trip (`trips.status`)
```
active → archived (↻ after end_date) | cancelled (user)
```

### Hike (`hikes.status`)
```
draft → open ⇄ full → confirmed → in_progress → completed
  any pre-completion state → cancelled (host)
open⇄full is automatic on member count vs max_members
```

### Hike membership (`hike_members.status`)
```
requested → approved | declined
approved → removed (host) | left (member)
```

### Safety plan (`safety_plans.status`)
```
active → checked_in (user) | escalated (↻ cron: now > expected_return_at + 30min grace)
escalated → checked_in (all-clear SMS sent)
active → cancelled (user) | expired (↻ 24h hard stop)
```

### Message media (`messages.media_moderation`)
```
pending → approved | rejected   (hidden until approved)
```

### Report (`reports.status`)
```
open → actioned | dismissed   (audit row required for actioned)
```

## 3.2 Master Gating Table (capability × account state)

| Capability | Guest (unverified/pending/needs_review) | Verified active | Warned | Suspended | Banned |
|---|---|---|---|---|---|
| Browse parks/trails/weather (`S-EXP-01…04`, `S-SAFE-06` public part) | ✅ | ✅ | ✅ | ❌ (interstitial) | ❌ |
| See any member profile / trip / hike / photo | ❌ (API returns nothing — RLS) | ✅ | ✅ | ❌ | ❌ |
| Post trip / hike, request, invite | ❌ → `S-EXP-05` | ✅ | ✅ | ❌ | ❌ |
| Chat | ❌ | ✅ (participants only) | ✅ | ❌ | ❌ |
| Safety tools (contacts, plan, check-in) | contacts setup allowed; rest needs membership | ✅ | ✅ | in-flight plans complete; no new | in-flight plans complete |
| Report / block | ❌ (nothing visible to report) | ✅ | ✅ | ❌ | ❌ |
| Appear in others' overlap/discovery | ❌ | ✅ | ✅ | ❌ | ❌ |

`visibility='similar_experience'` trips additionally filter both directions by ±1 experience level.

## 3.3 Copy Library (normative additions to per-screen copy)

**Voice:** capable outdoorswoman — warm, direct, competence-first. Never dating language (no "match made", hearts, flames, swipes). "Trail sisters", "hiking partners", "group hikes" (PRD §16.3). Safety copy is explicit about limits (coverage caveat everywhere escalation is mentioned).

- App-wide errors: offline banner *"You're offline — showing saved info."* · generic *"Something went wrong. Try again."* · retry button always present.
- Push templates: mirror `S-NOTIF-01` row templates. Safety check-in push: title **"Are you safe?"** body *"Tap 'I'm safe' or open TrailSisters — otherwise we'll alert your trusted contacts at {time}."* (time-sensitive; actions: "I'm safe" / "Need 30 more min").
- SMS templates: normative in `S-SAFE-03` / `S-SAFE-04`. All SMS end with *"Reply STOP to opt out."* (PRD §3.8 AC).
- Age display: DOB → decade string ("20s", "30s", "40s"…); exact age never rendered anywhere.
- Attribution strings: *"Data: National Park Service"* · *"Contains information licensed under the Open Government Licence – Canada"* · OSM rows: *"© OpenStreetMap contributors, ODbL"* (PRD §10).

## 3.4 Push Notification Matrix (PRD §3.11)

| Kind | Trigger | Priority | Deep link | User-disableable |
|---|---|---|---|---|
| `match_request` | say-hi received | standard | `S-HOME-02` | ✅ |
| `match_accepted` | request accepted | standard | `S-CHAT-02` | ✅ |
| `hike_join_request` | join requested | standard | `S-HIKE-03` | ✅ |
| `hike_approved` | host approved | standard | `S-HIKE-02` | ✅ |
| `hike_updated` / `hike_cancelled` | host edit/cancel | standard | `S-HIKE-02` | ✅ |
| `hike_reminder` | T-24h, T-2h | standard | `S-HIKE-02` | ✅ |
| `message` | new message (thread unmuted) | standard | `S-CHAT-02` | ✅ (per-thread mute) |
| `trip_nudge` | ↻ cron T-14/5/2d | standard | `S-TRIP-03` | ✅ |
| `safety_checkin` | T+0 expected return | **time-sensitive** | `S-SAFE-04` prompt | ❌ while hike active |
| `verification` | status flip | standard | route table | ❌ |
| `moderation_outcome` | report actioned / enforcement | standard | `S-NOTIF-01` | ✅ (outcomes) |

Time-sensitive entitlement is used **only** by `safety_checkin` (PRD §3.11 AC).

## 3.5 Empty-State Inventory (every one proposes an action — PRD §4)

| Where | Line | Action |
|---|---|---|
| Home, no trips | "Where are you headed next?" | Post a trip · Browse flagship parks |
| Trip detail, no overlaps | "No overlaps yet…" (flagship + flexibility hint) | Adjust dates |
| Requests inbox | "No requests right now…" | — (informational, links Home) |
| Chats | "Chats open when a connection is made…" | See requests · Find a hike |
| Notifications | "Nothing yet…" | — |
| Park with no trails | "Trail data coming soon" | Post a trip here |
| Filters zero-result | "No trails match" | Loosen a filter (reset) |
| Blocked list | "You haven't blocked anyone." | — |

## 3.6 Phase-to-Screen Index

| Roadmap phase | Screens introduced/modified |
|---|---|
| 0 | (infra only) `S-ONB-01` shell |
| 1 | Design primitives (0.4), debug preview screen |
| 2–3 | (data + maps infra feeding `S-EXP-*`) |
| 4 | `S-ONB-01…04`, `S-AUTH-01…04`, `S-LEGAL-01`, `S-AGE-01` |
| 5 | `S-VER-01…05`, `S-EXP-05` |
| 6 | `S-PROF-01…06`, `S-ME-01`, `S-ME-02`, `S-USER-01` (view-only) |
| 7 | `S-EXP-01…04` |
| 8 | `S-HOME-01` (trips sections), `S-HOME-02` (trip requests), `S-PLAN-01` (trips), `S-TRIP-01…04` |
| 9 | `S-HIKE-01…04`, `S-HOME-01/02` hike sections, `S-PLAN-01` hikes, `S-TRIP-04` invite variant |
| 10 | `S-CHAT-01…02` |
| 11 | `S-HIKE-05…06`, `S-SAFE-01…06`, `W-SHARE-01` |
| 12 | `S-NOTIF-01`, `S-ME-04` |
| 13 | `S-MOD-01…03`, `S-ME-03`, `A-ADM-01…05` |
| 14 | `S-ME-05`, launch-readiness passes over all |
| 15 | `S-EXP-06…07`, `S-HIKE-07`, `S-HIKE-06` conditions step, `S-EXP-03` conditions section |

---

*End of App Workflow Specification.*
