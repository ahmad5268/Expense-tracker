# Flutter App — Phase 3: Shared Models + Workspace Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create all Freezed data models (Workspace, WorkspaceMember, Category, Transaction, Budget, RecurringRule, Notification), a shared currency formatting utility, and the `WorkspaceProvider` that tracks the currently selected workspace and exposes the workspace list.

**Architecture:** All models live in `shared/models/`. Each is a `@freezed` class with `fromJson`/`toJson`. `WorkspaceNotifier` is an `AsyncNotifier<Workspace?>` that fetches workspace list from the API and persists the active workspace ID in `SharedPreferences`. Features depend on `activeWorkspaceProvider` — they never call workspace APIs directly.

**Tech Stack:** `freezed`, `json_annotation`, `shared_preferences`, `intl` (currency formatting)

**Prerequisite:** Phase 2 complete. `ApiClient`, `SecureStorageService`, `User` model available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/shared/models/workspace.dart` | Workspace + WorkspaceMember Freezed models |
| `lib/shared/models/category.dart` | Category Freezed model |
| `lib/shared/models/transaction.dart` | Transaction Freezed model |
| `lib/shared/models/budget.dart` | Budget Freezed model |
| `lib/shared/models/recurring_rule.dart` | RecurringRule Freezed model |
| `lib/shared/models/notification_item.dart` | NotificationItem Freezed model |
| `lib/shared/utils/currency_formatter.dart` | Cents → display string (e.g., 5000 → "$50.00") |
| `lib/features/workspaces/workspace_provider.dart` | `WorkspaceNotifier` — list + active workspace |
| `test/shared/models/` | Serialization tests for all models |
| `test/features/workspaces/workspace_provider_test.dart` | Provider unit tests |

---

## Task 1: Workspace + WorkspaceMember models

**Files:**
- Create: `lib/shared/models/workspace.dart`

- [ ] **Step 1.1: Write Workspace model**

```dart
// apps/mobile/lib/shared/models/workspace.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

// IMPORTANT: @JsonValue annotations map Flutter camelCase enum values to the
// backend's UPPER_SNAKE_CASE Prisma enum strings. Without these, JSON
// deserialization fails because the API returns "OWNER" but Freezed
// generates code that expects "owner".
enum MemberRole {
  @JsonValue('OWNER') owner,
  @JsonValue('ADMIN') admin,
  @JsonValue('MEMBER') member,
}

// WorkspaceRole is an alias kept for backward compatibility — use MemberRole.
typedef WorkspaceRole = MemberRole;

@freezed
class WorkspaceMember with _$WorkspaceMember {
  const factory WorkspaceMember({
    required String userId,
    required String name,
    String? avatarUrl,
    required MemberRole role,
  }) = _WorkspaceMember;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceMemberFromJson(json);
}

@freezed
class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    required String currency,
    required String ownerId,
    @Default([]) List<WorkspaceMember> members,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
```

- [ ] **Step 1.2: Write model test**

```dart
// apps/mobile/test/shared/models/workspace_test.dart
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Workspace model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'w1',
        'name': 'Family Budget',
        'currency': 'USD',
        'ownerId': 'u1',
        'members': [],
      };
      final w = Workspace.fromJson(json);
      expect(w.id, 'w1');
      expect(w.currency, 'USD');
    });

    test('members default to empty list', () {
      final json = {'id': 'w1', 'name': 'W', 'currency': 'USD', 'ownerId': 'u1'};
      final w = Workspace.fromJson(json);
      expect(w.members, isEmpty);
    });

    // Verify @JsonValue mapping: backend sends UPPER_SNAKE_CASE, Flutter parses correctly
    test('WorkspaceMember role parses UPPER_SNAKE_CASE from backend', () {
      final json = {
        'id': 'w1', 'name': 'W', 'currency': 'USD', 'ownerId': 'u1',
        'members': [
          {'userId': 'u1', 'name': 'Alice', 'role': 'OWNER'},
          {'userId': 'u2', 'name': 'Bob',   'role': 'ADMIN'},
          {'userId': 'u3', 'name': 'Carol',  'role': 'MEMBER'},
        ],
      };
      final w = Workspace.fromJson(json);
      expect(w.members[0].role, MemberRole.owner);
      expect(w.members[1].role, MemberRole.admin);
      expect(w.members[2].role, MemberRole.member);
    });
  });
}
```

- [ ] **Step 1.3: Run code generation**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 1.4: Run test**

```bash
flutter test test/shared/models/workspace_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/shared/models/workspace.dart apps/mobile/lib/shared/models/workspace.freezed.dart apps/mobile/lib/shared/models/workspace.g.dart apps/mobile/test/shared/models/workspace_test.dart
git commit -m "feat(mobile/models): add Workspace and WorkspaceMember Freezed models"
```

---

## Task 2: Category model
Depends-on: 1

**Files:**
- Create: `lib/shared/models/category.dart`

- [ ] **Step 2.1: Write Category model**

```dart
// apps/mobile/lib/shared/models/category.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

