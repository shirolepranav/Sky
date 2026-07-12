# PRD + Technical Specification
## "TrailSisters" (working title) — Women-First Hiking Partner App for US & Canadian National Parks

**Version:** 1.0 | **Date:** July 2026 | **Owner:** Solo iOS Developer
**Purpose of this document:** A complete, self-contained specification that an AI coding agent (Claude Code, Cursor, etc.) can use to build this app. It contains product requirements, acceptance criteria, data models, API design, external service integrations, and phased build order. Follow the build phases in order. Do not build P2 features before P0 features pass acceptance criteria.

---

# PART 1 — PRODUCT REQUIREMENTS DOCUMENT (PRD)

## 1. Product Overview

### 1.1 One-liner
A free, women-only iOS app where women find verified hiking partners for specific trails in US and Canadian national parks, matched by destination and overlapping trip dates.

### 1.2 Problem
- Women are ~52% of hikers but many won't hike alone for safety reasons, and won't meet strangers from generic apps for remote outdoor activities.
- National park hikers are mostly out-of-town visitors, so location-based "people near me" matching fails.
- Existing tools (Facebook groups, Meetup, AllTrails) lack verified identity, structured partner matching, and hike-specific safety tooling.

### 1.3 Solution
- **Women-only accounts** verified via third-party ID + liveness selfie check (Face ID-style), with zero raw-ID storage in our systems.
- **Trip-based matching:** users post a trip ("Zion, Oct 3–7") and match with other verified women whose trips overlap at the same destination.
- **Group-first hikes:** the core unit is a group hike (2–8 women) attached to a specific trail, not 1:1 dates.
- **Free safety suite:** check-in timers, live location sharing, offline maps, offline trailhead/SOS info — features competitors paywall.

### 1.4 Goals (in priority order)
1. Maximum user growth (free app; no monetization at launch).
2. Establish trust: high verification rate, high female-perceived-safety scores.
3. Match liquidity: a trip posted at a flagship park gets ≥1 relevant match suggestion within 24h during peak season.

### 1.5 Non-Goals (explicitly out of scope for v1)
- Male accounts of any kind (deferred to Phase 3 "invited male guest" — designed for, not built).
- Android app (iOS only).
- Monetization, payments, subscriptions.
- Dating/romance framing of any kind — copy, UI, and prompts must read as activity-partner finding.
- 1:1 spontaneous "48-hour" matching (the original mechanic is replaced by trip-date windows; a soft "happening soon" filter is P2).
- Trails outside US/Canadian national parks (schema supports expansion; content does not ship).
- User-generated trail creation (users pick from the curated database only).

### 1.6 Target Users (personas)
- **P1 "Solo Park Traveler" (primary):** 25–45, plans national park trips 1–6 months ahead, travels alone or wants to peel off from family for a big hike, top concern is safety. Growth persona.
- **P2 "Local Chapter Hiker":** lives near a park/trail town, hikes most weekends, joins/hosts group hikes, becomes an ambassador. Retention/liquidity persona.
- **P3 "Nervous First-Timer":** wants to start hiking but won't go alone; joins easy group hikes; heavy consumer of safety content and checklists.

### 1.7 Success Metrics
| Metric | Target (first 2 peak seasons) |
|---|---|
| Verified-account completion rate | ≥ 60% of signups complete verification |
| Trip → match rate (flagship parks, peak) | ≥ 40% of trips get ≥1 accepted match |
| Hike completion ("marked as hiked") | ≥ 50% of confirmed group hikes |
| D30 retention (verified users) | ≥ 25% |
| Reports actioned within 24h | 100% (App Store 1.2 requirement) |
| Safety-feature adoption | ≥ 50% of hikes use check-in timer or live share |

---

## 2. Core Product Rules (invariants — enforce in code and copy)

1. **Women-only:** only users who pass gender-inclusive verification (see §6) can browse, match, chat, or join hikes. Trans women are women and are included; verification provider settings must not be configured to exclude them.
2. **No raw ID storage:** government ID images, ID numbers, and biometric templates are NEVER stored in our database or storage buckets. Only the verification provider's session ID, status, and a boolean outcome are stored. This is non-negotiable (Tea-app breach lesson).
3. **Group-first:** hikes support 2–8 participants. 1:1 hikes are allowed but the UI defaults to and encourages groups of 3+.
4. **Match before chat:** users cannot message anyone until a mutual connection exists (join request accepted, or mutual trip match accepted).
5. **No swiping:** discovery is list/card-grid based with explicit "Request to join" / "Invite" buttons. No swipe gestures anywhere in matching UI.
6. **Safety is never paywalled** (relevant later; for v1 everything is free anyway).
7. **Privacy defaults:** exact home location never shown; age shown as range (e.g., "30s") by default; last name never shown; profile photos hidden from unverified accounts.
8. **Server-authoritative:** trip windows, hike times, membership, and verification status are enforced server-side (RLS + edge functions), never trusted from the client.

---

## 3. Feature Specification

Features are labeled **P0** (MVP, must ship), **P1** (fast-follow, weeks after launch), **P2** (later). Each has acceptance criteria (AC).

### 3.1 Onboarding & Account Creation — P0
**Flow:** Splash → value proposition carousel (3 screens: "Find your trail sisters", "Verified women only", "Safety built in") → Sign in with Apple (primary) or email/password → phone number + SMS OTP → identity verification (§6) → profile setup wizard → home feed.

- Sign in with Apple is the primary auth CTA (required by Apple when third-party login exists).
- Phone verification via SMS OTP is required before verification step (bot gate).
- Users may browse the trail database in read-only "guest preview" mode before verifying, but cannot see any user profiles, trips, or hikes.
- Declared age must be ≥ 18. Use date-of-birth entry; block and delete accounts under 18. App Store age rating: 17+.
- **AC:** A new user can go from install → verified → complete profile in under 8 minutes. An unverified user can never retrieve another user's profile via API (verified via RLS test).

