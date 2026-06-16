# Monthly Expense Tracker — Design Specification

**Date:** 2026-06-16
**Status:** Approved

---

## 1. Overview

A multi-user monthly expense tracker available as a Flutter web app (desktop browser) and native mobile app (iOS + Android) from a single codebase. Users can track expenses, income, recurring transactions, and budgets within shared workspaces (households/groups). Advanced analytics, CSV/PDF export, and multi-channel notifications are included.

---

## 2. Requirements

### 2.1 Functional Requirements

**Authentication**
- Email/password registration and login
- Social login via Google OAuth and Apple OAuth
- Password reset via email (SendGrid)
- JWT-based sessions: short-lived access token (15 min) + long-lived refresh token (30 days, rotated on use)

**Workspaces**
- Users can create multiple workspaces (e.g., "Personal", "Family Budget")
- Workspace owners can invite members via email (token-based invite, 72-hour expiry)
- Roles: `owner`, `admin`, `member`
- All financial data is scoped to a workspace
- Members can be removed by owner/admin

**Transactions**
- Log expenses and income with: amount, currency, category, description, date
- Edit and delete transactions
- Paginated, searchable, filterable transaction list (by date range, category, type, amount)
- Transactions linked to the workspace member who created them

**Categories**
- Workspace-scoped categories with name, icon, and color
- Type: `expense` or `income`
- Default categories seeded on workspace creation:
  - Expense: Housing, Food & Dining, Transport, Healthcare, Entertainment, Shopping, Utilities, Education, Other
  - Income: Salary, Freelance, Investment, Gift, Other

**Recurring Transactions**
- Define recurring rules: amount, category, frequency (daily / weekly / monthly / yearly), start date, optional end date
- Background job auto-creates transactions at midnight based on `next_run_at`
- Rules can be paused, edited, or deleted

**Budgets**
- Set monthly or yearly budgets per category or for the workspace total
- Budget progress visible on dashboard (% used)
- Alerts at 80% (warning) and 100% (exceeded) thresholds — deduplicated per threshold per month

**Reports & Analytics**
- Monthly summary: total income, total expenses, net balance
- Spending trends: month-over-month line chart for up to 24 months
- Category breakdown: pie chart + table
- Budget vs. actual: per-category adherence for selected month
- Year-over-year comparison: bar chart
- Daily spending heatmap
- Custom date range filter across all reports
- Export: CSV and PDF download (streamed from API)

**Notifications**
- In-app: real-time via WebSocket, unread badge on bell icon
- Email: budget alerts, monthly summary digest, workspace invites (SendGrid)
- Push: iOS/Android via Firebase Cloud Messaging

### 2.2 Non-Functional Requirements

- All API communication over HTTPS
- Auth endpoints rate-limited: 5 requests/min per IP
- Amounts stored as integers (cents) to avoid floating-point errors
- API response shape is consistent across all endpoints (success + error)
- No stack traces exposed to clients in production
- Refresh tokens invalidated immediately on logout
- Budget alert deduplication — one notification per threshold per budget per month

---

## 3. Application Stack

| Layer | Technology |
|---|---|
| Mobile & Web frontend | Flutter (Dart) — single codebase |
| State management | Riverpod (`AsyncNotifierProvider`) |
| Navigation | GoRouter with auth redirect guards |
| HTTP client | Dio with JWT interceptor + auto-refresh |
| Charts | FL Chart |
| Token storage | flutter_secure_storage (mobile) / shared_preferences (web) |
| Push notifications | firebase_messaging (FCM) |
| Backend framework | NestJS (Node.js / TypeScript) |
| ORM | Prisma |
| Database | PostgreSQL |
| Cache & job queues | Redis (Upstash) + BullMQ |
| Auth strategy | Passport.js (JWT, Google OAuth, Apple OAuth) |
| JWT signing | RS256 asymmetric keys |
| Password hashing | bcrypt (cost factor 12) |
| Email delivery | SendGrid |
| Push delivery | Firebase Admin SDK (FCM) |
| PDF generation | pdfkit |
| CSV generation | csv-writer |
| Input validation | class-validator + class-transformer DTOs |
| Rate limiting | @nestjs/throttler |
| API hosting | Railway or Render (Docker container) |
| Database hosting | Railway PostgreSQL (managed, daily backups) |
| Web hosting | Vercel (Flutter web build) |
| Mobile CI/CD | GitHub Actions + Fastlane (Android) + Xcode Cloud (iOS) |

---

## 4. System Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│         (Web browser + iOS + Android)            │
│  Dart/Flutter · Riverpod · GoRouter · FL Chart  │
└──────────────────────┬──────────────────────────┘
                       │ HTTPS / REST + WebSocket
┌──────────────────────▼──────────────────────────┐
│              NestJS API (REST + WS)              │
│  Auth · Workspaces · Transactions · Budgets      │
│  Recurring Engine · Reports · Notifications      │
└───┬──────────────┬──────────────┬───────────────┘
    │              │              │