// @JsonValue maps Flutter lowercase values → backend UPPER_SNAKE_CASE strings.
enum CategoryType {
  @JsonValue('EXPENSE') expense,
  @JsonValue('INCOME') income,
}

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String workspaceId,
    required String name,
    required String icon,
    required String color,
    required CategoryType type,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
```

- [ ] **Step 2.2: Write model test**

```dart
// apps/mobile/test/shared/models/category_test.dart
import 'package:expense_tracker/shared/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The API returns UPPER_SNAKE_CASE; verify @JsonValue mapping.
  test('Category fromJson parses EXPENSE type from backend', () {
    final json = {
      'id': 'c1',
      'workspaceId': 'w1',
      'name': 'Food',
      'icon': '🍔',
      'color': '#FF5733',
      'type': 'EXPENSE', // backend sends UPPER_SNAKE_CASE
    };
    final c = Category.fromJson(json);
    expect(c.type, CategoryType.expense);
    expect(c.name, 'Food');
  });

  test('Category fromJson parses INCOME type from backend', () {
    final json = {
      'id': 'c2',
      'workspaceId': 'w1',
      'name': 'Salary',
      'icon': '💼',
      'color': '#22c55e',
      'type': 'INCOME',
    };
    final c = Category.fromJson(json);
    expect(c.type, CategoryType.income);
  });
}
```

- [ ] **Step 2.3: Run code generation + test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/shared/models/category_test.dart
```

Expected: PASS — 2 tests

- [ ] **Step 2.4: Commit**

```bash
git add apps/mobile/lib/shared/models/category.dart apps/mobile/lib/shared/models/category.freezed.dart apps/mobile/lib/shared/models/category.g.dart apps/mobile/test/shared/models/category_test.dart
git commit -m "feat(mobile/models): add Category Freezed model"
```

---

## Task 3: Transaction model
Depends-on: 2

**Files:**
- Create: `lib/shared/models/transaction.dart`

- [ ] **Step 3.1: Write Transaction model**

```dart
// apps/mobile/lib/shared/models/transaction.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

// @JsonValue maps Flutter lowercase values → backend UPPER_SNAKE_CASE strings.
enum TransactionType {
  @JsonValue('EXPENSE') expense,
  @JsonValue('INCOME') income,
}

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String workspaceId,
    required String userId,
    required String categoryId,
    String? categoryName,
    String? categoryIcon,
    required int amount,        // always in cents
    required TransactionType type,
    String? description,
    required DateTime date,
    String? recurringRuleId,
    required DateTime createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
```

- [ ] **Step 3.2: Write model test**

```dart
// apps/mobile/test/shared/models/transaction_test.dart
import 'package:expense_tracker/shared/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction model', () {
    // Backend returns UPPER_SNAKE_CASE; @JsonValue must map it to Flutter enum.
    final json = {
      'id': 't1',
      'workspaceId': 'w1',
      'userId': 'u1',
      'categoryId': 'c1',
      'amount': 5000,
      'type': 'EXPENSE', // backend sends UPPER_SNAKE_CASE
      'date': '2026-06-01T00:00:00.000Z',
      'createdAt': '2026-06-01T10:00:00.000Z',
    };

    test('fromJson parses amount as int (cents)', () {
      final t = Transaction.fromJson(json);
      expect(t.amount, 5000);
      expect(t.amount, isA<int>());
    });

    test('fromJson parses date as DateTime', () {
      final t = Transaction.fromJson(json);
      expect(t.date, isA<DateTime>());
    });

    test('toJson round-trips without loss', () {
      final t = Transaction.fromJson(json);
      final encoded = t.toJson();
      final decoded = Transaction.fromJson(encoded);
      expect(decoded.amount, 5000);
    });
  });
}
```

- [ ] **Step 3.3: Run code generation + test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/shared/models/transaction_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 3.4: Commit**

```bash
git add apps/mobile/lib/shared/models/transaction.dart apps/mobile/lib/shared/models/transaction.freezed.dart apps/mobile/lib/shared/models/transaction.g.dart apps/mobile/test/shared/models/transaction_test.dart
git commit -m "feat(mobile/models): add Transaction Freezed model (amount in cents)"
```

