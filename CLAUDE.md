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