┌───▼───┐    ┌────▼────┐   ┌─────▼─────┐
│  PG   │    │  Redis  │   │  BullMQ   │
│  DB   │    │  Cache  │   │  Queues   │
└───────┘    └─────────┘   └─────┬─────┘
                                 │
              ┌──────────────────┼──────────────┐
              │                  │              │
         ┌────▼────┐      ┌──────▼─────┐  ┌────▼────┐
         │  FCM    │      │  SendGrid  │  │ Cron Job│
         │ (Push)  │      │  (Email)   │  │(Recur.) │
         └─────────┘      └────────────┘  └─────────┘
```

**Three deployment units:**
1. **Flutter app** — compiled to web (Vercel), iOS (App Store), Android (Play Store)
2. **NestJS API** — Docker container on Railway/Render, auto-deployed on main merge
3. **Data layer** — PostgreSQL + Redis (Railway + Upstash)

**Monorepo structure:**
```
expense-tracker/
├── apps/
│   ├── api/          → NestJS backend
│   └── mobile/       → Flutter app
├── docs/
│   └── superpowers/specs/
└── docker-compose.yml  → local dev (PG + Redis)
```

---

## 5. Data Model

```
users
├── id, email, password_hash, name, avatar_url
├── oauth_provider, oauth_id
└── created_at, updated_at

workspaces
├── id, name, owner_id → users
├── currency (ISO 4217 code, e.g. "USD") — all transactions in this workspace use this currency
└── created_at

workspace_members
├── workspace_id → workspaces
├── user_id → users
└── role: ENUM(owner, admin, member)

categories
├── id, workspace_id → workspaces
├── name, icon, color
└── type: ENUM(expense, income)

transactions
├── id, workspace_id → workspaces
├── user_id → users (who logged it)
├── category_id → categories
├── amount (integer, cents), description, date
├── type: ENUM(expense, income)
├── recurring_rule_id → recurring_rules (nullable)
└── created_at

recurring_rules
├── id, workspace_id → workspaces
├── category_id → categories
├── amount (integer, cents), description, type
├── frequency: ENUM(daily, weekly, monthly, yearly)
├── start_date, end_date (nullable)
└── next_run_at

budgets
├── id, workspace_id → workspaces
├── category_id → categories (nullable = workspace total budget)
├── amount (integer, cents)
├── period: ENUM(monthly, yearly)
└── year, month (nullable for yearly)

notifications
├── id, user_id → users
├── type: ENUM(budget_alert, recurring_reminder, monthly_summary, invite)
├── payload (JSONB), read_at
└── created_at

workspace_invites
├── id, workspace_id → workspaces
├── invited_email, invited_by → users
├── token (UUID v4), status: ENUM(pending, accepted, expired)
└── expires_at
```

**Key decisions:**
- All amounts stored as integers (cents) — no floating-point errors
- Currency is set once per workspace (ISO 4217 code); all transactions inherit it — no multi-currency conversion in v1
- `transactions` workspace-scoped — enables shared household tracking
- `budgets.category_id` nullable — supports both category-level and total workspace budgets
- `recurring_rules.next_run_at` — queried by BullMQ cron to find due rules each midnight

---

## 6. Backend API Structure

```
POST   /auth/register
POST   /auth/login
POST   /auth/refresh
POST   /auth/logout
GET    /auth/google
GET    /auth/google/callback
GET    /auth/apple/callback
POST   /auth/forgot-password

GET    /users/me
PUT    /users/me

POST   /workspaces
GET    /workspaces
PUT    /workspaces/:id
POST   /workspaces/:id/invite
POST   /workspaces/:id/join
DELETE /workspaces/:id/members/:userId

GET    /workspaces/:id/categories
POST   /workspaces/:id/categories
PUT    /workspaces/:id/categories/:catId
DELETE /workspaces/:id/categories/:catId

GET    /workspaces/:id/transactions
POST   /workspaces/:id/transactions
PUT    /workspaces/:id/transactions/:txId
DELETE /workspaces/:id/transactions/:txId

GET    /workspaces/:id/recurring
POST   /workspaces/:id/recurring
PUT    /workspaces/:id/recurring/:ruleId
DELETE /workspaces/:id/recurring/:ruleId

GET    /workspaces/:id/budgets
POST   /workspaces/:id/budgets
PUT    /workspaces/:id/budgets/:budgetId
DELETE /workspaces/:id/budgets/:budgetId

GET    /workspaces/:id/reports/summary
GET    /workspaces/:id/reports/trends
GET    /workspaces/:id/reports/by-category
GET    /workspaces/:id/reports/budget-vs-actual
GET    /workspaces/:id/reports/year-over-year
GET    /workspaces/:id/reports/heatmap
GET    /workspaces/:id/reports/export?format=csv|pdf