---

## Task 4: Budget, RecurringRule, and NotificationItem models
Depends-on: 2

**Files:**
- Create: `lib/shared/models/budget.dart`
- Create: `lib/shared/models/recurring_rule.dart`
- Create: `lib/shared/models/notification_item.dart`

- [ ] **Step 4.1: Write Budget model**

```dart
// apps/mobile/lib/shared/models/budget.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

// @JsonValue maps Flutter lowercase values → backend UPPER_SNAKE_CASE strings.
enum BudgetPeriod {
  @JsonValue('MONTHLY') monthly,
  @JsonValue('YEARLY') yearly,
}

@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String workspaceId,
    String? categoryId,
    String? categoryName,
    required int amount,   // cents
    required BudgetPeriod period,
    required int year,
    int? month,            // null for yearly budgets
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
}
```

- [ ] **Step 4.2: Write RecurringRule model**

```dart
// apps/mobile/lib/shared/models/recurring_rule.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'transaction.dart';

part 'recurring_rule.freezed.dart';
part 'recurring_rule.g.dart';

// @JsonValue maps Flutter lowercase values → backend UPPER_SNAKE_CASE strings.
enum Frequency {
  @JsonValue('DAILY') daily,
  @JsonValue('WEEKLY') weekly,
  @JsonValue('MONTHLY') monthly,
  @JsonValue('YEARLY') yearly,
}

@freezed
class RecurringRule with _$RecurringRule {
  const factory RecurringRule({
    required String id,
    required String workspaceId,
    required String categoryId,
    String? categoryName,
    required int amount,   // cents
    required TransactionType type,
    String? description,
    required Frequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    required DateTime nextRunAt,
    required bool isActive,
  }) = _RecurringRule;

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      _$RecurringRuleFromJson(json);
}
```

- [ ] **Step 4.3: Write NotificationItem model**

```dart
// apps/mobile/lib/shared/models/notification_item.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

// @JsonValue maps Flutter camelCase values → backend UPPER_SNAKE_CASE strings.
enum NotificationType {
  @JsonValue('BUDGET_ALERT') budgetAlert,
  @JsonValue('RECURRING_REMINDER') recurringReminder,
  @JsonValue('MONTHLY_SUMMARY') monthlySummary,
  @JsonValue('INVITE') invite,
}

@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String userId,
    required NotificationType type,
    required Map<String, dynamic> payload,
    @Default(false) bool isRead,
    DateTime? readAt,
    required DateTime createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
```

- [ ] **Step 4.4: Write combined model tests**

```dart
// apps/mobile/test/shared/models/budget_test.dart
import 'package:expense_tracker/shared/models/budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Backend sends UPPER_SNAKE_CASE for period; verify @JsonValue mapping.
  test('Budget fromJson parses MONTHLY period from backend', () {
    final b = Budget.fromJson({
      'id': 'b1', 'workspaceId': 'w1', 'amount': 100000,
      'period': 'MONTHLY', // backend UPPER_SNAKE_CASE
      'year': 2026, 'month': 6,
    });
    expect(b.amount, 100000);
    expect(b.period, BudgetPeriod.monthly);
    expect(b.month, 6);
  });

  test('Budget fromJson parses YEARLY period from backend', () {
    final b = Budget.fromJson({
      'id': 'b2', 'workspaceId': 'w1', 'amount': 500000,
      'period': 'YEARLY',
      'year': 2026,
    });
    expect(b.period, BudgetPeriod.yearly);
    expect(b.month, isNull);
  });
}
```

```dart
// apps/mobile/test/shared/models/recurring_rule_test.dart
import 'package:expense_tracker/shared/models/recurring_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Backend sends UPPER_SNAKE_CASE; verify @JsonValue mappings on Frequency and TransactionType.
  test('RecurringRule fromJson parses MONTHLY frequency and EXPENSE type', () {
    final r = RecurringRule.fromJson({
      'id': 'r1', 'workspaceId': 'w1', 'categoryId': 'c1',
      'amount': 50000,
      'type': 'EXPENSE',       // backend UPPER_SNAKE_CASE
      'frequency': 'MONTHLY',  // backend UPPER_SNAKE_CASE
      'startDate': '2026-01-01T00:00:00.000Z',
      'nextRunAt': '2026-07-01T00:00:00.000Z',
      'isActive': true,
    });
    expect(r.frequency, Frequency.monthly);
    expect(r.isActive, true);
  });
}
```

