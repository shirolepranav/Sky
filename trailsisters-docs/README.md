# TrailSisters

Women-first hiking partner app for US & Canadian national parks (iOS 17+,
SwiftUI, Supabase). Verified women post trips ("Zion, Oct 3–7"), match with
women whose dates overlap, form group hikes of 2–8, and hike with a free
built-in safety suite. Working title — see `AppBranding` decisions later.

**This repository currently contains the complete documentation package to
build the app with an AI coding agent.** Code lands in phases per the roadmap.

## Document map

| File | What it is |
|---|---|
| `TrailSisters_PRD_TechSpec.md` | Product requirements + full technical spec: rules, features with acceptance criteria, verification spec, Postgres schema, RLS, edge functions, import pipeline, compliance checklist, test requirements |
| `TrailSisters_App_Workflow.md` | Every screen (60 iOS screens with stable IDs like `S-HIKE-05`, + admin dashboard + public share page), 14 end-to-end journeys, state machines, gating table, copy library, push matrix, phase-to-screen index |
| `TrailSisters_Development_Roadmap.md` | 16 build phases in dependency order — each sized for one AI session, each with code scope + automated/manual/regression tests |
| `DESIGN_SYSTEM.md` | Authoritative visual spec v0.1: color tokens (light+dark, AA-checked), type scale, spacing, component library, motion, accessibility checklist |
| `CLAUDE.md` | Standing instructions for AI agents: invariants, conventions, build/verify commands, gotchas |
| `.claude/skills/` | Claude Code skills: `ts-screen`, `ts-component`, `ts-backend` |

## How to build this with an AI coding agent

1. **Always in context:** `CLAUDE.md`.
2. **Work strictly in roadmap order.** Open the next phase in
   `TrailSisters_Development_Roadmap.md`; do not start Phase N+1 until Phase
   N's four test sections are green.
3. **Per phase, feed the agent:** the phase section + the screens listed for
   that phase in the workflow's §3.6 index (Part 1 entries, plus the journeys
   and §3.1–3.5 references they cite) + the PRD sections the phase cites.
4. **Screens are specs, not suggestions:** IDs are stable, quoted copy is
   normative, every listed state must ship.
5. Non-negotiables live in `CLAUDE.md` — women-only gating, zero raw-ID
   storage, RLS-before-client-code, no dating language, safety never
   paywalled. Decision tiebreak: safety > privacy > growth.

## Status

- [x] Documentation package (this repo)
- [ ] Phase 0 — Foundations (Xcode + Supabase + schema + RLS + CI)
- [ ] Phases 1–14 — P0 launch scope
- [ ] Phase 15 — P1 fast-follow
