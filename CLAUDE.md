# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

Monorepo with two apps:

```
expense-tracker/
├── apps/
│   ├── api/       → NestJS backend (Node.js / TypeScript)
│   └── mobile/    → Flutter app (web + iOS + Android, single codebase)
├── docs/superpowers/specs/  → Design specifications
└── docker-compose.yml       → Local dev: PostgreSQL + Redis
```

## Development Commands

### API (`apps/api/`)

```bash
docker compose up -d          # start local PostgreSQL + Redis
npm run start:dev             # start API in watch mode
npm run test                  # unit tests (Jest)
npm run test:e2e              # integration tests (requires docker compose up)
npm run test -- --testPathPattern=budget  # run a single test file
npx prisma migrate dev        # apply schema migrations
npx prisma studio             # browse database
npm run build                 # production build
```

### Flutter (`apps/mobile/`)

```bash
flutter pub get               # install dependencies
flutter run -d chrome         # run web in browser
flutter run                   # run on connected device/emulator
flutter test                  # all unit + widget tests
flutter test test/features/dashboard/  # run a single test directory
flutter analyze               # static analysis (zero warnings policy)
flutter build web             # production web build
flutter build apk             # Android build
flutter build ios             # iOS build (macOS only)
```

## Architecture

### Data flow

Flutter → Dio (JWT interceptor) → NestJS REST API → Prisma → PostgreSQL

Real-time notifications flow through a WebSocket connection (`/notifications`) backed by Redis pub/sub.

### Backend module structure

Each NestJS module owns its routes, service, and Prisma calls. Modules: `auth`, `users`, `workspaces`, `categories`, `transactions`, `recurring`, `budgets`, `reports`, `notifications`.

Every route under `/workspaces/:id/*` is protected by `WorkspaceMemberGuard`, which verifies the JWT user is a member of that workspace before the handler runs.

The `reports` module executes raw SQL aggregations via Prisma for performance — do not replace these with ORM queries.

### Background jobs

BullMQ (Redis-backed) runs four queues:
- `recurring-transactions` — cron midnight, creates transactions from due `recurring_rules`
- `budget-alerts` — triggered by EventEmitter after every transaction INSERT; checks spend vs budget thresholds
- `notifications-delivery` — sends push (FCM), email (SendGrid), and in-app (WebSocket + DB write)
- `monthly-summary` — cron 1st of month 08:00, sends digest to all workspace members

Budget alerts deduplicate via Redis key `budget:alert:{workspaceId}:{budgetId}:{month}:{threshold}` with 30-day TTL.

### Flutter state management

Each feature has its own Riverpod `AsyncNotifierProvider`. Providers live in `features/<name>/<name>_provider.dart`. All data models are Freezed classes in `shared/models/`.

The `core/api/api_client.dart` Dio interceptor handles JWT refresh silently — if a 401 is received it fetches a new access token using the stored refresh token and retries the original request.

Token storage: `flutter_secure_storage` on iOS/Android, `shared_preferences` on web.

### Auth flow

- Access tokens: RS256, 15-minute TTL
- Refresh tokens: 30-day TTL, stored hashed in DB, single-use (rotated on every refresh)
- Logout deletes the refresh token from DB immediately

## Critical Conventions

- **Money is always stored as integers (cents).** Never use floats for amounts anywhere in the stack. Convert to/from display strings at the UI layer only.
- **Currency is per-workspace**, not per-transaction. Set once on the workspace; all transactions inherit it. No multi-currency conversion in v1.
- **`WorkspaceMemberGuard` is mandatory** on every workspace-scoped route — never bypass it for convenience.
- **No raw SQL string interpolation** — use Prisma parameterized queries exclusively. The only exception is complex report aggregations, which use Prisma's `$queryRaw` with tagged template literals (safe parameterization).
- **Prisma error mapping**: P2002 → 409, P2025 → 404 — handled in the global `ExceptionFilter`.
- **Integration tests hit a real PostgreSQL instance** (via Docker). Do not mock the database in integration tests.

## Environment Variables