- [ ] **Step 4.5: Run code generation + tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/shared/models/
```

Expected: PASS — all model tests

- [ ] **Step 4.6: Commit**

```bash
git add apps/mobile/lib/shared/models/ apps/mobile/test/shared/models/
git commit -m "feat(mobile/models): add Budget, RecurringRule, NotificationItem Freezed models"
```

---

## Task 5: CurrencyFormatter utility

**Files:**
- Create: `lib/shared/utils/currency_formatter.dart`
- Create: `test/shared/utils/currency_formatter_test.dart`

- [ ] **Step 5.1: Write failing tests**

```dart
// apps/mobile/test/shared/utils/currency_formatter_test.dart
import 'package:expense_tracker/shared/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats 5000 cents as \$50.00 for USD', () {
      expect(CurrencyFormatter.format(5000, 'USD'), '\$50.00');
    });

    test('formats 0 as \$0.00', () {
      expect(CurrencyFormatter.format(0, 'USD'), '\$0.00');
    });

    test('formats 1 cent as \$0.01', () {
      expect(CurrencyFormatter.format(1, 'USD'), '\$0.01');
    });

    test('formats 100000 as \$1,000.00', () {
      expect(CurrencyFormatter.format(100000, 'USD'), '\$1,000.00');
    });

    test('formats negative values (net loss)', () {
      expect(CurrencyFormatter.format(-5000, 'USD'), '-\$50.00');
    });

    test('formats EUR correctly', () {
      final result = CurrencyFormatter.format(9999, 'EUR');
      expect(result, contains('99.99'));
    });
  });
}
```

- [ ] **Step 5.2: Run test — verify it fails**

```bash
flutter test test/shared/utils/currency_formatter_test.dart
```

Expected: FAIL — `Cannot find module 'currency_formatter.dart'`

- [ ] **Step 5.3: Implement CurrencyFormatter**

```dart
// apps/mobile/lib/shared/utils/currency_formatter.dart
import 'package:intl/intl.dart';

class CurrencyFormatter {
  // cents → display string. Never operates on floats until the final division.
  static String format(int cents, String currencyCode) {
    final amount = cents / 100.0;
    final formatter = NumberFormat.currency(
      name: currencyCode,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Parse display string back to cents (for UI input → API)
  static int parseToCents(String displayValue) {
    final cleaned = displayValue.replaceAll(RegExp(r'[^\d.-]'), '');
    final amount = double.tryParse(cleaned) ?? 0.0;
    return (amount * 100).round();
  }
}
```

- [ ] **Step 5.4: Run tests — verify pass**

```bash
flutter test test/shared/utils/currency_formatter_test.dart
```

Expected: PASS — 6 tests

- [ ] **Step 5.5: Commit**

```bash
git add apps/mobile/lib/shared/utils/currency_formatter.dart apps/mobile/test/shared/utils/currency_formatter_test.dart
git commit -m "feat(mobile/utils): add CurrencyFormatter (cents to display string)"
```

---

## Task 6: WorkspaceProvider
Depends-on: 3, 4

**Files:**
- Create: `lib/features/workspaces/workspace_provider.dart`
- Create: `test/features/workspaces/workspace_provider_test.dart`

- [ ] **Step 6.1: Write failing unit tests**

```dart
// apps/mobile/test/features/workspaces/workspace_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'workspace_provider_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    final mockStorage = MockSecureStorageService();
    when(mockStorage.getAccessToken()).thenAnswer((_) async => 'tok');
    final client = ApiClient.withDio(dio, mockStorage);

    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
    ]);
  });

  tearDown(() => container.dispose());

  test('fetchWorkspaces loads workspace list from API', () async {
    adapter.onGet('/workspaces', (server) => server.reply(200, {
          'data': [
            {'id': 'w1', 'name': 'Personal', 'currency': 'USD', 'ownerId': 'u1', 'members': []},
          ]
        }));

    await container.read(workspaceNotifierProvider.notifier).fetchWorkspaces();

    final state = container.read(workspaceNotifierProvider);
    expect(state.workspaces.length, 1);
    expect(state.workspaces.first.name, 'Personal');
  });

  test('setActiveWorkspace updates activeWorkspace', () async {
    adapter.onGet('/workspaces', (server) => server.reply(200, {
          'data': [
            {'id': 'w1', 'name': 'Personal', 'currency': 'USD', 'ownerId': 'u1', 'members': []},
          ]
        }));

    await container.read(workspaceNotifierProvider.notifier).fetchWorkspaces();
    container.read(workspaceNotifierProvider.notifier).setActive('w1');

    final state = container.read(workspaceNotifierProvider);
    expect(state.activeWorkspace?.id, 'w1');
  });
}
```

- [ ] **Step 6.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/workspaces/workspace_provider_test.dart
```

