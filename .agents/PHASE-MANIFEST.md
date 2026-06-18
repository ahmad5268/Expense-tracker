# Phase Manifest

> Read by META-ORCHESTRATOR to build the plan-level wave structure.
> `depends-on` lists plan IDs that must be fully committed before this plan starts.
> Plans with no mutual dependency share a wave and run in parallel.

---

## Backend API

| ID | Plan file | Depends-on |
|---|---|---|
| be-1 | `docs/superpowers/plans/2026-06-16-backend-api-phase1.md` | — |
| be-2 | `docs/superpowers/plans/2026-06-16-backend-api-phase2.md` | be-1 |
| be-3 | `docs/superpowers/plans/2026-06-16-backend-api-phase3.md` | be-2 |
| be-4 | `docs/superpowers/plans/2026-06-16-backend-api-phase4.md` | be-3 |
| be-5 | `docs/superpowers/plans/2026-06-16-backend-api-phase5.md` | be-4 |
| be-6 | `docs/superpowers/plans/2026-06-16-backend-api-phase6.md` | be-5 |
| be-7 | `docs/superpowers/plans/2026-06-16-backend-api-phase7.md` | be-6 |
| be-8 | `docs/superpowers/plans/2026-06-16-backend-api-phase8.md` | be-7 |

## Flutter

| ID | Plan file | Depends-on |
|---|---|---|
| fl-1 | `docs/superpowers/plans/2026-06-16-flutter-phase1.md` | — |
| fl-2 | `docs/superpowers/plans/2026-06-16-flutter-phase2.md` | fl-1 |
| fl-3 | `docs/superpowers/plans/2026-06-16-flutter-phase3.md` | fl-2 |
| fl-4 | `docs/superpowers/plans/2026-06-16-flutter-phase4.md` | fl-3 |
| fl-5 | `docs/superpowers/plans/2026-06-16-flutter-phase5.md` | fl-3 |
| fl-6 | `docs/superpowers/plans/2026-06-16-flutter-phase6.md` | fl-3 |
| fl-7 | `docs/superpowers/plans/2026-06-16-flutter-phase7.md` | fl-4, fl-5 |
| fl-8 | `docs/superpowers/plans/2026-06-16-flutter-phase8.md` | fl-5 |
| fl-9 | `docs/superpowers/plans/2026-06-16-flutter-phase9.md` | fl-3 |
| fl-10 | `docs/superpowers/plans/2026-06-16-flutter-phase10.md` | fl-7, fl-8, fl-9 |

---

## Computed Wave Structure

_(META-ORCHESTRATOR derives this on every run from the depends-on column above.
Shown here for quick reference — do not edit manually.)_

| Wave | Plans running in parallel |
|---|---|
| 1 | be-1 ∥ fl-1 |
| 2 | be-2 ∥ fl-2 |
| 3 | be-3 ∥ fl-3 |
| 4 | be-4 ∥ fl-4 ∥ fl-5 ∥ fl-6 ∥ fl-9 |
| 5 | be-5 ∥ fl-7 ∥ fl-8 |
| 6 | be-6 ∥ fl-10 |
| 7 | be-7 |
| 8 | be-8 |

**18 plans. 8 waves. Peak of 5 plans running simultaneously in Wave 4.**
