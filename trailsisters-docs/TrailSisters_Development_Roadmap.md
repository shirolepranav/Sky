# TrailSisters — Development Roadmap

16 phases (0–15), ordered by dependency, expanding PRD §14's four coarse phases into AI-session-sized chunks. Each phase has:
- **Code Development** — what to build
- **Automated Tests** — tests an AI assistant can write and run (XCTest / XCUITest / SQL-based RLS tests / Deno tests)
- **Manual Tests** — checks needing a physical device, real services, or human judgment
- **Regression Tests** — re-tests only for earlier-phase features this phase could plausibly break

Rules (from PRD §16):
1. **Do not start Phase N+1 until all four sections of Phase N are green.**
2. **Every table gets RLS enabled — and an RLS test — before any client code touches it.**
3. When feeding a phase to an AI session, include: this phase's section + `CLAUDE.md` + the screens listed for the phase in `TrailSisters_App_Workflow.md` §3.6 + the PRD sections cited.
4. Flag (don't silently implement) anything requiring paid services beyond PRD §7's budget.

P0 = Phases 0–14 (launch). P1 = Phase 15.

---

## Phase 0 — Foundations: Project, Schema, RLS, CI

*(PRD §7, §8, §12, §16)*

### Code Development
- Create Xcode project `TrailSisters`: iOS 17.0 minimum, SwiftUI lifecycle, Swift 5.10+, MVVM + Swift Concurrency (no Combine — PRD §9).
- Folder structure exactly per PRD §9 (`App/`, `Core/{Networking,Auth,Location,Persistence,DesignSystem}/`, `Features/…`, `Maps/`, `Tests/`).
- Add SPM dependencies: `supabase-swift`, `StripeIdentity`, `MapLibre Native`; pin versions.
- Capabilities: Sign in with Apple, Push Notifications, Background Modes (`location`, `remote-notification`). URL scheme `trailsisters://` + associated domains placeholder.
- Create Supabase project (Pro). Apply the **entire** PRD §8 schema as migration files (`supabase/migrations/`), including extensions (`postgis`, `pg_cron`), triggers for `updated_at` + `profiles.completeness`, and the `trips_overlap_idx`. Add `profiles.accepted_tos_version` (workflow `S-LEGAL-01`) and a `feature_flags` table (PRD §9) seeded with `verification_kill_switch=false`.
- **Enable RLS on every table** with deny-by-default; implement PRD §8.1 policies incl. `public_profiles` view (sensitive columns excluded).
- CI (GitHub Actions): iOS build + unit tests; **local Supabase (`supabase start`) RLS test suite**; and a **grep-audit step failing the build if any migration/source contains forbidden identifiers** (`id_image`, `document_number`, `id_number`, `face_template`, `biometric`, `selfie_url` — Tea-app guard, PRD §15).
- `Core/Networking`: Supabase client wrapper, typed repository protocols, retry + offline queue skeleton.
- `.gitignore`, README stub, `AppConfig.swift` (environment/base URLs; no secrets in repo).

### Automated Tests
- RLS suite (SQL or Deno, run against local Supabase): unverified user selects 0 rows from `public_profiles`, `trips`, `hikes`, `messages`; anonymous role reads only `parks`/`trails`; participant-only policy on `messages` (deny non-participant read AND insert); blocked-pair invisibility on `public_profiles`; banned user loses all reads (PRD §12.1).
- Migration idempotency: `supabase db reset` twice, clean both times.
- Grep-audit test passes on the pristine repo and fails on a planted fixture.
- Build succeeds Debug + Release.

### Manual Tests
- Supabase dashboard: all tables show RLS ON; pg_cron + postgis listed under extensions.
- Xcode: capabilities show without signing errors on a device profile.

### Regression Tests
- None (first phase).

---

## Phase 1 — Design System

*(DESIGN_SYSTEM.md is the source of truth; PRD §4)*

### Code Development
- `Core/DesignSystem/`: `TSColor` (all tokens, light+dark), `TSTextStyle` + `.tsText(_:)` modifier (Dynamic Type–relative), `TSSpacing`, `TSRadius`.
- Components: `TSPrimaryButton`, `TSSecondaryButton`, `TSDestructiveButton`, `TSCard`, `TSListRow`, `TSChip`/`TSChipGroup`, `TSSegment`, `TSTextField`/`TSTextEditor` (counted), `TSToggleRow`, `TSCheckboxRow`, `TSStepper`, `TSAvatar` + `VerifiedBadge`, `TSBadge`, `TSStatusPill`, `TSDifficultyPill`, `TSStatTile`, `TSProgressRing`, `TSEmptyState`, `TSBanner`, `TSToast`, `TSSearchField`, `TSOTPField`, `TSRangeSlider`, `TSCalendarRange`, `TSPhotoGrid` shell.
- Every component: `#Preview` light + dark + Dynamic Type XL; VoiceOver labels; 44×44 minimum targets.
- Hidden `DesignSystemPreviewScreen` behind a debug flag for visual QA.

### Automated Tests
- `TSColorTests.testHexParsing` — token hex → expected RGB.
- Contrast tests: every (fill, label) pair declared in DESIGN_SYSTEM.md §2 clears WCAG AA 4.5:1 (computed, not eyeballed).
- Snapshot tests (light/dark/XL type): buttons, card, avatar+badge, empty state, difficulty pill.

### Manual Tests
- Preview screen on device in light/dark; Dynamic Type at largest accessibility size; Reduce Motion honored by ring/toast animations.

### Regression Tests
- Phase 0 CI still green (RLS suite unaffected).

---

## Phase 2 — Trail Data Import Pipeline (5 flagship parks)

*(PRD §10; runs locally as scripts, committed under `tools/import/`)*

### Code Development
- Scripts (TypeScript/Deno or Python — pick one, document): NPS `NPS_Public_Trails` ArcGIS fetch (paginated, `OPENTOPUBLIC='Yes'`, hiking `TRLUSE`, filtered to flagship unit codes); Parks Canada Trails APCA GeoJSON fetch (Banff).
- Enrichment: trailhead snap (first vertex + curated override CSV), DEM sampling (USGS 3DEP / NRCan CDEM) → `elevation_gain_m` + downsampled `elevation_profile` (~200 pts), `length_km` via PostGIS geography, difficulty formula `score = length_km + gain_m/100` (easy <8 / moderate 8–16 / hard 16–24 / very_hard >24), Naismith `est_duration_min` (12 min/km + 10 min/100 m gain).
- Curated CSVs for the 5 flagship parks: emergency phone, nearest hospital, trailhead notes, permit flags, `is_flagship=true`.
- Loader → `parks`/`trails`; export per-park GeoJSON bundles for client caching; attribution strings written per source.
- OSM Overpass gap-fill script (used only if a flagship trail is missing; `source='osm'`, ODbL attribution).

### Automated Tests
- Unit: difficulty formula boundary cases (7.99/8/16/24/24.01); Naismith known inputs; elevation-profile downsampler point count + monotonic distance (PRD §12.2).
- Import integration (fixtures, no network): sample ArcGIS/APCA payloads → expected rows; geometry validity (`ST_IsValid`); every loaded trail has non-null geometry, length, attribution.
- Idempotent re-run produces no duplicates (`unique (source, source_code)` respected).

### Manual Tests
- Spot-check 3 well-known trails per flagship park against official park pages (name, length ±10%, trailhead location on a map).
- Confirm the 5 parks' curated emergency/hospital fields against official sources.

### Regression Tests
- Phase 0 RLS suite (new content tables readable by anon — intended).

---

## Phase 3 — Maps: MapLibre + PMTiles on R2

*(PRD §3.12 P0 scope, §7, §10.6)*

### Code Development
- Build PMTiles extracts for the 5 flagship-park bounding boxes (zooms 8–14) with Protomaps `pmtiles extract`; upload to Cloudflare R2 behind a Worker with CORS + cache headers.
- `Maps/`: `TSMap` (MapLibre wrapper) — PMTiles remote source, park boundary layer, trail `MultiLineString` overlay, trailhead pin, marker clustering, style tuned per DESIGN_SYSTEM.md (outdoor palette, light+dark styles).
- Client GeoJSON caching for trail geometry (from Phase 2 bundles).
- Offline-download scaffold only: protocols + local-pack registry types (implementation Phase 15).

### Automated Tests
- Unit: bounding-box → tile-URL resolution; GeoJSON decode of park bundles; style JSON validates.
- Snapshot: `TSMap` rendering a fixture trail polyline + trailhead pin (both themes).

### Manual Tests
- On device: pan/zoom each flagship park; trail overlays align with basemap paths at z12–14; R2 latency acceptable on LTE; dark style legible outdoors.

### Regression Tests
- Phase 1 snapshots unaffected.

---

## Phase 4 — Auth, Legal, Age Gate, Guest Shell

*(PRD §3.1; workflow S-ONB-01…04, S-AUTH-01…04, S-LEGAL-01, S-AGE-01)*

### Code Development
- `Core/Auth`: Sign in with Apple → Supabase `signInWithIdToken`; email/password; session persistence + refresh; sign-out.
- Phone OTP via Supabase Auth phone provider (Twilio); `phone_hash` uniqueness enforcement server-side (edge function or DB trigger on confirmation).
- ToS versioned acceptance (server column + re-prompt logic); DOB write-once + server-side ≥18 validation; under-18 block + delete path.
- `AppRouter` + full cold-launch route table (workflow §0.2); onboarding carousel; guest-preview MainTab shell (Explore live, other tabs gated).
- Analytics events: `signup_started/completed` (PRD §13; TelemetryDeck/PostHog, no PII).

### Automated Tests
- Route-table unit tests: one test per row 1–14 (fixture states → expected route).
- DOB: 18th-birthday boundary (17y364d rejected, 18y0d accepted, server-side test).
- `phone_hash` uniqueness: second account with same number rejected (integration).
- ToS re-prompt: bumping version fixture re-routes to `S-LEGAL-01`.
- XCUITest: carousel → Apple-auth stub → legal → DOB → phone (stubbed OTP) reaches `S-VER-01`.

### Manual Tests
- Real Sign in with Apple on device (fresh Apple ID + revoked-credential case).
- Real SMS OTP to a US + a CA number; resend cooldown; wrong-code shake.

### Regression Tests
- Phase 0 RLS: unverified (now real) session still reads zero user content.

---

## Phase 5 — Identity Verification (Stripe Identity)

*(PRD §6, §3.2; workflow S-VER-01…05, S-EXP-05)*

### Code Development
- Edge function `create-verification-session`: auth-gated, idempotent per user, creates VerificationSession `type: document`, `require_matching_selfie: true`, `require_live_capture: true`; honors `verification_kill_switch` feature flag (queue mode → friendly message).
- Edge function `stripe-identity-webhook`: signature verification; maps events → `verification_status`; ambiguity/mismatch → `needs_review` (never auto-reject on gender marker — PRD §6.4); stores ONLY `stripe_verification_session_id`, `status`, `verified_at`, `verification_failure_code`.
- iOS: `S-VER-01…05` screens, StripeIdentity sheet integration, Realtime subscription on own status, retry with 3-attempt cap, guest-preview entry + `S-EXP-05` gate sheet.
- Analytics: `verification_started/passed/failed/needs_review`.

### Automated Tests
- Webhook unit tests (Deno): valid signature accepted / invalid rejected; each Stripe event fixture → expected status; ambiguous fixture → `needs_review`.
- **Grep-audit re-run is part of this phase's DoD** — verification code stores only the four allowed fields (PRD §3.2 AC).
- Idempotency: two create-session calls → one open session.
- RLS: user can read own verification_status; nobody else's (not even `verified_at` via `public_profiles`).
- Kill-switch flag flips create-session into queue mode (integration).

### Manual Tests
- Full happy path on device with Stripe test documents (verified in <3 min).
- Force each failure bucket with Stripe test cases; check copy per bucket.
- Confirm in Stripe dashboard: retention set to minimum (PRD §6.5).

### Regression Tests
- Phase 4 route table rows 6–9 with real statuses; guest shell unaffected.

---

## Phase 6 — Profiles & Photo Moderation

*(PRD §3.3; workflow S-PROF-01…06, S-ME-01…02, S-USER-01 view-only)*

### Code Development
- Profile wizard (6 steps), resumable; edit profile; own profile root; other-profile view (view-only — action bar arrives Phases 8–9).
- On-device Vision face check for primary photo; client downscale (2048 px); Supabase Storage upload; offline upload queue.
- Edge function `moderate-media` (Storage hook → Sightengine/Hive → `moderation_status`); Realtime status updates to the grid.
- Completeness trigger (server) + meter UI + ≥80% ranking flag.
- `public_profiles` view finalized: age-range computed column; sensitive fields (DOB, phone_hash, verification internals, last name — not collected beyond first name) excluded (PRD §3.3 AC).
- Analytics: `profile_completed_pct`.

### Automated Tests
- Age-range rendering: DOB fixtures → "20s"/"30s"/boundary at decade edges (PRD §12.2).
- Completeness computation: field-set fixtures → expected %.
- RLS/view: `public_profiles` for another user contains NO `date_of_birth`, `phone_hash`, `stripe_verification_session_id` columns (schema introspection test); unverified viewer gets zero rows.
- Moderation pipeline integration (mock Sightengine): pending → approved/rejected transitions; rejected photo never readable by others (RLS on `profile_photos.moderation_status`).
- Snapshot: profile page light/dark/XL (PRD §12.3).
- Face-check unit: fixture with face passes, landscape photo fails.

### Manual Tests
- Real photo uploads incl. borderline images; moderation round-trip p95 < 10 s.
- Wizard resume: kill app at each step, relaunch resumes correctly.

### Regression Tests
- Phase 5 verification → wizard handoff; Phase 4 route rows 12.

---

## Phase 7 — Explore: Parks, Trails, Weather/AQI/Sun

*(PRD §3.4, §3.9; workflow S-EXP-01…04)*

### Code Development
- Explore root (list/map/search), park page (alerts via NPS API server-cached, description, trails + filters), trail page (all sections; conditions section stubbed until P1), filters sheet.
- Weather: Open-Meteo per trailhead, server-side 30-min cache (edge function or supabase table cache); AQI: AirNow (US) / AQICN (CA) with >100 banner; sunrise/sunset/golden hour computed on-device (solar math, no API).
- SwiftData caching: parks, trails, viewed trail pages incl. last weather payload; offline stale labels; graceful degradation (page never blocks on weather — PRD §3.9 AC).
- `ElevationProfileChart` with scrub + `accessibilityChartDescriptor`.

### Automated Tests
- Solar math unit: known lat/long/date → sunrise/sunset within ±2 min of reference values (include DST + polar-ish edge: Glacier in June).
- Weather/AQI decoding fixtures; failure → cached/stale path renders (no throw to UI).
- Difficulty pill mapping; unit conversion mi/km by locale.
- Cache test: trail page renders fully from SwiftData with network layer stubbed to fail (PRD §3.4 AC).
- Snapshot: trail page (light/dark/XL) with fixture data.

### Manual Tests
- Airplane mode: previously viewed trail page fully renders; unvisited page shows friendly offline state.
- Cross-check weather + AQI banner against official sources for one park each side of the border.

### Regression Tests
- Phase 3 map overlays inside trail/park pages; Phase 2 data renders for all 5 parks.

---

## Phase 8 — Trips, Overlap Matching, Requests & Connections

*(PRD §3.5; workflow S-HOME-01/02 trip sections, S-PLAN-01, S-TRIP-01…04)*

### Code Development
- Create/edit/cancel trip; my trips; trip detail with ranked overlaps (SQL: date-overlap length desc, then pace+experience proximity — server-side RPC); visibility `similar_experience` filtering both directions.
- Say-hi compose; requests inbox (received/sent); accept → transactional edge function or RPC: `connections` insert (canonical ordering) + `dm` thread creation.
- Trip auto-archive cron; `trip-nudges-cron` (T-14/5/2d with live overlap counts) — pushes stubbed until Phase 12, rows written to `notifications`.
- Home feed v1 (attention, trips, overlaps sections + empty states).
- Analytics: `trip_created`, `overlap_viewed`, `match_request_sent/accepted`.

### Automated Tests
- **Overlap correctness, property-based:** random date-range pairs → overlap iff `start_a ≤ end_b AND start_b ≤ end_a`; ranking order verified (PRD §12.2).
- **Load sanity: seed 5,000 active trips at one park → overlap RPC < 200 ms** (PRD §3.5 AC, §12.5; run in CI against local Supabase, generous threshold ×2 for CI hardware, verify real target manually).
- RLS: trips invisible to unverified; `similar_experience` trip invisible to out-of-range member (both directions); blocked pair excluded from overlaps.
- Unique constraint: second say-hi to same trip rejected with friendly error.
- Accept transaction: connections + thread created atomically; decline creates neither.
- XCUITest: create trip → see seeded overlap → say hi → (second session) accept → thread exists.

### Manual Tests
- Two real devices/accounts: full J-03 journey; nudge row appears when trip date fixture is T-5d.

### Regression Tests
- Phase 6 `public_profiles` exposure via overlap cards (no sensitive fields in payload); Phase 4 guest cannot reach any trip API.

---

## Phase 9 — Group Hikes & Membership

*(PRD §3.6; workflow S-HIKE-01…04, invite variant of S-TRIP-04)*

### Code Development
- Create/edit/cancel hike (draft→open, tz-aware validation); hike detail public/member/host variants; join request + approve/decline/remove; auto open⇄full; confirm; invite-from-trip (pre-approved request); no-show flags post-completion (3 flags → warning, server).
- Realtime `hike:{id}` membership/status channel.
- Home feed + Plan hub hike sections.
- Analytics: `hike_created/join_requested/approved/confirmed/cancelled`.

### Automated Tests
- Server validation: past date in park tz rejected (fixture parks in 3 tz); `max_members` 2–8 bounds.
- **Membership transactionality:** concurrent approvals racing the last spot → exactly one succeeds, hike flips `full` (PRD §3.6 AC).
- RLS: removed member immediately loses hike + thread reads (PRD AC); invite-only hike invisible to non-invitees.
- State machine unit tests: every legal/illegal `hikes.status` + `hike_members.status` transition.
- No-show: 3 flags fixture → account_status `warned`.

### Manual Tests
- Two devices: J-04 end-to-end; edit hike → member gets change notification row; remove member → her UI degrades live.

### Regression Tests
- Phase 8 requests inbox now mixed (trip + hike rows); Home feed sections coexist.

---

## Phase 10 — Chat (Realtime) & Content Moderation

*(PRD §3.7; workflow S-CHAT-01…02)*

### Code Development
- Threads list + thread UI (DM + group), pagination (50/page), optimistic send, offline outbox, typing indicator, per-thread mute.
- Photo messages: upload → `moderate-media` → hidden-until-approved shimmer (<10 s p95).
- Edge function `moderate-text` (DB webhook on message insert): toxicity screen → `toxicity_flagged` → moderation queue (borderline never hard-blocked); client-side profanity hint pre-send.
- Blocking hooks: thread visibility respects `blocks` (delivered fully in Phase 13; table + RLS exist since Phase 0).
- Cancelled-hike thread: 7-day read-only window.
- Analytics: `message_sent`.

### Automated Tests
- **RLS (critical, PRD §12.1):** non-participant cannot select OR insert into a thread; removed hike member loses both; DM requires connection row.
- Media message invisible to recipient while `pending`, visible on `approved`, never on `rejected`.
- Toxicity webhook fixture → flagged row lands in queue; message still delivered.
- Pagination: 120-message fixture → 3 pages, stable ordering.
- Load sanity: send→receive p95 < 1 s on local stack (PRD §12.5).
- XCUITest: accept match → send text + photo → second account receives.

### Manual Tests
- Two devices on LTE: latency feel, typing indicator, mute, offline outbox flush on reconnect.

### Regression Tests
- Phase 8 accept-creates-thread; Phase 9 approve-adds-to-group-chat & remove-revokes.

---

## Phase 11 — Safety Suite

*(PRD §3.8 — the differentiator; workflow S-HIKE-05…06, S-SAFE-01…06, W-SHARE-01)*

### Code Development
- Trusted contacts CRUD (manual entry only — never request Contacts permission, PRD §5/§9).
- Share-my-plan: `safety_plans` + `share_token`; `send-safety-sms` edge function (Twilio, opt-out language); share-sheet path.
- `share-page` edge function/Worker → `W-SHARE-01` (tokenized, expiring, revocable; 60 s auto-refresh; zero-leak expired page).
- Check-in timer: default est×1.3; time-sensitive push with lock-screen "I'm safe" action; **`safety-escalation-cron` (pg_cron, 5-min scan): `active` plans past `expected_return_at`+30 min → `escalated` + SMS with last-known location** (server-side — PRD AC); all-clear SMS; offline-confirm reconciliation.
- Live share: significant-change location; `hike:{id}:loc` channel (approved members only); `last_known_location` write every 5 min; 24 h hard stop; revoke.
- Active-hike mode (`S-HIKE-05`), complete flow (`S-HIKE-06` minus P1 conditions), offline safety card (`S-SAFE-06`, cached render + save-to-Photos), Safety Center + bundled articles.
- Background mode `location` only during user-started hike (purpose strings per PRD §11).
- Analytics: `safety_plan_shared`, `checkin_set/confirmed/escalated`, `live_share_started`.

### Automated Tests
- **Check-in escalation state machine (PRD §12.2):** every transition incl. grace boundary (T+29:59 no-op, T+30:01 escalates), offline-confirm-then-reconnect (escalated → all-clear), 24 h expiry, cancel.
- Cron integration (local Supabase): seeded overdue plan → status `escalated` + SMS job row; checked-in plan untouched.
- Token page: valid token renders plan; expired/revoked/garbage token → uniform expired page (no data leak); last-known-location section absent when contact live-share off.
- SMS templates contain coverage caveat + STOP language (string assertions).
- RLS: `safety_plans` readable by owner only; location channel restricted to approved members.
- **Airplane-mode suite (PRD §12.6):** simulated offline check-in confirm defers and reconciles on reconnect.

### Manual Tests
- Full J-05 + J-06 on real devices with real SMS to a test contact: prompt at T+0, escalation SMS ~T+30 with working map link, all-clear on "I'm safe"; lock-screen action works.
- Battery: 4-hour live-share hike (or simulated route) — acceptable drain; background updates continue with screen off ("Always" granted).
- `W-SHARE-01` opened on a non-app phone: readable, refreshes, expires.

### Regression Tests
- Phase 9 hike states (in_progress/completed) driven by start/complete; Phase 10 group chat reachable from active mode.

---

## Phase 12 — Push Notifications & Inbox

*(PRD §3.11; workflow S-NOTIF-01, S-ME-04)*

### Code Development
- `push` edge function: APNs JWT (p8) direct send; device token registry (`devices`); fan-out for all Phase 8–11 events (retro-wire the stubs); time-sensitive **only** for `safety_checkin`.
- In-app inbox (reads `notifications`), badge counts via Realtime `user:{id}`, mark-read.
- Per-category preference toggles; safety lock while hike active; system-denied banner.
- Deep-link routing for every push kind (workflow §0.3).

### Automated Tests
- Payload builder unit tests: every kind → correct APNs headers (`interruption-level: time-sensitive` only for safety), deep-link target, no PII beyond first names (PRD §13).
- Preference filtering: disabled category → no push row queued; safety kind ignores disable while plan active.
- Inbox RLS: own rows only.
- Route tests: each push kind fixture → expected screen (extends Phase 4 route tests).

### Manual Tests
- Real APNs sandbox on device: one push per kind lands + routes; safety check-in breaks through Focus mode (time-sensitive); per-thread mute silences message pushes.

### Regression Tests
- Phase 11 check-in prompt path now via real push; Phase 8 nudge cron sends real pushes.

---

## Phase 13 — Reporting, Blocking, Enforcement & Admin Dashboard

*(PRD §3.10 — App Store 1.2 hard requirement; workflow S-MOD-01…03, S-ME-03, A-ADM-01…05)*

### Code Development
- Report sheet on every content type (profile, message, photo, hike, trip); confirmation + follow-up notification; <5 s to queue.
- Block: insert + RLS-driven bidirectional invisibility (profiles, trips, hikes, overlaps, threads); connection removal; blocked-list management in Settings.
- Suspension/ban: enforcement columns honored across all RLS policies; **banned session kill + content hide ≤60 s** (Realtime status broadcast + server checks); `S-MOD-03` interstitials; in-flight safety plans still complete.
- Admin dashboard (Next.js, service-role API routes, admin allowlist): A-ADM-01…05 incl. SLA timers (>12 h red), enforcement ladder, verification `needs_review` queue (links into Stripe dashboard — no ID data rendered locally), audit log, verification kill-switch toggle.
- Settings root (legal, support contact, sign out).
- Analytics: `report_submitted`, `block_created`.

### Automated Tests
- Report insert-only RLS (user can insert, cannot read others' reports); report→queue latency assertion.
- **Block matrix test:** after block, each surface returns zero rows both directions (profiles, trips overlaps, hikes, threads, messages).
- Ban propagation: flipping `banned` → all reads fail; session-kill broadcast consumed by client stub within 60 s (integration).
- Enforcement ladder unit: warn→suspend→ban transitions; impersonation → direct ban; suspension auto-expiry restores `active`.
- Audit: every admin action fixture writes `moderation_audit`.
- Dashboard API routes reject non-allowlisted identities.

### Manual Tests
- Full J-08 with two accounts + admin; SLA timer displays; reporter receives outcome notification.
- Ban a live device session → locked out within 60 s.

### Regression Tests
- Phases 8–10: blocked pair invisible in overlaps, hikes, chat; Phase 6 profile view of suspended member unavailable.

---

## Phase 14 — Launch Readiness: Deletion, Compliance, E2E

*(PRD §5, §11; workflow S-ME-05)*

### Code Development
- `delete-account` edge function + `S-ME-05` flow: purge profile/media, tombstone messages, remove memberships, cancel+notify hosted hikes, retain minimal audit rows; CCPA/PIPEDA alignment.
- App Store package: privacy nutrition labels (location incl. background justification, photos, phone, user content, identifiers); 17+ rating + UGC questionnaire; background-location purpose strings; support URL + published contact; EULA/zero-tolerance text; **review notes: women-only framing per 1.2, demo pre-verified account + male-tester review-bypass flag account (feature-flagged, documented)**; "dating" absent from all metadata (PRD §11).
- Crash reporting (Sentry) + MetricKit; final accessibility pass (VoiceOver labels on all interactive elements — launch requirement, PRD §4).
- **E2E XCUITest happy path (PRD §12.4):** signup → stubbed verification → create trip → match → create hike → approve → chat → start hike → check-in → complete.

### Automated Tests
- Deletion integration: after deletion — profile/photos gone, messages tombstoned ("deleted member" rendering), hosted hikes cancelled with notification rows, audit stub remains, re-signup with same phone allowed.
- The full E2E suite above, green in CI.
- Review-bypass account: flag skips Stripe but is excluded from discovery/overlaps (test), clearly marked internal.
- Full airplane-mode suite re-run (PRD §12.6).
- Metadata lint: grep App Store metadata files for "dating" → must be absent.

### Manual Tests
- TestFlight build through the entire PRD §11 checklist, checkbox by checkbox.
- Account deletion on device, then attempt every deep link/push targeting deleted content.
- VoiceOver-only session: complete J-01 and J-03 without sight.

### Regression Tests
- Full regression: J-01…J-14 smoke on TestFlight build; all CI suites green.

---

## Phase 15 — P1 Fast-Follow

*(PRD §3.12–3.14, §3.9 P1, §5, §6.5; workflow S-EXP-06…07, S-HIKE-07)*

Ship as independent sub-tracks, each with its own mini regression:

1. **Offline park downloads** (`S-EXP-06`): pack download/resume/remove; ≤60 MB/park; AC — trail page + map + safety card fully functional in airplane mode. Tests: pack integrity, airplane-mode XCUITest.
2. **GPX recording + stats** (`S-HIKE-07`): adaptive sampling; 6 h < 15% battery (manual device test); GPX export validates against schema; lifetime totals.
3. **Trail conditions** (`S-EXP-07`, `S-HIKE-06` step, `S-EXP-03` section): render within 1 min of post; 30-day summary window test; photo moderation path reuse.
4. **NWS + Environment Canada alerts** on trail pages; degrade gracefully (reuse Phase 7 pattern + tests).
5. **`redact-verification-cron`**: Stripe redaction API for sessions decided >30 days (PRD §6.5); test with fixture sessions.
6. **Data export** (JSON via support flow, CCPA): export contains user's own data only; RLS-safe generation.
7. Interactive 10-essentials checklist in Safety Center.

### Regression Tests
- Phase 7 trail page (new sections don't break offline cache); Phase 11 safety card inside offline packs; Phase 5 verification unaffected by redaction cron.

---

## Phase 16+ — Designed, Not Built (do not implement)

Community chapters, badges, invited male guest (`hike_members.role='male_guest'` path), monetization scaffolding (PRD §3.15–3.16, §14 Phase 3). Schema already accommodates; **no male-facing UI ships in v1** (PRD §3.16).