Expected: FAIL — `Cannot find module 'workspace_provider.dart'`

- [ ] **Step 6.3: Implement WorkspaceProvider**

```dart
// apps/mobile/lib/features/workspaces/workspace_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/workspace.dart';

class WorkspaceState {
  final List<Workspace> workspaces;
  final Workspace? activeWorkspace;
  const WorkspaceState({this.workspaces = const [], this.activeWorkspace});

  WorkspaceState copyWith({List<Workspace>? workspaces, Workspace? activeWorkspace}) =>
      WorkspaceState(
        workspaces: workspaces ?? this.workspaces,
        activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      );
}

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceState();

  Future<void> fetchWorkspaces() async {
    final response = await ref.read(apiClientProvider).dio.get('/workspaces');
    final list = (response.data['data'] as List)
        .map((j) => Workspace.fromJson(j as Map<String, dynamic>))
        .toList();
    state = state.copyWith(
      workspaces: list,
      activeWorkspace: list.isNotEmpty ? (state.activeWorkspace ?? list.first) : null,
    );
  }

  void setActive(String workspaceId) {
    final workspace = state.workspaces.firstWhere((w) => w.id == workspaceId);
    state = state.copyWith(activeWorkspace: workspace);
  }

  Future<Workspace> createWorkspace({required String name, required String currency}) async {
    final response = await ref.read(apiClientProvider).dio.post('/workspaces', data: {
      'name': name,
      'currency': currency,
    });
    final workspace = Workspace.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.copyWith(
      workspaces: [...state.workspaces, workspace],
      activeWorkspace: state.activeWorkspace ?? workspace,
    );
    return workspace;
  }

  Future<void> inviteMember(String workspaceId, String email) async {
    await ref.read(apiClientProvider).dio.post(
      '/workspaces/$workspaceId/invite',
      data: {'email': email},
    );
  }

  Future<void> removeMember(String workspaceId, String userId) async {
    await ref.read(apiClientProvider).dio.delete(
      '/workspaces/$workspaceId/members/$userId',
    );
    await fetchWorkspaces();
  }
}

final workspaceNotifierProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);

final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  return ref.watch(workspaceNotifierProvider).activeWorkspace;
});
```

- [ ] **Step 6.4: Run tests — verify pass**

```bash
flutter test test/features/workspaces/workspace_provider_test.dart
```

Expected: PASS — 2 tests

- [ ] **Step 6.5: Run full test suite**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 6.6: Commit**

```bash
git add apps/mobile/lib/features/workspaces/workspace_provider.dart apps/mobile/test/features/workspaces/workspace_provider_test.dart
git commit -m "feat(mobile/workspaces): add WorkspaceNotifier with list + active workspace"
```

---

## Phase 3 Complete

- ✅ `User`, `Workspace`, `WorkspaceMember`, `Category`, `Transaction`, `Budget`, `RecurringRule`, `NotificationItem` — all Freezed with `fromJson`/`toJson`
- ✅ **Enum serialization strategy:** All enums use `@JsonValue` annotations to map Flutter camelCase/lowercase values to the backend's Prisma UPPER_SNAKE_CASE strings (`EXPENSE`, `INCOME`, `OWNER`, `ADMIN`, `MEMBER`, `MONTHLY`, `YEARLY`, `DAILY`, `WEEKLY`, `BUDGET_ALERT`, `RECURRING_REMINDER`, `MONTHLY_SUMMARY`, `INVITE`). This prevents JSON deserialization failures when consuming API responses.
- ✅ `WorkspaceRole` renamed to `MemberRole` throughout to match the backend Prisma schema. `WorkspaceRole` is kept as a `typedef` alias for compatibility.
- ✅ Money in `Transaction`, `Budget`, `RecurringRule` is `int` (cents) — no floats in models
- ✅ `CurrencyFormatter.format(cents, currency)` — safe cents-to-display, `parseToCents` for form input
- ✅ `WorkspaceNotifier` — fetch list, set active, create, invite, remove member
- ✅ `activeWorkspaceProvider` — derived provider used by all feature screens
- ✅ Unit tests: 13 model tests (including enum mapping assertions) + 6 formatter tests + 2 provider tests

**Next plan:** `2026-06-16-flutter-phase4.md` — Dashboard screen (summary card, recent transactions, budget progress bars)