### 3.2 Identity & Gender Verification — P0 (see §6 for full spec)
Two-step: (a) **Liveness selfie check** (Face ID-style guided video selfie, anti-spoofing) matched against (b) **government ID document** — both handled entirely by Stripe Identity (primary choice) inside their hosted/native sheet. We receive webhook events only.

- Verification states: `unverified → pending → verified | failed | needs_review`.
- `needs_review` goes to an admin queue (manual approval in admin dashboard).
- Verified users get a **"Verified" badge** (checkmark + shield) on their profile.
- Re-verification can be triggered by admin (e.g., after credible impersonation report).
- **AC:** No table, bucket, or log in our infrastructure ever contains an ID image, ID number, or face template. Grep-able proof: the only verification fields stored are `stripe_verification_session_id`, `status`, `verified_at`.

### 3.3 Profiles — P0
Capability-first design (reads as competence-matching, not dating).

**Required fields:** first name, date of birth (shown as age range), pronouns (optional display), home region (city/state level only), profile photo (face visible; moderated), hiking experience level (Beginner / Intermediate / Advanced / Expert), typical pace (Casual <2 mph / Steady 2–3 mph / Fast 3+ mph), comfortable distance (<5 mi / 5–10 mi / 10–15 mi / 15+ mi), comfortable elevation gain (<1,000 ft / 1,000–2,500 ft / 2,500+ ft).

**Optional fields:** terrain experience (multi-select: scrambling, snow/microspikes, exposure/heights, river crossings, high altitude, desert), hike types (day hikes, backpacking, peak-bagging, trail running, photography walks, birding), preferred start times (dawn / morning / afternoon / flexible), camping/backpacking experience (none → expert), first-aid or WFR certification (self-declared + badge), carries satellite communicator (InReach/PLB — badge), navigation confidence (1–5), has car / can drive to trailheads / open to carpool, brings a dog / dog-friendly, languages spoken, music-on-trail vs. quiet preference, Leave No Trace familiarity, group size preference (small 2–3 / medium 4–6 / any), 3 short prompts (pick from list, e.g., "My most memorable hike…", "My ideal trail day…", "I'm working toward…"), up to 6 photos.

- Photos pass automated moderation (§3.10) before becoming visible.
- **AC:** Profile completeness meter; profiles ≥80% complete are labeled and rank higher in discovery. Sensitive fields (exact age, last name, home city) are excluded from all API responses to other users.

### 3.4 Trail Database & Discovery — P0
Pre-imported, curated database of official trails in US and Canadian national parks (import pipeline in Part 2 §10).

- **Park browser:** searchable list + map of national parks (US: NPS units filtered to National Parks for v1 content; CA: Parks Canada national parks). Park page: description, alerts (NPS API), seasonal notes, trails list.
- **Trail page:** name, park, length, elevation gain, estimated difficulty (computed: distance + gain formula), route drawn on map, elevation profile chart, trailhead coordinates + parking notes, permit-required flag + link, current weather + 7-day forecast (Open-Meteo), AQI (AirNow/AQICN), sunrise/sunset + golden hour, recent user-submitted trail conditions (P1), "Plan a hike here" CTA.
- **Filters:** park, difficulty, length, elevation gain, dog-allowed (where known).
- **AC:** Trail pages load offline if previously viewed (cached). Difficulty formula is deterministic and unit-tested. Every trail has geometry rendering correctly on the map.

### 3.5 Trips (the density solution) — P0
A **Trip** = "I will be at [park] from [start date] to [end date]." This is the primary matching object.

- Create trip: pick park → date range → optional intent note (280 chars) → optional target trails (multi-select) → visibility (all verified women / women in my experience range).
- Trips are visible to other verified women with overlapping dates at the same park, sorted by date-overlap length, then profile compatibility (pace + experience proximity).
- From a trip, users can: **"Say hi"** (sends a trip-match request with optional note) or **"Invite to my hike"** (if they have a hike planned there).
- Accepting a trip-match request opens a chat thread between the two users.
- Trips auto-archive after end date. Users can post trips up to 12 months ahead.
- **Matching window replaces the old 48-hour idea:** matching is open from trip creation until trip end. A soft urgency nudge ("Your trip is in 5 days — 3 women overlap with your dates") is sent via push at T-14d, T-5d, T-2d.
- **AC:** Overlap query is index-backed (see schema) and returns in <200 ms for a park with 5,000 trips. A user with no overlapping trips sees a friendly empty state suggesting flagship parks + date flexibility, never a blank screen.

### 3.6 Group Hikes — P0
A **Hike** = a specific plan: trail + date + start time + group.

- Create hike: pick trail (from a trip context or directly) → date + start time → group size limit (2–8) → pace/experience expectations → meetup point (defaults to trailhead; free text allowed but UI nudges "meet at trailhead") → description → visibility (public to verified women / invite-only).
- Other users **request to join**; host approves/declines. Approved members enter the hike's **group chat**.
- Hike states: `draft → open → full → confirmed → in_progress → completed | cancelled`.
- Host controls: approve/remove members, edit details (members notified), cancel (members notified).
- Day-of: "Start hike" button activates the safety suite (§3.8) for opted-in members; "Complete hike" prompts stats + optional trail-condition report + optional kudos to companions.
- Attendance: after completion, members can privately flag no-shows (3 no-show flags → warning; pattern → suspension).
- **AC:** A hike cannot be created in the past; membership changes are transactional; removed members lose chat access immediately (RLS-enforced).

