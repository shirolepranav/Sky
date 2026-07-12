---
name: ts-backend
description: Supabase backend work for TrailSisters — schema migrations, Row-Level Security policies, Postgres functions/triggers, Edge Functions (Deno/TypeScript), pg_cron jobs, Realtime channels, Storage hooks. Use for any change to the data model, verification webhook, moderation pipeline, safety escalation cron, push fan-out, or matching queries.
---

# Working on the TrailSisters backend

The backend is Supabase: Postgres + PostGIS with RLS as the security boundary,
Edge Functions for webhooks/SMS/push/jobs, pg_cron for schedules. The schema
of record is PRD §8; edge-function inventory is PRD §8.2.

## Non-negotiables (check on every change)

1. **RLS before client code.** A new table ships in the same migration as its
   RLS enablement + policies, and the RLS test suite gains cases in the same
   change. Deny-by-default; service role only inside edge functions.
2. **No raw ID data, ever.** The only verification fields are
   `stripe_verification_session_id`, `verification_status`, `verified_at`,
   `verification_failure_code`. Never add columns, logs, or buckets that could
   hold ID images/numbers/biometrics — CI grep-audit (forbidden identifiers)
   must stay green; extend it if you touch verification.
3. **Sensitive columns never reach other clients.** Cross-user reads go
   through `public_profiles` (no DOB, `phone_hash`, verification internals).
   New profile columns default to EXCLUDED from the view until explicitly
   decided.
4. **Server-authoritative validation.** Dates, membership counts, statuses:
   validate in SQL/edge functions even when the client also checks.
5. **Safety paths are server-side.** Escalation fires from
   `safety-escalation-cron` regardless of client state; enforcement (suspend/
   ban) must never cancel an in-flight `safety_plans` row. All safety SMS
   templates include the coverage caveat + "Reply STOP to opt out."

## How to work

- **Migrations:** append-only files in `supabase/migrations/`; must survive
  `supabase db reset` twice. Index every FK; keep `trips_overlap_idx`-class
  partial indexes for hot queries (overlap RPC must stay <200 ms @ 5k
  trips/park — there's a load test).
- **RLS tests:** run against local Supabase (`supabase start`) in CI. The
  canonical matrix (PRD §12.1): unverified reads nothing; non-participant
  can't read or write a thread; blocked pairs mutually invisible; banned loses
  all reads; removed hike member loses access instantly. Extend, never trim.
- **Edge functions** (Deno/TS, one folder each): verify webhook signatures
  (Stripe), auth-gate client-callable functions, keep them idempotent
  (create-verification-session, membership transactions), and write Deno tests
  with fixture payloads. Secrets via Supabase secrets — never in the repo.
- **Webhook → status mapping:** verification ambiguity routes to
  `needs_review`, never auto-reject on a gender marker (PRD §6.4) — this is a
  policy invariant, treat regressions as P0 bugs.
- **Crons** (pg_cron): safety escalation (5 min), trip nudges + archive
  (daily), redaction (P1, daily; only sessions decided >30 days). Every cron
  is idempotent and safe to double-fire.
- **Realtime:** per-thread `thread:{id}`, per-hike `hike:{id}` (+ `:loc` for
  approved members only), per-user `user:{id}`. Authorize channels — location
  data especially.
- **Transactions:** connection+thread creation, membership approval racing
  the last spot, account deletion — wrap in functions/RPCs; there are
  concurrency tests, keep them passing.

## Definition of done

- Migration + policies + RLS tests + (if applicable) Deno tests in one change.
- `supabase db reset` clean; local RLS suite green; grep-audit green.
- PRD §8/§8.2 or this repo's docs updated if the contract changed.
- Note anything that adds paid-service cost (PRD §16.6) instead of silently
  shipping it.