All secrets are environment variables — never hardcoded. See the spec at `docs/superpowers/specs/2026-06-16-expense-tracker-design.md` (Section 8) for the full list. Key vars: `DATABASE_URL`, `REDIS_URL`, `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY`, `SENDGRID_API_KEY`, `FIREBASE_SERVICE_ACCOUNT`, `GOOGLE_CLIENT_ID/SECRET`, `APPLE_CLIENT_ID/SECRET`.

## Agentic Pipeline

The full build pipeline lives in `.agents/`. Start with:

```
Read .agents/META-ORCHESTRATOR.md and start the full pipeline.
```

### Pipeline file map

| File | Role |
|---|---|
| `.agents/META-ORCHESTRATOR.md` | Top-level: runs plan-waves in sequence, dispatches ORCHESTRATOR subagents |
| `.agents/PHASE-MANIFEST.md` | 18 plans with IDs + depends-on; defines plan-level wave structure |
| `.agents/CONTRACT-AGENT.md` | Generates API contract before each wave (read by REVIEWER + TESTER) |
| `.agents/ORCHESTRATOR.md` | Runs one plan's task-waves; spawns TASK-AGENT per task in parallel |
| `.agents/TASK-AGENT.md` | Mini-orchestrator: DEVELOPER → (TESTER ∥ REVIEWER) → QA per task |
| `.agents/prompts/DEVELOPER.md` | Implements code; reads contract + project skills |
| `.agents/prompts/TESTER.md` | Writes independent tests verifying contract + spec |
| `.agents/prompts/REVIEWER.md` | Code reviews diff; checks contract compliance |
| `.agents/prompts/QA.md` | Acceptance criteria verification |
| `.agents/META-STATE.md` | Progress tracking for META-ORCHESTRATOR |
| `.agents/STATE.md` | Progress tracking template for each ORCHESTRATOR |
| `docs/contracts/` | Wave API contracts generated by CONTRACT-AGENT |

### Wave structure (plan-level)

| Wave | Plans | Peak |
|---|---|---|
| 1 | be-1 ∥ fl-1 | 2 |
| 2 | be-2 ∥ fl-2 | 2 |
| 3 | be-3 ∥ fl-3 | 2 |
| 4 | be-4 ∥ fl-4 ∥ fl-5 ∥ fl-6 ∥ fl-9 | 5 |
| 5 | be-5 ∥ fl-7 ∥ fl-8 | 3 |
| 6 | be-6 ∥ fl-10 | 2 |
| 7 | be-7 | 1 |
| 8 | be-8 | 1 |

### Available skills for agents

Agents must read the relevant skill before implementing:

| Skill | Path | When to use |
|---|---|---|
| `prisma` | `.agents/skills/prisma/SKILL.md` | Any Prisma schema or query work |
| `flutter` | `.agents/skills/flutter/SKILL.md` | Flutter/Dart development |
| `flutter-ui-ux` | `.agents/skills/flutter-ui-ux/SKILL.md` | Flutter UI components, animations |
| `mobile-app-ui-design` | `.agents/skills/mobile-app-ui-design/SKILL.md` | Screen design, layout decisions |
| `cicd-expert` | `.agents/skills/cicd-expert/SKILL.md` | GitHub Actions, Docker, Railway |

### UI design tokens (Flutter — mandatory)

| Token | Value | Usage |
|---|---|---|
| Primary | `#4F46E5` | Buttons, active states, links |
| Income | `#10B981` | Positive amounts, success |
| Expense | `#EF4444` | Negative amounts, over-budget |
| Warning | `#F59E0B` | 80–99% budget usage |
| Background | `#F1F5F9` | App/page background |
| Surface | `#FFFFFF` | Cards, panels, modals |
| Sidebar | `#0F172A` | Web sidebar |
| Text Primary | `#1E293B` | Headings, values |
| Text Secondary | `#64748B` | Labels, metadata |
| Text Hint | `#94A3B8` | Placeholders, timestamps |

Radii: cards `12px`, chips `20px`, buttons/inputs `8px`.
Typography: Inter/System UI · `700` headings · `600` labels · `400` body.
Spacing: 8-point grid (all values multiples of 4 or 8).
Budget bar thresholds: `< 80%` → green · `80–99%` → amber · `≥ 100%` → red.

Wireframes: `docs/superpowers/specs/2026-06-17-ui-wireframes.md`

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