### 3.7 Chat — P0
- 1:1 chat (from accepted trip match) and group chat (per hike). Supabase Realtime channels.
- Text + photos (photos pass moderation pipeline). No voice/video v1.
- Blocked users' messages are hidden bidirectionally; blocking removes match/connection.
- Every message long-press → Report.
- Push notification on new message (respecting per-thread mute).
- Profanity/abuse filter runs on send (client hint) + server (authoritative; flags to moderation queue rather than hard-blocking borderline cases).
- **AC:** Users who share no accepted connection/hike cannot open or post to a thread (RLS test). Media messages are hidden until moderation passes (<10 s p95).

### 3.8 Safety Suite — P0 (the differentiator; all free)
1. **Trusted contacts:** user adds up to 3 contacts (name + phone). Stored locally + server. Contacts don't need the app; they receive SMS links.
2. **Share my plan:** one tap from a hike → SMS/share-sheet message to trusted contacts containing: trail name, park, trailhead coordinates + map link, start time, expected return time, group size, and first names of companions. Rendered as a hosted, tokenized, expiring web page (no login needed).
3. **Check-in timer:** user sets expected return time (default: trail estimated duration × 1.3). At T+0 the app prompts "Are you safe?"; if no response in 30 min AND the phone regains connectivity, an SMS is sent to trusted contacts with last-known location. Copy must be explicit that this depends on cell coverage and is not an emergency service.
4. **Live location share:** during an active hike, optional location sharing (a) with hike group members in-app, (b) with trusted contacts via tokenized web link. Uses significant-location updates to preserve battery; stops automatically on "Complete hike" or after 24 h.
5. **Offline safety card:** every trail page has a downloadable offline card: trailhead coordinates, nearest ranger station + phone, park emergency number, nearest hospital, cell-coverage caveat, and the user's own plan summary.
6. **Safety Center screen:** static content — partner-vetting tips, trailhead-meeting guidance, wildlife basics, 10 essentials checklist (interactive, P1), Leave No Trace, links to report a user.
- **AC:** Check-in escalation fires from a server-side scheduled job (not client-only). All SMS include opt-out language. Live-share links expire and are revocable. Feature works end-to-end in airplane-mode simulation with delayed reconnect.

### 3.9 Weather, AQI & Environment — P0 (data), P1 (polish)
- Weather: Open-Meteo forecast API per trailhead coordinate (free, no key). Cache server-side 30 min.
- AQI: AirNow API (US) + AQICN (Canada fallback). Show banner on trail pages when AQI > 100 (wildfire-smoke relevance).
- Sunrise/sunset/golden hour: computed on-device (solar math, no API).
- P1: NWS alerts (api.weather.gov) surfaced on US trail pages; Environment Canada alerts for CA.
- **AC:** Weather failures degrade gracefully (cached/stale label), never block trail page render.

### 3.10 Moderation, Reporting & Blocking — P0 (Apple Guideline 1.2 — hard launch requirement)
- **Report:** any profile, message, photo, hike, or trip → report with category (impersonation/not a woman, harassment, safety concern, spam, inappropriate content, no-show, other) + free text. Reporter gets confirmation + follow-up notification when actioned.
- **Block:** any user; hides all content bidirectionally, removes connections, prevents future matching.
- **Automated screening:** all uploaded images pass a moderation API (nudity/violence) before visibility; message text passes a toxicity filter; flagged items → queue.
- **Admin dashboard (web, internal):** queues for reports, flagged media, verification `needs_review`; actions: dismiss, warn, remove content, suspend (7/30 d), ban; audit log; SLA timer surfacing items older than 12 h (target action <24 h).
- **Enforcement ladder:** warn → temporary suspension → permanent ban. Impersonation (male account) = immediate ban.
- EULA/Terms acceptance at signup including zero-tolerance objectionable-content clause; in-app contact/support link.
- **AC:** Report-to-queue latency <5 s. A banned user's sessions are killed and content hidden within 60 s. Dashboard demonstrates the full 1.2 checklist for App Review notes.

### 3.11 Notifications — P0
Push (APNs) + in-app inbox: trip-match requests/accepts, hike join requests/approvals, hike changes/cancellations/reminders (T-24h, T-2h), new messages, trip urgency nudges (§3.5), safety check-in prompts (time-critical channel), moderation outcomes.
- Granular per-category settings; safety notifications cannot be disabled while a hike is active.
- **AC:** Time-sensitive entitlement used only for safety check-ins; all others standard priority.

### 3.12 Offline Maps — P1 (scaffold in P0)
- Vector tiles: Protomaps PMTiles extracts covering national-park bounding boxes, hosted on Cloudflare R2, rendered with MapLibre Native.
- P0: MapLibre renders online from R2-hosted PMTiles (cheap); trail geometry overlays from bundled/cached GeoJSON.
- P1: "Download park" button — park tile pack + trails + safety cards stored locally; target ≤ 60 MB per park at zooms 8–14.
- **AC (P1):** Full trail page + map + safety card usable in airplane mode after download.

### 3.13 GPX Recording & Hike Stats — P1
- Record track during active hike (Core Location, background); live distance/elevation/duration; save + export GPX via share sheet.
- Post-hike stats: distance, gain, duration, moving time; lifetime totals; badges P2 (first hike, 5 group hikes, 3 parks, safety-feature streak).
- **AC:** 6-hour recording consumes <15% battery on a modern iPhone (adaptive GPS sampling).

### 3.14 Trail Conditions & Reviews — P1
- Post-hike prompt + standalone: condition tags (snow, mud, downed trees, water crossing high, trail clear, crowded, bugs, wildlife sighting) + optional note/photo + date. Shown on trail page, newest first, auto-expire from summary after 30 days.
- **AC:** Conditions render on trail page within 1 min of posting (post-moderation for photos).

### 3.15 Community Layer (home-city) — P2
Chapters (metro-level groups), local recurring hikes, ambassador tools (host badges, chapter feeds). Ship only after destination liquidity proven.

