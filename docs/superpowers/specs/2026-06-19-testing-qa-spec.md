# Testing, Code Review & QA Specification

**Date:** 2026-06-19  
**Status:** Approved — implement before production release  
**Scope:** Full-stack: NestJS API + Flutter mobile/web

---

## Table of Contents

1. [Testing Philosophy](#1-testing-philosophy)
2. [Test Inventory — What Exists](#2-test-inventory--what-exists)
3. [Coverage Requirements](#3-coverage-requirements)
4. [Unit Tests — NestJS API](#4-unit-tests--nestjs-api)
5. [Integration Tests — NestJS API (E2E)](#5-integration-tests--nestjs-api-e2e)
6. [Unit & Widget Tests — Flutter](#6-unit--widget-tests--flutter)
7. [Flutter Integration Tests](#7-flutter-integration-tests)
8. [End-to-End Tests — Web UI (Playwright)](#8-end-to-end-tests--web-ui-playwright)
9. [Contract Testing](#9-contract-testing)
10. [Code Review Checklist](#10-code-review-checklist)
11. [QA Workflow](#11-qa-workflow)
12. [CI/CD Pipeline](#12-cicd-pipeline)
13. [Implementation Priority Order](#13-implementation-priority-order)

---

## 1. Testing Philosophy

### Guiding Rules

- **No mocked databases in integration tests.** All E2E/integration tests hit real PostgreSQL via Docker. (CLAUDE.md constraint.)
- **Money is always integers (cents).** Every test that touches amounts must assert integer values — never floats.
- **WorkspaceMemberGuard must be tested.** Every workspace-scoped endpoint must have a test proving a non-member gets 403.
- **Token rotation is a contract.** Every refresh-token test must confirm the old token is invalidated after use.
- **Test names describe behaviour, not implementation.** Use `it('returns 409 when email already registered')` not `it('tests ConflictException')`.
- **Arrange / Act / Assert structure** for every test.

### Test Pyramid Target

```
        ┌─────────────┐
        │  E2E / UI   │  ← 5–10 critical flows (Playwright)
        │  Playwright │
        ├─────────────┤
        │  Contract   │  ← OpenAPI schema validation after every E2E run
        ├─────────────┤
        │ Integration │  ← All API endpoints: real DB, real HTTP (Supertest)
        │  (E2E API)  │
        ├─────────────┤
        │ Flutter Int │  ← Key user journeys on real device/emulator
        ├─────────────┤
        │ Widget Tests│  ← Every screen + shared widget
        ├─────────────┤
        │ Unit Tests  │  ← Pure business logic, service methods, models
        └─────────────┘
```

---

## 2. Test Inventory — What Exists

### NestJS Unit Tests (complete)

| File | Status | Notes |
|---|---|---|
| `auth/auth.service.spec.ts` | ✅ Exists | Covers register, login, logout, resetPassword |
| `workspaces/workspaces.service.spec.ts` | ✅ Exists | Verify covers invite flow |
| `budgets/budgets.service.spec.ts` | ✅ Exists | Verify covers alert deduplication |
| `transactions/transactions.service.spec.ts` | ✅ Exists | Verify covers pagination + filter |
| `recurring/recurring.service.spec.ts` | ✅ Exists | Verify covers next_run_at advancement |
| `jobs/processors/recurring.processor.spec.ts` | ✅ Exists | — |
| `jobs/processors/budget-alert.processor.spec.ts` | ✅ Exists | — |
| `notifications/notifications.service.spec.ts` | ✅ Exists | — |
| `reports/reports.service.spec.ts` | ✅ Exists | — |
| `common/filters/http-exception.filter.spec.ts` | ✅ Exists | — |
| `common/interceptors/transform.interceptor.spec.ts` | ✅ Exists | — |
| `workspaces/guards/workspace-member.guard.spec.ts` | ✅ Exists | — |

### NestJS E2E Tests (gaps exist)

| File | Status | Missing coverage |
|---|---|---|
| `test/auth.e2e-spec.ts` | ✅ Exists | Missing `GET /auth/me` |
| `test/workspaces.e2e-spec.ts` | ✅ Exists | Missing invite flow, member removal |
| `test/budgets.e2e-spec.ts` | ❌ Missing | Entire file missing |
| `test/transactions.e2e-spec.ts` | ❌ Missing | Separate file for full CRUD + filter |
| `test/categories.e2e-spec.ts` | ❌ Missing | Custom category CRUD |
| `test/recurring.e2e-spec.ts` | ❌ Missing | Recurring rule CRUD + cron trigger |
| `test/reports.e2e-spec.ts` | ❌ Missing | All report endpoints |
| `test/notifications.e2e-spec.ts` | ❌ Missing | Preferences, mark-read, WebSocket |

### Flutter Unit/Widget Tests (gaps exist)

| File | Status | Notes |
|---|---|---|
| `test/shared/models/*.dart` | ✅ Exists | All 5 models covered |
| `test/shared/utils/currency_formatter_test.dart` | ✅ Exists | — |
| `test/features/auth/login_screen_test.dart` | ✅ Exists | Basic — needs error/loading states |
| `test/features/auth/auth_provider_test.dart` | ✅ Exists | Verify covers session restore |
| `test/features/dashboard/dashboard_provider_test.dart` | ✅ Exists | — |
| `test/features/transactions/transactions_provider_test.dart` | ✅ Exists | — |
| `test/features/budgets/budgets_provider_test.dart` | ✅ Exists | — |
| `test/features/reports/reports_provider_test.dart` | ✅ Exists | — |
| `test/features/recurring/recurring_provider_test.dart` | ✅ Exists | — |
| `test/core/api/api_client_test.dart` | ✅ Exists | Verify covers refresh fix |
| `test/features/auth/register_screen_test.dart` | ❌ Missing | — |
| `test/features/dashboard/dashboard_screen_test.dart` | ❌ Missing | — |
| `test/features/transactions/add_transaction_sheet_test.dart` | ❌ Missing | — |
| `test/features/transactions/transaction_list_screen_test.dart` | ❌ Missing | — |
| `test/features/budgets/budgets_screen_test.dart` | ❌ Missing | — |
| `test/features/workspaces/create_workspace_screen_test.dart` | ❌ Missing | — |
| `test/features/recurring/recurring_screen_test.dart` | ❌ Missing | — |
| `test/features/reports/reports_screen_test.dart` | ❌ Missing | — |
| `test/core/router/app_router_test.dart` | ❌ Missing | Redirect logic |

### Flutter Integration Tests (all missing)

`integration_test/` directory does not exist — all flows need creating.

### Playwright E2E Tests (all missing)

`e2e/` directory does not exist — all flows need creating.

---

## 3. Coverage Requirements

### NestJS

| Layer | Target | Tool |
|---|---|---|
| Unit (services, guards, filters) | ≥ 80% statement coverage | Jest `--coverage` |
| E2E (integration) | All public endpoints covered | Supertest |
| Critical paths | 100% branch coverage | `register`, `login`, `refresh`, `WorkspaceMemberGuard` |

Run coverage: `npm run test -- --coverage --coverageDirectory=coverage/unit`

### Flutter

| Layer | Target | Tool |
|---|---|---|
| Models (Freezed) | 100% — serialisation round-trips | `flutter test` |
| Providers | ≥ 80% | `flutter test --coverage` |
| Widget tests | Every user-facing screen has ≥ 1 smoke test | `flutter test` |
| Integration tests | 5 critical flows pass on Chrome | `flutter test integration_test/` |

---

## 4. Unit Tests — NestJS API

### 4.1 Files to Add or Augment

#### `test/auth.e2e-spec.ts` — add to existing file

```
describe('GET /auth/me')
  it('returns user profile with valid access token')   → 200 { data: { id, email, name } }
  it('returns 401 without token')                       → 401
  it('returns 401 with expired/invalid token')          → 401
```

#### `src/auth/auth.service.spec.ts` — add to existing file

```
describe('getMe')
  it('returns user when found')
  it('throws NotFoundException when user does not exist')

describe('refresh')
  it('returns new token pair and rotates refresh token')
  it('throws when refresh token does not match stored hash')
  it('throws when user has no stored refresh token hash')
```

#### `src/workspaces/workspaces.service.spec.ts` — verify / add

```
describe('invite')
  it('creates invite record with 72-hour expiry')
  it('throws ConflictException when email is already a member')

describe('acceptInvite')
  it('adds user as member and marks token used')
  it('throws when token expired')
  it('throws when token already used')

describe('removeMember')
  it('removes member from workspace')
  it('throws when attempting to remove the owner')
```

#### `src/budgets/budgets.service.spec.ts` — verify / add

```
describe('create')
  it('stores amount as integer (cents)')
  it('throws when categoryId does not belong to workspace')

describe('checkBudgetAlert (alert deduplication)')
  it('emits alert event at 80% threshold')
  it('emits alert event at 100% threshold')
  it('does NOT emit duplicate alert within same month (Redis key exists)')

describe('findAll')
  it('returns budgets with current spend calculated')
```

#### `src/transactions/transactions.service.spec.ts` — verify / add

```
describe('create')
  it('stores amount as integer — rejects if float passed')
  it('emits budget-alert event after INSERT')
  it('throws 403 when categoryId belongs to different workspace')

describe('findAll')
  it('filters by dateFrom / dateTo')
  it('filters by categoryId')
  it('filters by type (INCOME / EXPENSE)')
  it('returns paginated result with correct meta.total')
  it('returns transactions sorted by date DESC')

describe('update')
  it('updates amount and re-emits budget-alert event')

describe('delete')
  it('deletes transaction and re-emits budget-alert event')
```

#### `src/recurring/recurring.service.spec.ts` — verify / add

```
describe('create')
  it('sets next_run_at based on startDate + frequency')

describe('processRule')
  it('creates transaction and advances next_run_at by one period')
  it('marks rule inactive when past endDate')
  it('skips paused rules')
```

#### `src/reports/reports.service.spec.ts` — verify / add

```
describe('monthlySummary')
  it('returns totalIncome, totalExpenses, net as integers')
  it('scopes results to the correct workspaceId and month')

describe('categoryBreakdown')
  it('returns amounts in cents')
  it('returns zero-spend categories when includEmpty=true')

describe('exportCsv')
  it('sanitises description to prevent formula injection (no leading =+-@)')
  it('formats amounts as decimal strings (e.g. "50.00" not "5000")')
```

---

## 5. Integration Tests — NestJS API (E2E)

Each file boots `AppModule` against the real Docker PostgreSQL. All tests clean up their own data in `afterAll`.

### 5.1 `test/budgets.e2e-spec.ts` (new file)

Setup: register → create workspace → get a category id.

```
POST /workspaces/:id/budgets
  ✓ creates budget and returns it with correct integer amount
  ✓ returns 400 when amount is missing
  ✓ returns 400 when period is not MONTHLY or YEARLY
  ✓ returns 403 when caller is not a workspace member
  ✓ returns 401 without token

GET /workspaces/:id/budgets
  ✓ returns list with current spend field
  ✓ returns empty array when no budgets exist
  ✓ returns 403 for non-member

PATCH /workspaces/:id/budgets/:budgetId
  ✓ updates amount and period
  ✓ returns 404 for non-existent budget
  ✓ returns 403 for non-member

DELETE /workspaces/:id/budgets/:budgetId
  ✓ deletes budget and returns 204
  ✓ returns 404 for non-existent budget
  ✓ returns 403 for non-member
```

### 5.2 `test/transactions.e2e-spec.ts` (new file — expand existing coverage)

```
POST /workspaces/:id/transactions
  ✓ creates EXPENSE with integer amount
  ✓ creates INCOME with integer amount
  ✓ returns 400 when amount is 0 or negative
  ✓ returns 400 when date is invalid format
  ✓ returns 400 when categoryId is not a valid UUID
  ✓ returns 403 for non-member
  ✓ returns 401 without token

GET /workspaces/:id/transactions
  ✓ returns paginated list (default page=1, limit=20)
  ✓ filters by type=EXPENSE returns only expenses
  ✓ filters by type=INCOME returns only income
  ✓ filters by dateFrom / dateTo
  ✓ filters by categoryId
  ✓ meta.total is accurate after multiple inserts
  ✓ returns 403 for non-member

PATCH /workspaces/:id/transactions/:txId
  ✓ updates amount (integer) and description
  ✓ returns 404 for non-existent transaction
  ✓ returns 403 for non-member

DELETE /workspaces/:id/transactions/:txId
  ✓ deletes and returns 204
  ✓ subsequent GET omits the deleted transaction
  ✓ returns 403 for non-member
```

### 5.3 `test/categories.e2e-spec.ts` (new file)

```
GET /workspaces/:id/categories
  ✓ returns 14 seeded categories on fresh workspace
  ✓ categories have correct type (EXPENSE / INCOME)
  ✓ returns 403 for non-member

POST /workspaces/:id/categories
  ✓ creates custom category with name, icon, color, type
  ✓ returns 400 when name is empty
  ✓ returns 403 for non-member

PATCH /workspaces/:id/categories/:catId
  ✓ updates name and color
  ✓ returns 404 for non-existent category
  ✓ returns 403 for non-member

DELETE /workspaces/:id/categories/:catId
  ✓ deletes category and returns 204
  ✓ returns 409 when category has transactions referencing it
```

### 5.4 `test/recurring.e2e-spec.ts` (new file)

```
POST /workspaces/:id/recurring
  ✓ creates rule and sets correct next_run_at
  ✓ returns 400 when frequency is invalid
  ✓ returns 403 for non-member

GET /workspaces/:id/recurring
  ✓ lists active rules
  ✓ excludes paused rules when active=true query param

PATCH /workspaces/:id/recurring/:ruleId
  ✓ updates amount and pauses rule (isActive: false)

DELETE /workspaces/:id/recurring/:ruleId
  ✓ soft-deletes (sets isActive=false) or hard-deletes per spec
  ✓ returns 403 for non-member
```

### 5.5 `test/reports.e2e-spec.ts` (new file)

```
GET /workspaces/:id/reports/monthly-summary?year=2026&month=6
  ✓ returns totalIncome, totalExpenses, net as integers
  ✓ returns zeros for month with no transactions
  ✓ returns 403 for non-member

GET /workspaces/:id/reports/category-breakdown?year=2026&month=6
  ✓ returns array with amount in cents
  ✓ returns 403 for non-member

GET /workspaces/:id/reports/spending-trends?months=12
  ✓ returns 12 data points
  ✓ each point has { month, totalExpenses, totalIncome } as integers

GET /workspaces/:id/reports/export/csv
  ✓ Content-Type is text/csv
  ✓ first line is header row
  ✓ amounts are formatted as decimal strings, not cents
  ✓ no cell starts with = + - @ (formula injection prevention)

GET /workspaces/:id/reports/export/pdf
  ✓ Content-Type is application/pdf
  ✓ returns 403 for non-member
```

### 5.6 `test/workspaces.e2e-spec.ts` — add to existing file

```
describe('Workspace invites')
  ✓ POST /workspaces/:id/invite sends invite (204 + DB record)
  ✓ GET /workspaces/invite/:token accepts invite and adds member
  ✓ GET /workspaces/invite/:token returns 410 when token expired
  ✓ POST /workspaces/:id/invite returns 409 when email is already a member

describe('Member management')
  ✓ DELETE /workspaces/:id/members/:userId removes member (204)
  ✓ DELETE /workspaces/:id/members/:ownerId returns 403 (cannot remove owner)
  ✓ Returns 403 when caller is not owner or admin
```

### 5.7 `test/notifications.e2e-spec.ts` (new file)

```
GET /notifications
  ✓ returns empty array for new user
  ✓ returns 401 without token

PATCH /notifications/:id/read
  ✓ marks notification as read
  ✓ returns 404 for non-existent notification

PATCH /notifications/read-all
  ✓ marks all notifications as read (204)

GET /notifications/preferences
  ✓ returns default preferences for new user

PATCH /notifications/preferences
  ✓ updates email and push preferences
  ✓ returns 400 for invalid preference keys
```

### 5.8 `test/auth.e2e-spec.ts` — add to existing file

```
describe('GET /auth/me')
  ✓ returns { id, email, name } with valid access token (200)
  ✓ returns 401 without token
  ✓ returns 401 with expired token

describe('POST /auth/reset-password')
  ✓ resets password with valid token (204)
  ✓ returns 401 with expired token
  ✓ returns 401 with already-used token
  ✓ old refresh token is invalidated after reset

describe('Refresh token rotation')
  ✓ old refresh token is rejected after a single use
  ✓ refreshing with an access token (not refresh token) returns 401
```

---

## 6. Unit & Widget Tests — Flutter

### 6.1 Model Tests — audit existing, ensure round-trip

All `shared/models/` Freezed classes must have:
```
it('fromJson → toJson round-trip preserves all fields')
it('amount field is int, never double')
it('fromJson with null optional fields does not throw')
```

### 6.2 Provider Tests — audit / augment

#### `test/features/auth/auth_provider_test.dart`

```
it('build() returns null when no access token stored')
it('build() calls GET /auth/me and returns User when token exists')
it('build() returns null when /auth/me throws (expired + no refresh)')
it('login() sets state to AsyncData(user) on success')
it('login() re-throws and keeps state AsyncData(null) on failure')
it('logout() clears state and calls AuthService.logout()')
```

#### `test/core/api/api_client_test.dart`

```
it('onRequest interceptor attaches Bearer token to every request')
it('refresh interceptor uses a SEPARATE Dio instance (does not trigger onRequest)')
it('refresh interceptor sends refresh token (not access token) in Authorization header')
it('refresh interceptor retries original request with new access token on 401')
it('refresh interceptor clears tokens and does not retry when refresh fails with 401')
```

### 6.3 Widget Tests — new files required

#### `test/features/auth/register_screen_test.dart`

```
testWidgets('shows name, email, password fields and register button')
testWidgets('shows validation errors on empty submit')
testWidgets('shows error banner when register throws')
testWidgets('password field toggles visibility when eye icon tapped')
testWidgets('calls AuthService.register with trimmed values')
```

#### `test/features/dashboard/dashboard_screen_test.dart`

```
testWidgets('shows loading indicator while dashboardNotifier is loading')
testWidgets('shows empty workspace state when no workspace selected')
testWidgets('shows hero balance card with formatted net balance')
testWidgets('shows income and expense stat chips')
testWidgets('shows recent transactions list when transactions exist')
testWidgets('FAB is hidden when no workspace is active')
testWidgets('FAB opens AddTransactionSheet when tapped')
testWidgets('pull-to-refresh calls dashboardNotifier.load()')
```

#### `test/features/transactions/add_transaction_sheet_test.dart`

```
testWidgets('calls load() in initState when categories is empty')
testWidgets('shows category dropdown populated with categories')
testWidgets('shows income/expense type toggle')
testWidgets('amount field rejects non-numeric input')
testWidgets('amount field converts decimal input to cents on submit')
testWidgets('submit calls transactionsNotifier.create() with correct data')
testWidgets('shows error banner on submit failure')
testWidgets('sheet closes on successful submit')
```

#### `test/features/transactions/transaction_list_screen_test.dart`

```
testWidgets('shows paginated list of transactions')
testWidgets('shows income amounts in green color')
testWidgets('shows expense amounts in red color')
testWidgets('filter chip changes active filter')
testWidgets('empty state shows message when no transactions')
```

#### `test/features/budgets/budgets_screen_test.dart`

```
testWidgets('renders budget progress bar for each budget')
testWidgets('budget bar is green when spend < 80% of limit')
testWidgets('budget bar is amber when spend is 80–99% of limit')
testWidgets('budget bar is red when spend >= 100% of limit')
testWidgets('tapping Add opens CreateEditBudgetSheet')
testWidgets('amounts display as formatted currency strings, not raw cents')
```

#### `test/features/workspaces/create_workspace_screen_test.dart`

```
testWidgets('shows name and currency fields')
testWidgets('shows validation error on empty name')
testWidgets('currency dropdown contains expected currencies (USD, EUR, GBP, etc.)')
testWidgets('submit calls workspacesNotifier.create()')
testWidgets('shows error on create failure')
```

#### `test/core/router/app_router_test.dart`

```
testWidgets('redirects unauthenticated user from /dashboard to /login')
testWidgets('redirects authenticated user from /login to /dashboard')
testWidgets('does NOT redirect while auth state is loading (isLoading = true)')
testWidgets('navigating to /workspaces/create works when authenticated')
```

---

## 7. Flutter Integration Tests

Use `package:integration_test` with a real backend (Docker Compose running). Tests run against `http://localhost:3000`.

Create directory: `apps/mobile/integration_test/`

### 7.1 `integration_test/auth_flow_test.dart`

```dart
testWidgets('can register, login, and reach dashboard', (tester) async {
  // 1. Opens app → sees login screen
  // 2. Taps "Create account" → register screen
  // 3. Fills name, email, password → taps Create Account
  // 4. Asserts dashboard screen is shown
  // 5. Hot restarts app → asserts still on dashboard (session restored)
});

testWidgets('logout clears session', (tester) async {
  // 1. Login
  // 2. Tap logout in profile/menu
  // 3. Assert redirected to login screen
  // 4. Hot restart → assert login screen (not dashboard)
});
```

### 7.2 `integration_test/workspace_flow_test.dart`

```dart
testWidgets('can create workspace and see default categories', (tester) async {
  // 1. Login
  // 2. Tap "Create Workspace" from empty state
  // 3. Enter name + currency → submit
  // 4. Assert workspace name appears in AppBar
  // 5. Navigate to Add Transaction → assert category list is populated
});
```

### 7.3 `integration_test/transaction_flow_test.dart`

```dart
testWidgets('can add and view a transaction', (tester) async {
  // 1. Login + has active workspace
  // 2. Tap FAB → sheet opens
  // 3. Fill amount (e.g. 12.50), type=EXPENSE, pick category
  // 4. Tap Add → sheet closes
  // 5. Assert dashboard hero card updated (expenses shows 1250 cents = "$12.50")
  // 6. Navigate to Transactions → see the new transaction
});
```

### 7.4 `integration_test/budget_flow_test.dart`

```dart
testWidgets('can create budget and see progress bar', (tester) async {
  // 1. Navigate to Budgets screen
  // 2. Tap Add → CreateEditBudgetSheet opens
  // 3. Enter amount 10000 (=$100), period MONTHLY, optional category
  // 4. Submit → assert budget appears with 0% progress bar
  // 5. Add an expense → return to budgets → assert progress bar updated
});
```

### 7.5 `integration_test/token_refresh_test.dart`

```dart
testWidgets('expired access token is refreshed transparently', (tester) async {
  // 1. Login
  // 2. Manually expire access token in SharedPreferences (set old value)
  // 3. Trigger any API call (e.g. pull-to-refresh on dashboard)
  // 4. Assert request succeeds (no 401 shown to user)
  // 5. Assert new access token is stored in SharedPreferences
});
```

---

## 8. End-to-End Tests — Web UI (Playwright)

### Setup

```
apps/e2e/
├── playwright.config.ts
├── helpers/
│   └── auth.ts          ← login() helper used by every test
└── tests/
    ├── auth.spec.ts
    ├── workspace.spec.ts
    ├── transactions.spec.ts
    ├── budgets.spec.ts
    └── reports.spec.ts
```

`playwright.config.ts` base URL: `http://localhost:3001` (Flutter web build served locally).

All tests use `test.beforeEach` to log in via the API directly (fast, no UI login overhead) except `auth.spec.ts`.

### 8.1 `tests/auth.spec.ts`

```typescript
test('login page shows two-panel layout on desktop viewport')
test('register form shows validation errors on empty submit')
test('successful login redirects to /dashboard')
test('after login, refreshing page keeps user on dashboard (session restore)')
test('logout navigates to login screen')
test('register with existing email shows error message')
```

### 8.2 `tests/workspace.spec.ts`

```typescript
test('empty state shown on first login with Create Workspace CTA')
test('creating workspace shows workspace name in sidebar and AppBar')
test('workspace switcher changes active workspace')
```

### 8.3 `tests/transactions.spec.ts`

```typescript
test('add transaction via FAB → appears in transaction list')
test('hero balance card updates after adding expense')
test('filter by type=EXPENSE shows only expenses')
test('filter by date range returns correct transactions')
test('delete transaction removes it from list and updates balance')
test('edit transaction updates amount in list')
```

### 8.4 `tests/budgets.spec.ts`

```typescript
test('create budget shows 0% progress bar')
test('budget progress bar turns amber when spend reaches 80%')
test('budget progress bar turns red when spend reaches 100%')
test('delete budget removes it from the list')
```

### 8.5 `tests/reports.spec.ts`

```typescript
test('monthly summary shows correct income/expense/net for current month')
test('category breakdown chart renders with spending data')
test('CSV export downloads a file with correct headers')
test('switching month updates all report figures')
```

---

## 9. Contract Testing

Contract testing ensures the Flutter client's expectations of the API response shape are never broken by backend changes.

### Approach: OpenAPI Schema Validation

The NestJS API exposes a Swagger schema at `GET /api-json`. After every E2E test run, validate every response body against this schema.

### 9.1 API Schema Validation (NestJS side)

**Required `test/contract.e2e-spec.ts`:**

```typescript
describe('Contract: Response shapes', () => {
  // Auth
  it('POST /auth/register response matches AuthResponseDto schema')
  it('GET /auth/me response matches AuthUserDto schema')
  
  // Workspaces
  it('GET /workspaces response matches WorkspaceDto[] schema')
  it('POST /workspaces response matches WorkspaceDto schema')
  
  // Transactions
  it('GET /workspaces/:id/transactions response matches PaginatedTransactionDto schema')
  it('POST /workspaces/:id/transactions response matches TransactionDto schema')
  
  // Budgets
  it('GET /workspaces/:id/budgets response matches BudgetDto[] schema')
  
  // Reports
  it('GET /workspaces/:id/reports/monthly-summary matches MonthlySummaryDto schema')
  it('GET /workspaces/:id/reports/category-breakdown matches CategoryBreakdownDto[]')
  
  // Notifications
  it('GET /notifications response matches NotificationDto[] schema')
});
```

Each assertion uses `ajv` to validate the response body against a JSON schema snapshot generated from `@nestjs/swagger` DTOs.

### 9.2 Flutter API Contract Test

**`test/core/api/api_contract_test.dart`:**

Every Freezed model `fromJson` must succeed with the exact shape the API sends. Test by round-tripping through a typed fixture that mirrors the actual API response:

```dart
test('TransactionDto fromJson accepts API response shape', () {
  final json = {
    'id': 'uuid',
    'amount': 5000,      // must be int
    'type': 'EXPENSE',
    'date': '2026-06-01T00:00:00.000Z',
    'description': 'Lunch',
    'categoryId': 'uuid',
    'createdByUserId': 'uuid',
    'createdAt': '2026-06-01T00:00:00.000Z',
  };
  expect(() => Transaction.fromJson(json), returnsNormally);
  expect(Transaction.fromJson(json).amount, isA<int>());  // never double
});
```

---

## 10. Code Review Checklist

Every PR must pass this checklist before merge. Reviewer verifies each item.

### Security

- [ ] No secrets or API keys hardcoded anywhere in diff
- [ ] No raw SQL string interpolation (only Prisma `$queryRaw` tagged templates)
- [ ] `WorkspaceMemberGuard` applied to every new workspace-scoped route
- [ ] User input at API boundaries validated by a DTO with class-validator decorators
- [ ] CSV export sanitises values (no leading `= + - @`)
- [ ] No XSS risk in any Flutter widget rendering user-supplied strings
- [ ] JWT expiry not extended without product sign-off

### Money Handling

- [ ] All DB columns storing money are `Int` (Prisma) / `INTEGER` (SQL) — never `Float` or `Decimal`
- [ ] All service-layer computations on money use integer arithmetic
- [ ] No division that could produce floats stored back to DB
- [ ] Display formatting (÷100, locale string) happens only at the UI layer
- [ ] Test amounts are integers in all new test cases

### Architecture

- [ ] New NestJS module owns its own routes, service, and Prisma calls — no cross-module Prisma access
- [ ] No `@Skip(WorkspaceMemberGuard)` or equivalent bypass added
- [ ] `reports` module still uses raw SQL via `$queryRaw` (not ORM queries)
- [ ] BullMQ job processors do not have direct HTTP calls — they emit events or call services
- [ ] Flutter providers use `AsyncNotifierProvider` (not `StateNotifierProvider`)
- [ ] No new `ChangeNotifier` or `setState` in screens that should use Riverpod

### Code Quality

- [ ] `flutter analyze --no-fatal-infos` exits 0 on the Flutter diff
- [ ] `npm run test` passes on the API diff (no failing unit tests)
- [ ] No `console.log` / `print()` left in production code paths
- [ ] No `TODO` comments merged to main without a linked issue
- [ ] Dart linting: no `unnecessary_non_null_assertion` or `dead_code` warnings
- [ ] No test using `// ignore:` suppressions without explanation

### Testing

- [ ] Every new API endpoint has at least one E2E test (happy path + 401/403)
- [ ] Every new widget has at least one widget test (smoke: renders without error)
- [ ] `WorkspaceMemberGuard` is tested with a non-member token for every new route
- [ ] If the change touches token handling, the refresh flow test is updated

### Documentation / CLAUDE.md

- [ ] `CLAUDE.md` updated if new modules, routes, or critical conventions added
- [ ] Environment variables listed in Section 8 of the design spec if new vars introduced
- [ ] DB schema changes have a Prisma migration file (no direct `ALTER TABLE`)

---

## 11. QA Workflow

### Definition of Done (per feature)

A feature is shippable when ALL of the following are true:

1. **Unit tests pass:** `npm run test` and `flutter test` both exit 0
2. **E2E API tests pass:** `npm run test:e2e` exits 0 (requires `docker compose up -d`)
3. **Flutter analyze passes:** `flutter analyze --no-fatal-infos` exits 0
4. **Code review approved:** reviewer has signed off every checklist item
5. **QA sign-off:** QA has verified the feature manually against acceptance criteria
6. **No regressions:** CI pipeline is green on the PR branch

### Manual QA Acceptance Criteria

For each feature area, QA must verify the following flows manually in a browser and on a mobile device (or emulator):

#### Auth

| # | Scenario | Expected |
|---|---|---|
| A1 | Register with valid data | Redirected to dashboard |
| A2 | Register with existing email | Error message shown, no redirect |
| A3 | Login with correct credentials | Dashboard shown with correct workspace |
| A4 | Login with wrong password | Error message shown |
| A5 | Refresh page while logged in | Still on dashboard (session restored) |
| A6 | Click logout | Login screen shown |
| A7 | Refresh page after logout | Login screen shown (no session) |
| A8 | Forgot password flow | Email received, reset link works |

#### Workspaces

| # | Scenario | Expected |
|---|---|---|
| W1 | First login shows empty state CTA | "Create Workspace" button visible |
| W2 | Create workspace | Name appears in sidebar, categories seeded |
| W3 | Create second workspace | Switcher allows toggling between both |
| W4 | Invite a user via email | User receives invite, can accept, sees workspace |
| W5 | Non-member tries to access workspace URL directly | 403 / redirect |

#### Transactions

| # | Scenario | Expected |
|---|---|---|
| T1 | Add EXPENSE of $12.50 | Stored as 1250 cents, displayed as "$12.50" |
| T2 | Add INCOME of $3,000 | Stored as 300000 cents, displayed as "$3,000.00" |
| T3 | Hero card net balance updates after add | Net balance reflects new transaction |
| T4 | Filter transactions by category | Only matching transactions shown |
| T5 | Edit transaction amount | List and dashboard reflect new amount |
| T6 | Delete transaction | Removed from list, dashboard updated |
| T7 | Add transaction from dashboard FAB | Sheet opens, categories populated |

#### Budgets

| # | Scenario | Expected |
|---|---|---|
| B1 | Create $100/month budget | Progress bar shows 0%, green |
| B2 | Spend $80 of $100 budget | Progress bar shows 80%, amber |
| B3 | Spend $100+ of $100 budget | Progress bar shows ≥100%, red |
| B4 | Budget alert notification | In-app notification received at 80% and 100% |
| B5 | Delete budget | Removed from list |

#### Recurring Transactions

| # | Scenario | Expected |
|---|---|---|
| R1 | Create monthly recurring rule | Rule appears in list with next_run_at |
| R2 | Pause rule | Rule shows paused state |
| R3 | Delete rule | Rule removed from list |

#### Reports

| # | Scenario | Expected |
|---|---|---|
| RP1 | Monthly summary for current month | Correct income/expense/net shown |
| RP2 | Category breakdown | Correct percentages, adds to ~100% |
| RP3 | Export CSV | File downloads, columns correct, amounts as decimals |
| RP4 | Switch to previous month | Data changes to reflect that month |

#### Notifications

| # | Scenario | Expected |
|---|---|---|
| N1 | Budget alert triggers in-app notification | Bell badge appears, notification in list |
| N2 | Mark single notification as read | Badge count decreases |
| N3 | Mark all as read | Badge disappears |

### Regression Checklist (run before every release)

- [ ] A1–A8 Auth flows
- [ ] W1, W2 Workspace creation
- [ ] T1, T2, T3 Transaction create + hero card
- [ ] B1, B3 Budget progress thresholds
- [ ] RP3 CSV export (formula injection check)
- [ ] All amounts display correctly with correct currency symbol

---

## 12. CI/CD Pipeline

The pipeline is defined in `.github/workflows/`. Required jobs:

### 12.1 `api-ci.yml` (trigger: push to `main`, PRs)

```yaml
jobs:
  unit-test:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - node setup (v20)
      - npm ci (in apps/api/)
      - npm run test -- --coverage
      - upload coverage to Codecov

  e2e-test:
    runs-on: ubuntu-latest
    services:
      postgres: image postgres:16-alpine, env POSTGRES_DB/USER/PASSWORD
      redis: image redis:7-alpine
    steps:
      - checkout
      - node setup
      - npm ci
      - npx prisma migrate deploy
      - npm run test:e2e
    needs: [unit-test]

  build:
    runs-on: ubuntu-latest
    steps:
      - npm run build
    needs: [e2e-test]
```

### 12.2 `flutter-ci.yml` (trigger: push to `main`, PRs)

```yaml
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - flutter setup (channel stable, version pin)
      - flutter pub get (in apps/mobile/)
      - flutter analyze --no-fatal-infos --fatal-warnings

  unit-widget-test:
    runs-on: ubuntu-latest
    steps:
      - flutter test --coverage
      - upload coverage to Codecov
    needs: [analyze]

  integration-test:
    runs-on: ubuntu-latest
    services: [postgres, redis]
    steps:
      - npx prisma migrate deploy
      - start NestJS API (background)
      - flutter test integration_test/ -d chrome
    needs: [unit-widget-test]
```

### 12.3 `e2e-playwright.yml` (trigger: push to `main` only)

```yaml
jobs:
  playwright:
    runs-on: ubuntu-latest
    services: [postgres, redis]
    steps:
      - start NestJS API
      - flutter build web
      - serve Flutter web on port 3001
      - npx playwright install --with-deps
      - npx playwright test
      - upload playwright report as artifact
```

### 12.4 Required Status Checks (branch protection on `main`)

All of the following must pass before merge:
- `api-ci / unit-test`
- `api-ci / e2e-test`
- `api-ci / build`
- `flutter-ci / analyze`
- `flutter-ci / unit-widget-test`
- At least 1 PR review approval

---

## 13. Implementation Priority Order

Implement in this order to unblock QA the fastest:

### Phase 1 — Fill E2E API gaps (backend confidence)

1. `test/budgets.e2e-spec.ts`
2. `test/transactions.e2e-spec.ts` (standalone, with full CRUD)
3. `test/categories.e2e-spec.ts`
4. `test/recurring.e2e-spec.ts`
5. `test/reports.e2e-spec.ts`
6. `test/notifications.e2e-spec.ts`
7. Augment `test/auth.e2e-spec.ts` (add `/auth/me`, token rotation)
8. Augment `test/workspaces.e2e-spec.ts` (invite + member removal)

### Phase 2 — Flutter widget tests (UI confidence)

9. `test/features/auth/register_screen_test.dart`
10. `test/features/dashboard/dashboard_screen_test.dart`
11. `test/features/transactions/add_transaction_sheet_test.dart`
12. `test/core/router/app_router_test.dart`
13. Remaining screen tests (transactions list, budgets, workspaces, recurring, reports)

### Phase 3 — Augment unit tests

14. Audit and fill gaps in existing `.spec.ts` files (getMe, refresh rotation, invite, budget alert dedup)
15. Augment `auth_provider_test.dart` (session restore)
16. Augment `api_client_test.dart` (refresh fix verification)
17. `test/core/api/api_contract_test.dart` (model ↔ API shape)

### Phase 4 — Integration + E2E

18. `integration_test/auth_flow_test.dart`
19. `integration_test/workspace_flow_test.dart`
20. `integration_test/transaction_flow_test.dart`
21. `integration_test/budget_flow_test.dart`
22. `integration_test/token_refresh_test.dart`

### Phase 5 — Playwright + CI

23. `apps/e2e/` Playwright suite (auth → workspace → transaction → budget → reports)
24. `.github/workflows/api-ci.yml`
25. `.github/workflows/flutter-ci.yml`
26. `.github/workflows/e2e-playwright.yml`

---

*This document is the authoritative source for what "production ready" means for the Expense Tracker application. No feature ships until its relevant sections of this spec are implemented and green.*