GET    /notifications
PUT    /notifications/:id/read
PUT    /notifications/read-all
WS     /notifications
```

**Cross-cutting:**
- `WorkspaceMemberGuard` on all `/workspaces/:id/*` routes
- `@nestjs/throttler` rate limiting on all `/auth/*` routes
- Global `ExceptionFilter` returns consistent error shape: `{ statusCode, error, message }`
- Prisma error codes mapped: P2002 → 409, P2025 → 404

---

## 7. Flutter App Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── api/
│   │   ├── api_client.dart          → Dio + JWT interceptor + token refresh
│   │   └── websocket_client.dart    → Real-time notification channel
│   ├── auth/
│   │   ├── auth_provider.dart       → Riverpod auth state
│   │   └── secure_storage.dart      → Token persistence
│   ├── router/app_router.dart       → GoRouter + auth guards
│   └── theme/app_theme.dart         → Light/dark theme
│
├── features/
│   ├── auth/                        → login, register, forgot password, OAuth buttons
│   ├── dashboard/                   → monthly summary, recent transactions, budget bars
│   ├── transactions/                → paginated list, add/edit bottom sheet, filters
│   ├── budgets/                     → budget list, create/edit form, progress bars
│   ├── recurring/                   → recurring rules list and form
│   ├── reports/
│   │   ├── reports_screen.dart      → Tab view across all report types
│   │   ├── charts/                  → FL Chart components (bar, pie, line, heatmap)
│   │   └── export_button.dart       → CSV/PDF download trigger
│   ├── workspaces/                  → switcher, settings, member management, invites
│   └── notifications/               → bell icon with badge, notification list
│
└── shared/
    ├── widgets/                     → amount_field, category_picker, date_range_picker
    └── models/                      → Freezed data classes with JSON serialization
```

---

## 8. Background Jobs & Notifications

**BullMQ Queues:**

| Queue | Job | Schedule / Trigger |
|---|---|---|
| `recurring-transactions` | `process-due-rules` | Cron: `0 0 * * *` (midnight daily) |
| `budget-alerts` | `check-budget` | Event: after every transaction INSERT |
| `notifications-delivery` | `send-push` / `send-email` / `send-in-app` | Triggered by budget-alerts processor |
| `monthly-summary` | `generate-summary` | Cron: `0 8 1 * *` (1st of month, 08:00) |

**Recurring engine logic:**
1. Query `recurring_rules WHERE next_run_at <= NOW()`
2. For each rule: INSERT transaction, UPDATE `next_run_at` by frequency
3. Emit event to trigger budget-alert check

**Budget alert deduplication:**
- Redis key: `budget:alert:{workspaceId}:{budgetId}:{month}:{threshold}`
- TTL: 30 days
- Prevents duplicate alerts per threshold per budget per calendar month

**Job reliability:**
- 3 retry attempts with exponential backoff
- Failed jobs → dead-letter queue for inspection

---

## 9. Security

| Layer | Control |
|---|---|
| Passwords | bcrypt, cost factor 12 |
| JWT signing | RS256 asymmetric keys |
| Access token TTL | 15 minutes |
| Refresh token | 30 days, hashed in DB, single-use (rotated) |
| Transport | HTTPS only, HSTS enforced |
| Auth rate limiting | 5 requests/min per IP via @nestjs/throttler |
| Workspace authorization | WorkspaceMemberGuard on every workspace route |
| Input validation | class-validator DTOs, whitelist + forbidNonWhitelisted |
| SQL injection | Prisma parameterized queries only |
| Invite tokens | UUID v4, 72-hour expiry, single-use |
| Secrets | Environment variables only — never in codebase |

---

## 10. Testing Strategy

**Backend (Jest):**
- Unit tests: services in isolation (mocked Prisma + Redis)
  - `BudgetAlertService` — threshold logic
  - `RecurringRuleService` — `next_run_at` computation
  - `ReportService` — aggregation calculations
- Integration tests (Supertest + real PostgreSQL via Docker):
  - Auth flow, workspace invitations, transaction CRUD
  - Budget alert trigger end-to-end
  - Report endpoint response shapes

**Flutter (Dart):**
- Unit tests: Riverpod providers (mock Dio via `http_mock_adapter`), model serialization, amount formatting
- Widget tests: `AddTransactionSheet`, `BudgetProgressBar`, `NotificationBell`
- Integration tests (patrol): login → dashboard, add transaction, budget exceeded alert

**CI (GitHub Actions):**
```
On PR:    backend:test → flutter:analyze → flutter:test → docker:build
On main:  deploy:api (Railway) → deploy:web (Vercel)
```

---

## 11. Deployment & Infrastructure

| Component | Service |
|---|---|
| NestJS API | Railway (Docker, auto-deploy) |
| PostgreSQL | Railway PostgreSQL (managed, daily backups) |
| Redis | Upstash (serverless, pay-per-use) |
| Flutter Web | Vercel (CDN, automatic HTTPS) |
| iOS | Apple App Store (Xcode Cloud) |
| Android | Google Play Store (Fastlane + GitHub Actions) |
| Email | SendGrid |
| Push | Firebase Cloud Messaging (free) |
| Avatar storage | Cloudinary |

**Scaling path:**
- Start: single Railway container (handles ~500 concurrent users)
- Scale: Railway horizontal replicas + PgBouncer connection pooling
- BullMQ workers extracted to separate container if job throughput demands it