### 3.16 Invited Male Guest — Phase 3 (DESIGN ONLY — do not build)
Future rule: a hike with ≥2 confirmed women may generate a single-use invite link for one male guest with a guest-scoped account (no browse, no discovery, no chat history, visible "Guest" label). Schema includes `hike_members.role` enum (`host|member|male_guest`) so this is additive later. Do not expose any male-facing UI in v1.

---

## 4. UX / Design Requirements

- **Tone:** capable-outdoorswoman, warm but not cutesy; zero dating-app visual language (no hearts, no pink-by-default, no swipe affordances). Think AllTrails × Airbnb trust patterns.
- Design system: SwiftUI, SF Symbols, dynamic type, dark mode, VoiceOver labels on all interactive elements (accessibility is a launch requirement, not a polish item).
- Tab bar (5): **Home** (trips/matches feed) · **Explore** (parks & trails) · **Plan** (+ create trip/hike) · **Chats** · **Profile**.
- Empty states always propose an action (create trip, browse flagship parks, invite friends).
- Verified badge visually prominent on every avatar.
- Onboarding must communicate the two trust pillars in ≤2 screens: "Every member is a verified woman" and "Your ID is checked by a secure third party and never stored by us."

## 5. Legal / Compliance Requirements (build-time)

- Terms of Service + assumption-of-risk + arbitration clause + class-action waiver acceptance flow at signup (content supplied by lawyer; app must version and re-prompt on changes).
- Privacy policy URL + App Store privacy nutrition labels: location (when-in-use + background for live share), photos, phone number, contacts (manual entry only — do NOT request contacts permission), identifiers.
- In-app **account deletion** (Apple requirement): deletes profile, media, messages content (tombstoned in threads), trips/hikes memberships; retains minimal legal audit rows (user id, ban history) per ToS.
- Age gate 18+; App Store rating 17+; UGC boxes checked with moderation/report/block affirmed.
- Canada: PIPEDA-aligned data handling; US: CCPA delete/export honored via account deletion + data export (P1: JSON export via support).
- Trans-inclusive verification policy documented in Help Center.

## 6. Verification Specification (CRITICAL FEATURE)

**Provider: Stripe Identity** (fallback candidate: Persona). Rationale: native iOS sheet, document + selfie **with liveness detection** (guided face capture, anti-spoof — the "Face ID-like" experience requested), ~$1.50/verification, and Stripe retains the sensitive artifacts so we never touch them.

**Flow:**
1. After SMS OTP, client requests `POST /edge/create-verification-session` (Supabase Edge Function).
2. Edge function calls Stripe API to create a VerificationSession with: `type: document`, options `document: { require_matching_selfie: true, require_live_capture: true }`.
3. Client opens Stripe's native verification sheet using the returned ephemeral key/client secret. User photographs government ID + performs guided selfie video/liveness capture.
4. Stripe webhook → `POST /edge/stripe-identity-webhook` (signature-verified): on `verification_session.verified`, edge function checks the reported document sex/gender marker where available and sets `profiles.verification_status`. **Policy: gender markers on IDs are unreliable and exclusionary for some trans women** → default automation: liveness+document validity gates authenticity; accounts whose signals are ambiguous or mismatched route to `needs_review` for human review under the inclusive policy, never auto-reject on marker alone.
5. We store ONLY: `stripe_verification_session_id`, `status`, `verified_at`, `failure_reason_code`. Configure Stripe Identity data retention to minimum; enable redaction API call 30 days post-decision (P1 cron).

**Anti-catfish reinforcement (defense in depth):** liveness capture defeats "photo of a woman" spoofs; periodic re-verification on credible reports; profile photos must contain a face (on-device Vision check) and admin can require a new liveness pass; device fingerprint + phone number uniqueness (one account per number).

**Cost control:** verification is triggered only after SMS OTP + basic profile intent (reduces drive-by cost); first 50/month free on Stripe, then ~$1.50 each — at 1,000 verifications/month ≈ $1,425/month worst case; acceptable given it IS the product's moat. Add an admin kill-switch to queue verifications (invite-list mode) if volume spikes beyond budget.

---

# END OF PART 1

---

# PART 2 — TECHNICAL SPECIFICATION

## 7. Architecture Overview

```
┌─────────────────────────────┐
│  iOS App (Swift / SwiftUI)  │  MapLibre Native, Stripe Identity SDK,
│  iOS 17+ minimum            │  Supabase Swift SDK, APNs
└──────────────┬──────────────┘
               │ HTTPS / WSS
┌──────────────▼──────────────┐
│  Supabase (managed)         │
│  • Postgres + PostGIS       │  ← all app data, geo queries
│  • Auth (Apple/email + OTP) │
│  • Realtime (chat)          │
│  • Storage (user media)     │
│  • Edge Functions (Deno/TS) │  ← webhooks, SMS, moderation, jobs
└───────┬─────────┬───────────┘
        │         │
┌───────▼──┐  ┌───▼──────────────────────────────┐
│ Cron jobs│  │ External services                │
│ (pg_cron)│  │ Stripe Identity · Twilio SMS ·   │
└──────────┘  │ Open-Meteo · AirNow/AQICN ·      │
              │ NPS API · Sightengine/Hive       │
              │ (media moderation) · APNs ·      │
              │ Cloudflare R2 (PMTiles + shared  │
              │ safety pages via Worker)         │
              └──────────────────────────────────┘
```

**Stack decisions (final):**
| Layer | Choice | Why |
|---|---|---|
| iOS | Swift 5.10+, SwiftUI, iOS 17+, MVVM + Swift Concurrency | Native quality; solo-dev velocity |
| Maps | MapLibre Native iOS + PMTiles (Protomaps) on Cloudflare R2 | Free/near-free, offline-capable; avoid MapKit lock-in for offline needs |
| Backend | Supabase Pro ($25/mo flat) | Relational matching queries, RLS security, Realtime chat, predictable cost |
| Geo | PostGIS extension | Trail geometry, distance queries, bounding boxes |
| Push | APNs direct (via edge function using `apns2`-style JWT) | No FCM dependency needed for iOS-only |
| SMS | Twilio (OTP via Supabase Auth phone provider; safety SMS via edge function) | Reliable, pay-per-use |
| ID verification | Stripe Identity (document + selfie liveness) | See PRD §6 |
| Media moderation | Sightengine or Hive AI (nudity/violence classes) | Pay-per-image, cheap at launch scale |
| Weather | Open-Meteo (no key) | Free, includes NWS + Env Canada models |
| AQI | AirNow (US) + AQICN (fallback/CA) | Free with API keys |
| Analytics | TelemetryDeck or PostHog (EU-hostable) | Privacy-respecting; no ad SDKs ever |
| Crash | Sentry or MetricKit + Sentry | Standard |

**Estimated running cost, launch scale (<10k MAU):** Supabase $25 + R2 ~$5 + Twilio ~$50–150 + moderation ~$10–30 + Apple $99/yr + verification (variable, see PRD §6) ≈ **$100–250/mo + verification volume**.

---

## 8. Data Model (Postgres — authoritative schema)

Conventions: `uuid` PKs (`gen_random_uuid()`), `created_at/updated_at timestamptz` on every table (triggers), soft-delete via `deleted_at` where noted, all FKs indexed. Comments explain intent for maintainers.

```sql
-- Enable required extensions
create extension if not exists postgis;      -- trail geometry & geo queries
create extension if not exists pg_cron;      -- scheduled jobs (check-in escalation, digests)

-- ═══════════════ USERS & VERIFICATION ═══════════════

-- Mirrors auth.users (Supabase Auth). One row per account.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null,
  date_of_birth date not null,               -- never exposed raw; age-range computed in views
  pronouns text,
  home_region text,                          -- city/state granularity only, free text
  bio text check (char_length(bio) <= 500),
  experience_level text not null check (experience_level in ('beginner','intermediate','advanced','expert')),
  pace text not null check (pace in ('casual','steady','fast')),
  distance_comfort text not null check (distance_comfort in ('lt5','5to10','10to15','gt15')),
  elevation_comfort text not null check (elevation_comfort in ('lt1000','1000to2500','gt2500')),
  terrain_experience text[] default '{}',    -- e.g. {'scrambling','snow','exposure'}
  hike_types text[] default '{}',
  start_time_pref text[] default '{}',
  camping_experience text,
  first_aid_cert boolean default false,      -- self-declared; renders a badge
  has_satellite_communicator boolean default false,
  navigation_confidence int check (navigation_confidence between 1 and 5),
  has_car boolean,
  open_to_carpool boolean,
  dog_friendly boolean,
  brings_dog boolean,
  languages text[] default '{}',
  quiet_preference text,                     -- 'quiet' | 'chatty' | 'either'
  group_size_pref text,                      -- 'small' | 'medium' | 'any'
  prompts jsonb default '[]',                -- [{"q": "...", "a": "..."}] max 3
  completeness int default 0,                -- 0-100, recomputed by trigger
  -- VERIFICATION: only these fields. NEVER store ID images/numbers/biometrics.
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','failed','needs_review')),
  stripe_verification_session_id text,       -- opaque reference into Stripe; safe to store
  verified_at timestamptz,
  verification_failure_code text,
  -- moderation state
  account_status text not null default 'active'
    check (account_status in ('active','warned','suspended','banned')),
  suspension_until timestamptz,
  phone_hash text unique,                    -- sha256 of E.164 phone; enforces 1 account/number
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index on profiles (verification_status);
create index on profiles (account_status);

create table profile_photos (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  storage_path text not null,                -- Supabase Storage object path
  position int not null default 0,           -- display order, 0 = primary
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create index on profile_photos (profile_id, position);

-- Trusted contacts for the safety suite. Manually entered, never from address book API.
create table trusted_contacts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  phone_e164 text not null,
  created_at timestamptz not null default now(),
  constraint max_three unique (profile_id, phone_e164)
);

-- ═══════════════ PARKS & TRAILS (imported content) ═══════════════

create table parks (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('nps','parks_canada')),
  source_code text not null,                 -- NPS unitCode (e.g. 'ZION') or Parks Canada id
  name text not null,
  country text not null check (country in ('US','CA')),
  state_province text,
  description text,
  boundary geometry(MultiPolygon, 4326),     -- for map + point-in-park queries
  centroid geometry(Point, 4326),
  emergency_phone text,                      -- park dispatch/emergency number (curated)
  nearest_hospital text,                     -- curated safety-card content
  official_url text,
  is_flagship boolean default false,         -- launch-focus parks get feed priority
  unique (source, source_code)
);
create index parks_centroid_gix on parks using gist (centroid);

create table trails (
  id uuid primary key default gen_random_uuid(),
  park_id uuid not null references parks(id) on delete cascade,
  source text not null,                      -- 'nps_public_trails' | 'parks_canada_apca' | 'osm'
  source_id text,
  name text not null,
  geometry geometry(MultiLineString, 4326) not null,
  length_km numeric not null,
  elevation_gain_m numeric,                  -- computed from DEM in import pipeline
  elevation_profile jsonb,                   -- [[dist_km, elev_m], ...] downsampled ~200 pts
  difficulty text check (difficulty in ('easy','moderate','hard','very_hard')),  -- computed
  route_type text,                           -- 'loop' | 'out_and_back' | 'point_to_point'
  trailhead geometry(Point, 4326),
  trailhead_notes text,                      -- parking, shuttle, curated
  permit_required boolean default false,
  permit_url text,
  dogs_allowed boolean,                      -- null = unknown
  attribution text not null,                 -- license attribution string (ODbL if OSM)
  est_duration_min int                       -- Naismith-based estimate; feeds check-in default
);
create index trails_geom_gix on trails using gist (geometry);
create index on trails (park_id);

-- User-generated trail condition reports (P1)
create table trail_conditions (
  id uuid primary key default gen_random_uuid(),
  trail_id uuid not null references trails(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete set null,
  tags text[] not null,                      -- {'snow','mud','clear',...}
  note text check (char_length(note) <= 500),
  photo_path text,
  moderation_status text not null default 'approved',  -- text auto-ok; photos gate on pipeline
  hiked_on date not null,
  created_at timestamptz not null default now()
);
create index on trail_conditions (trail_id, created_at desc);

-- ═══════════════ TRIPS & MATCHING ═══════════════

create table trips (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  park_id uuid not null references parks(id),
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  note text check (char_length(note) <= 280),
  target_trail_ids uuid[] default '{}',
  visibility text not null default 'all' check (visibility in ('all','similar_experience')),
  status text not null default 'active' check (status in ('active','archived','cancelled')),
  created_at timestamptz not null default now()
);
-- THE core matching index: find overlapping trips at a park fast
create index trips_overlap_idx on trips (park_id, start_date, end_date) where status = 'active';

-- A "say hi" between two overlapping trips. Accepting creates a connection + 1:1 thread.
create table trip_match_requests (
  id uuid primary key default gen_random_uuid(),
  from_trip_id uuid not null references trips(id) on delete cascade,
  to_trip_id uuid not null references trips(id) on delete cascade,
  from_profile_id uuid not null references profiles(id) on delete cascade,
  to_profile_id uuid not null references profiles(id) on delete cascade,
  note text check (char_length(note) <= 280),
  status text not null default 'pending' check (status in ('pending','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  unique (from_profile_id, to_trip_id)       -- one request per person per target trip
);

-- Mutual connections (result of accepted requests). Gate for 1:1 chat.
create table connections (
  id uuid primary key default gen_random_uuid(),
  profile_a uuid not null references profiles(id) on delete cascade,
  profile_b uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint ordered_pair check (profile_a < profile_b),  -- canonical ordering prevents dupes
  unique (profile_a, profile_b)
);

-- ═══════════════ HIKES ═══════════════

create table hikes (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  trail_id uuid not null references trails(id),
  park_id uuid not null references parks(id),
  hike_date date not null,
  start_time time not null,
  timezone text not null,                    -- park's IANA tz, resolved at creation
  max_members int not null default 4 check (max_members between 2 and 8),
  pace_expectation text,
  experience_expectation text,
  meetup_point text not null default 'Trailhead',
  description text check (char_length(description) <= 1000),
  visibility text not null default 'public' check (visibility in ('public','invite_only')),
  status text not null default 'open'
    check (status in ('draft','open','full','confirmed','in_progress','completed','cancelled')),
  created_at timestamptz not null default now()
);
create index on hikes (park_id, hike_date) where status in ('open','full','confirmed');

create table hike_members (
  id uuid primary key default gen_random_uuid(),
  hike_id uuid not null references hikes(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('host','member','male_guest')), -- male_guest: Phase 3 only
  status text not null default 'requested'
    check (status in ('requested','approved','declined','removed','left')),
  no_show_flags int default 0,
  created_at timestamptz not null default now(),
  unique (hike_id, profile_id)
);

-- ═══════════════ CHAT ═══════════════

create table threads (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('dm','hike')),
  connection_id uuid references connections(id) on delete cascade,  -- set when kind='dm'
  hike_id uuid references hikes(id) on delete cascade,              -- set when kind='hike'
  created_at timestamptz not null default now(),
  check ((kind='dm' and connection_id is not null) or (kind='hike' and hike_id is not null))
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references threads(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text,                                  -- null for pure-media messages
  media_path text,
  media_moderation text default null check (media_moderation in (null,'pending','approved','rejected')),
  toxicity_flagged boolean default false,     -- server filter result; queued if true
  created_at timestamptz not null default now(),
  deleted_at timestamptz                      -- tombstone on account deletion
);
create index on messages (thread_id, created_at desc);

-- ═══════════════ SAFETY SUITE ═══════════════

-- One active plan per hike per user; drives check-in escalation job.
create table safety_plans (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  hike_id uuid references hikes(id) on delete set null,
  trail_id uuid not null references trails(id),
  expected_return_at timestamptz not null,
  share_token text unique not null,           -- random 32-byte token for the public status page
  live_share_enabled boolean default false,
  last_known_location geometry(Point, 4326),
  last_location_at timestamptz,
  status text not null default 'active'
    check (status in ('active','checked_in','escalated','expired','cancelled')),
  escalated_at timestamptz,
  created_at timestamptz not null default now()
);
create index on safety_plans (status, expected_return_at); -- cron scans this

-- ═══════════════ MODERATION ═══════════════

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete set null,
  target_profile_id uuid references profiles(id) on delete set null,
  target_type text not null check (target_type in ('profile','message','photo','hike','trip','condition')),
  target_id uuid not null,
  category text not null check (category in
    ('impersonation','harassment','safety_concern','spam','inappropriate','no_show','other')),
  detail text,
  status text not null default 'open' check (status in ('open','actioned','dismissed')),
  actioned_by text,                            -- admin identifier
  actioned_at timestamptz,
  created_at timestamptz not null default now()
);
create index on reports (status, created_at);  -- SLA queue ordering

create table blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table moderation_audit (
  id uuid primary key default gen_random_uuid(),
  admin_id text not null,
  action text not null,                        -- 'warn' | 'suspend_7d' | 'ban' | 'remove_content' | ...
  target_profile_id uuid,
  target_id uuid,
  reason text,
  created_at timestamptz not null default now()
);

-- ═══════════════ NOTIFICATIONS ═══════════════

create table devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  apns_token text not null unique,
  environment text not null default 'prod',
  created_at timestamptz not null default now()
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  kind text not null,                          -- 'match_request','hike_approved','message','safety_checkin',...
  payload jsonb not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
```

### 8.1 Row-Level Security (RLS) — core policies (all tables have RLS enabled)

```sql
-- Pattern examples; implement equivalents on every table.

-- Only verified, active women can read other profiles (and never soft-deleted ones).
create policy read_profiles on profiles for select using (
  auth.uid() = id                                -- always read self
  or (
    exists (select 1 from profiles me
            where me.id = auth.uid()
              and me.verification_status = 'verified'
              and me.account_status = 'active')
    and verification_status = 'verified'
    and account_status in ('active','warned')
    and deleted_at is null
    and not exists (select 1 from blocks b
                    where (b.blocker_id = auth.uid() and b.blocked_id = profiles.id)
                       or (b.blocker_id = profiles.id and b.blocked_id = auth.uid()))
  )
);

-- Messages: only thread participants may read/insert.
create policy thread_participants on messages for all using (
  exists (
    select 1 from threads t
    left join connections c on c.id = t.connection_id
    left join hike_members hm on hm.hike_id = t.hike_id
      and hm.profile_id = auth.uid() and hm.status = 'approved'
    where t.id = messages.thread_id
      and ( (t.kind='dm' and auth.uid() in (c.profile_a, c.profile_b))
         or (t.kind='hike' and hm.id is not null) )
  )
);
```
Also: `trips` readable only by verified users; `safety_plans` readable only by owner (public status page is served by an edge function using the token, not RLS); `reports` insert-only for users, readable only by service role; sensitive `profiles` columns (`date_of_birth`, `phone_hash`, verification fields) are excluded via a `public_profiles` view — the client NEVER selects from `profiles` directly for other users.

### 8.2 Edge Functions (Deno/TypeScript)

| Function | Trigger | Responsibility |
|---|---|---|
| `create-verification-session` | client | Create Stripe Identity session (liveness + doc); return client secret |
| `stripe-identity-webhook` | Stripe | Verify signature; update `verification_status`; route ambiguity → `needs_review` |
| `moderate-media` | Storage upload hook | Call Sightengine/Hive; set moderation status; queue rejects |
| `moderate-text` | DB webhook on `messages` insert | Toxicity screen; flag to queue (don't hard-block borderline) |
| `send-safety-sms` | internal | Twilio SMS to trusted contacts (plan share, escalation) |
| `safety-escalation-cron` | pg_cron every 5 min | Find `safety_plans` past `expected_return_at` + 30 min grace, still `active` → escalate + SMS |
| `trip-nudges-cron` | pg_cron daily | T-14/T-5/T-2 pushes with live overlap counts |
| `push` | internal | APNs JWT send; fan-out for hike/thread events |
| `share-page` | public HTTPS (token) | Render tokenized safety-plan status page (also mirrors to R2/Worker) |
| `delete-account` | client | Full deletion flow per PRD §5 |
| `redact-verification-cron` | pg_cron daily (P1) | Call Stripe redaction API for sessions decided >30 days ago |

### 8.3 Realtime
Supabase Realtime channels per thread (`thread:{id}`) for messages + typing; per hike (`hike:{id}`) for membership/status changes; per user (`user:{id}`) for notification badge counts. Live location during hikes publishes to `hike:{id}:loc` (approved members only; ephemeral, also written to `safety_plans.last_known_location` every 5 min for escalation use).

---

## 9. iOS App Structure

```
TrailSisters/
├── App/                    // entry, DI container, deep links, push registration
├── Core/
│   ├── Networking/         // Supabase client wrapper, retry, offline queue
│   ├── Auth/               // Sign in with Apple, OTP, session
│   ├── Location/           // permission flows, significant-change, hike tracking
│   ├── Persistence/        // SwiftData cache: trails, parks, viewed profiles, drafts
│   └── DesignSystem/       // colors, type, components (Badge, Card, EmptyState)
├── Features/
│   ├── Onboarding/         // carousel, auth, OTP, verification (Stripe sheet), wizard
│   ├── Home/               // feed: overlaps, requests, upcoming hikes
│   ├── Explore/            // parks map/list, trail pages, weather/AQI, conditions
│   ├── Trips/              // create/edit, overlap list, match requests
│   ├── Hikes/              // create, detail, membership, day-of mode
│   ├── Chat/               // threads, messages, media
│   ├── Safety/             // trusted contacts, plan share, check-in timer, live share, safety cards
│   ├── ProfileSelf/        // edit profile, photos, settings, deletion
│   ├── ProfileOther/       // public profile view, report/block
│   └── Notifications/      // inbox, settings
├── Maps/                   // MapLibre wrapper, PMTiles source, trail overlay, downloads (P1)
└── Tests/                  // unit + snapshot + RLS integration tests (see §12)
```

Key implementation notes for the AI agent:
- Use `async/await` throughout; no Combine unless required by a dependency.
- All server mutations go through typed repository protocols (testability + future API swap).
- Feature-flag system (simple remote JSON in Supabase table `feature_flags`) gates P1/P2 features and the verification kill-switch.
- Background modes: `location` (only during active hike with explicit user start), `remote-notification`.
- Never request Contacts permission; trusted contacts are typed in manually (privacy stance).

---

## 10. Trail Data Import Pipeline (one-time + quarterly refresh; runs locally as scripts)

1. **US:** Query `NPS_Public_Trails` ArcGIS FeatureServer (GeoJSON, paginated 2,000/records) filtered to national park unit codes; keep `OPENTOPUBLIC='Yes'`, hiking-compatible `TRLUSE`. Public domain — include courtesy attribution "Data: National Park Service".
2. **Canada:** Download Parks Canada "Trails APCA" GeoJSON (Open Government Licence – Canada; attribute accordingly).
3. **Enrich:** snap trailheads (first vertex or curated override CSV); sample geometry against USGS 3DEP (US) / NRCan CDEM (CA) DEM tiles to compute `elevation_gain_m` + downsampled `elevation_profile`; compute `length_km` (PostGIS `ST_Length` geography); difficulty formula: `score = length_km + (elevation_gain_m / 100)` → easy <8, moderate 8–16, hard 16–24, very_hard >24 (tune later); `est_duration_min` via Naismith's rule (12 min/km + 10 min per 100 m gain).
4. **Curate flagship parks** (launch 5: Zion, Yosemite, Glacier, Grand Canyon, Banff): manual QA of trail names/dedup, trailhead notes, permit flags, emergency numbers, hospital info.
5. **Load** into `parks`/`trails`; export per-park GeoJSON bundles to R2 for client caching.
6. **Map tiles:** build PMTiles extracts (Protomaps `pmtiles extract` against park bounding boxes, zooms 8–14) → upload to Cloudflare R2 behind a Worker with CORS + cache headers.
7. **OSM gap-fill (only if a flagship trail is missing):** Overpass extract, stored with `source='osm'` and ODbL attribution string; keep OSM-derived rows clearly separated.

---

## 11. App Store Compliance Checklist (submit-blockers)

- [ ] 17+ age rating; UGC questionnaire answered; 18+ in-app age gate
- [ ] Guideline 1.2: report (all content types) ✓, block ✓, content filtering (auto media/text) ✓, published support contact ✓, EULA with objectionable-content zero tolerance ✓, ≤24 h moderation SLA process documented in review notes
- [ ] Sign in with Apple offered alongside any other login
- [ ] In-app account deletion
- [ ] Privacy nutrition labels: location (incl. background w/ justification: user-initiated safety sharing), photos, phone, user content; privacy policy URL
- [ ] Background location: purpose string explains hike safety sharing; only active during user-started hike
- [ ] Demo account credentials + a pre-verified test account + review notes explaining women-only verification (App Review testers may be male — provide a review bypass flag account, documented)
- [ ] No mention of "dating" anywhere in metadata
- [ ] Data collection consistent with Stripe Identity disclosure requirements

## 12. Testing Requirements (AI agent must generate these)

- **RLS integration tests (critical):** unverified user cannot read any profile/trip/hike/message; non-participant cannot read thread; blocked pairs invisible; banned user loses all reads. Run against a local Supabase instance in CI.
- Unit tests: difficulty formula, Naismith duration, age-range rendering, overlap query correctness (property-based date ranges), check-in escalation state machine.
- Snapshot tests: trail page, profile, hike card (light/dark/dynamic-type XL).
- E2E happy path (XCUITest): signup → (stubbed) verification → create trip → match → create hike → approve member → chat → start hike → check-in → complete.
- Load sanity: overlap query <200 ms @ 5k trips/park; message send→receive p95 <1 s.
- Airplane-mode suite: cached trail page, offline safety card, deferred check-in escalation on reconnect.

## 13. Analytics Events (privacy-safe; no PII in payloads)

`signup_started/completed`, `verification_started/passed/failed/needs_review`, `profile_completed_pct`, `trip_created`, `overlap_viewed`, `match_request_sent/accepted`, `hike_created/join_requested/approved/confirmed/completed/cancelled`, `message_sent`, `safety_plan_shared`, `checkin_set/confirmed/escalated`, `live_share_started`, `offline_pack_downloaded`, `report_submitted`, `block_created`, `account_deleted`. Dashboards: activation funnel, trip→match rate per park, safety adoption, report SLA.

## 14. Build Phases (execute in order)

**Phase 0 — Foundations (build first):** Supabase project + schema + RLS + CI RLS tests · auth (Apple/email + OTP) · design system · trail import pipeline run for 5 flagship parks · MapLibre + R2 PMTiles rendering.

**Phase 1 — P0 product:** onboarding + Stripe Identity verification + admin `needs_review` queue · profiles + photo moderation pipeline · Explore (parks/trails/weather/AQI/sun) · Trips + overlap matching + requests + connections · Hikes + membership · Chat (Realtime) + text/media moderation · Safety suite (contacts, plan share, check-in cron, live share, offline safety card) · notifications · reporting/blocking + admin dashboard (simple internal web app: Next.js or Retool) · account deletion · App Store checklist.

**Phase 2 — P1:** offline park downloads · GPX recording + stats · trail conditions · NWS/EC alerts · verification redaction cron · data export.

**Phase 3 — designed, not built:** community chapters · badges · invited male guest (`role='male_guest'` path) · monetization scaffolding.

## 15. Key Risks & Mitigations (engineering-relevant)

| Risk | Mitigation in this spec |
|---|---|
| Verification data breach (Tea-app scenario) | Zero raw-ID storage (§6, §8 AC); Stripe redaction cron; grep-audit in CI for forbidden column names |
| Verification bypass (AI-generated selfies) | Liveness capture requirement; re-verification on report; phone uniqueness; human `needs_review` queue |
| App Review rejection (women-only) | Review-bypass demo account + notes; frame as "verified community" per 1.2, not discrimination; legal ToS ready |
| Check-in false alarms | 30-min grace + explicit "depends on cell coverage" copy + one-tap "I'm safe" from lock screen (time-sensitive push) |
| Supabase Realtime scale for chat | Per-thread channels; message pagination; fallback to polling flag |
| Empty-marketplace feel | Flagship-park focus; empty states drive trip creation; ambassador-seeded hikes before public launch |

## 16. Instructions to the AI Coding Agent

1. Build in the phase order of §14; do not skip RLS tests.
2. Every table gets RLS enabled before any client code touches it.
3. All user-visible copy must avoid dating-app language; use "trail sisters", "hiking partners", "group hikes".
4. Comment code clearly and concisely so an amateur developer can follow it.
5. When a product decision is ambiguous, choose the option that maximizes user safety, then privacy, then growth — in that order.
6. Flag (don't silently implement) anything requiring paid-tier services beyond those budgeted in §7.

# END OF DOCUMENT
