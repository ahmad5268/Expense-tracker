# Flutter App — Phase 7: Budgets + Recurring Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Budgets feature (list with progress bars, create/edit sheet) and the Recurring Rules feature (list, create/edit sheet). Both features are workspace-scoped and share the `BudgetProgressBar` widget from Phase 4.

**Architecture:** `BudgetsNotifier` and `RecurringNotifier` are independent `Notifier` classes that call the API and maintain their own lists. Budgets show actual spend by calling the budget-vs-actual report endpoint. `CreateEditBudgetSheet` and `CreateEditRecurringSheet` are modal bottom sheets that commit on save and close.

**Tech Stack:** `flutter_riverpod`, `dio`, `freezed`, `intl`

**Prerequisite:** Phase 5 complete. `AmountField`, `CategoryPicker`, `BudgetProgressBar` (Phase 4), `Budget`, `RecurringRule` models available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/features/budgets/budgets_provider.dart` | CRUD for budgets + actual spend |
| `lib/features/budgets/budgets_screen.dart` | Budget list with progress bars |
| `lib/features/budgets/create_edit_budget_sheet.dart` | Bottom sheet: amount, period, category |
| `lib/features/recurring/recurring_provider.dart` | CRUD for recurring rules |
| `lib/features/recurring/recurring_screen.dart` | Recurring rules list |
| `lib/features/recurring/create_edit_recurring_sheet.dart` | Bottom sheet: amount, frequency, dates |
| `lib/core/router/app_router.dart` | Updated with real budget/recurring screens |
| `test/features/budgets/budgets_provider_test.dart` | Unit tests |
| `test/features/recurring/recurring_provider_test.dart` | Unit tests |

---

## Task 1: BudgetsProvider

**Files:**
- Create: `lib/features/budgets/budgets_provider.dart`
- Create: `test/features/budgets/budgets_provider_test.dart`

- [ ] **Step 1.1: Write failing unit tests**

```dart
// apps/mobile/test/features/budgets/budgets_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/budgets/budgets_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'budgets_provider_test.mocks.dart';

const _workspace = Workspace(id: 'w1', name: 'P', currency: 'USD', ownerId: 'u1');

final _budgetJson = {
  'id': 'b1', 'workspaceId': 'w1', 'amount': 100000,
  'period': 'monthly', 'year': 2026, 'month': 6,
};

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
      activeWorkspaceProvider.overrideWithValue(_workspace),
    ]);
  });

  tearDown(() => container.dispose());

  test('fetchBudgets loads budgets from API', () async {
    adapter.onGet('/workspaces/w1/budgets',
        (server) => server.reply(200, {'data': [_budgetJson]}));

    await container.read(budgetsNotifierProvider.notifier).fetchBudgets();
    final state = container.read(budgetsNotifierProvider);
    expect(state.budgets.length, 1);
    expect(state.budgets.first.amount, 100000);
  });

  test('addBudget appends to list', () async {
    adapter
      ..onGet('/workspaces/w1/budgets',
          (server) => server.reply(200, {'data': []}))
      ..onPost('/workspaces/w1/budgets', (server) => server.reply(201, {
            'data': _budgetJson
          }));

    await container.read(budgetsNotifierProvider.notifier).fetchBudgets();
    await container.read(budgetsNotifierProvider.notifier).addBudget(
          amount: 100000,
          period: 'monthly',
          year: 2026,
          month: 6,
        );

    expect(container.read(budgetsNotifierProvider).budgets.length, 1);
  });

  test('deleteBudget removes from list', () async {
    adapter
      ..onGet('/workspaces/w1/budgets',
          (server) => server.reply(200, {'data': [_budgetJson]}))
      ..onDelete('/workspaces/w1/budgets/b1',
          (server) => server.reply(200, {'data': null}));

    await container.read(budgetsNotifierProvider.notifier).fetchBudgets();
    await container.read(budgetsNotifierProvider.notifier).deleteBudget('b1');

    expect(container.read(budgetsNotifierProvider).budgets, isEmpty);
  });
}
```

- [ ] **Step 1.2: Generate mocks and run to verify failure**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/budgets/budgets_provider_test.dart
```

Expected: FAIL — `Cannot find module 'budgets_provider.dart'`

- [ ] **Step 1.3: Implement BudgetsProvider**

```dart
// apps/mobile/lib/features/budgets/budgets_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/budget.dart';

class BudgetWithSpend {
  final Budget budget;
  final int actualSpent;
  const BudgetWithSpend({required this.budget, this.actualSpent = 0});
}

class BudgetsState {
  final List<Budget> budgets;
  final Map<String, int> actualSpend; // budgetId → cents spent
  final bool isLoading;

  const BudgetsState({
    this.budgets = const [],
    this.actualSpend = const {},
    this.isLoading = false,
  });

  BudgetsState copyWith({
    List<Budget>? budgets,
    Map<String, int>? actualSpend,
    bool? isLoading,
  }) =>
      BudgetsState(
        budgets: budgets ?? this.budgets,
        actualSpend: actualSpend ?? this.actualSpend,
        isLoading: isLoading ?? this.isLoading,
      );

  int spentFor(String budgetId) => actualSpend[budgetId] ?? 0;
}

class BudgetsNotifier extends Notifier<BudgetsState> {
  @override
  BudgetsState build() => const BudgetsState();

  Future<void> fetchBudgets() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;

    state = state.copyWith(isLoading: true);
    final now = DateTime.now();
    final client = ref.read(apiClientProvider);

    final results = await Future.wait([
      client.dio.get('/workspaces/${workspace.id}/budgets'),
      client.dio.get(
        '/workspaces/${workspace.id}/reports/budget-vs-actual',
        queryParameters: {'year': now.year, 'month': now.month},
      ),
    ]);

    final budgets = (results[0].data['data'] as List)
        .map((j) => Budget.fromJson(j as Map<String, dynamic>))
        .toList();

    final actual = <String, int>{};
    for (final row in results[1].data['data'] as List) {
      final m = row as Map<String, dynamic>;
      actual[m['budgetId'] as String] = m['actualAmount'] as int;
    }

    state = BudgetsState(
      budgets: budgets,
      actualSpend: actual,
      isLoading: false,
    );
  }

  Future<void> addBudget({
    required int amount,
    required String period,
    required int year,
    int? month,
    String? categoryId,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.post(
          '/workspaces/${workspace.id}/budgets',
          data: {
            'amount': amount,
            'period': period,
            'year': year,
            if (month != null) 'month': month,
            if (categoryId != null) 'categoryId': categoryId,
          },
        );
    final budget = Budget.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.copyWith(budgets: [...state.budgets, budget]);
  }

  Future<void> updateBudget(String id, {int? amount, String? categoryId}) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.put(
          '/workspaces/${workspace.id}/budgets/$id',
          data: {
            if (amount != null) 'amount': amount,
            if (categoryId != null) 'categoryId': categoryId,
          },
        );
    final updated = Budget.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.copyWith(
      budgets: state.budgets.map((b) => b.id == id ? updated : b).toList(),
    );
  }

  Future<void> deleteBudget(String id) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    await ref.read(apiClientProvider).dio.delete(
          '/workspaces/${workspace.id}/budgets/$id',
        );
    state = state.copyWith(
      budgets: state.budgets.where((b) => b.id != id).toList(),
    );
  }
}

final budgetsNotifierProvider =
    NotifierProvider<BudgetsNotifier, BudgetsState>(BudgetsNotifier.new);
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/features/budgets/budgets_provider_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/features/budgets/budgets_provider.dart apps/mobile/test/features/budgets/budgets_provider_test.dart
git commit -m "feat(mobile/budgets): add BudgetsNotifier with actual spend from reports"
```

---

## Task 2: BudgetsScreen + CreateEditBudgetSheet
Depends-on: 1

**Files:**
- Create: `lib/features/budgets/budgets_screen.dart`
- Create: `lib/features/budgets/create_edit_budget_sheet.dart`

- [ ] **Step 2.1: Implement BudgetsScreen**

```dart
// apps/mobile/lib/features/budgets/budgets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../features/dashboard/widgets/budget_progress_bar.dart';
import 'budgets_provider.dart';
import 'create_edit_budget_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(budgetsNotifierProvider.notifier).fetchBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetsNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.budgets.isEmpty
              ? const Center(child: Text('No budgets yet. Tap + to add one.'))
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(budgetsNotifierProvider.notifier).fetchBudgets(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.budgets.length,
                    itemBuilder: (context, index) {
                      final budget = state.budgets[index];
                      final spent = state.spentFor(budget.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    budget.categoryName ?? 'Total Budget',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            CreateEditBudgetSheet.show(
                                                context, budget: budget),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => ref
                                            .read(budgetsNotifierProvider.notifier)
                                            .deleteBudget(budget.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              BudgetProgressBar(
                                label: budget.period.name,
                                spent: spent,
                                limit: budget.amount,
                                currency: currency,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateEditBudgetSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Budget'),
      ),
    );
  }
}
```

- [ ] **Step 2.2: Implement CreateEditBudgetSheet**

```dart
// apps/mobile/lib/features/budgets/create_edit_budget_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/budget.dart';
import '../../shared/widgets/amount_field.dart';
import 'budgets_provider.dart';

class CreateEditBudgetSheet extends ConsumerStatefulWidget {
  final Budget? budget;
  const CreateEditBudgetSheet({super.key, this.budget});

  static Future<void> show(BuildContext context, {Budget? budget}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CreateEditBudgetSheet(budget: budget),
      );

  @override
  ConsumerState<CreateEditBudgetSheet> createState() =>
      _CreateEditBudgetSheetState();
}

class _CreateEditBudgetSheetState extends ConsumerState<CreateEditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _amountCents;
  late String _period;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCents = widget.budget?.amount ?? 0;
    _period = widget.budget?.period.name ?? 'monthly';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final now = DateTime.now();
    try {
      if (widget.budget != null) {
        await ref.read(budgetsNotifierProvider.notifier).updateBudget(
              widget.budget!.id,
              amount: _amountCents,
            );
      } else {
        await ref.read(budgetsNotifierProvider.notifier).addBudget(
              amount: _amountCents,
              period: _period,
              year: now.year,
              month: _period == 'monthly' ? now.month : null,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save budget')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEditing ? 'Edit Budget' : 'New Budget',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (!isEditing)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'yearly', label: Text('Yearly')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            const SizedBox(height: 16),
            AmountField(
              initialCents: _amountCents,
              onChanged: (v) => _amountCents = v,
              currency: 'USD',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? 'Update Budget' : 'Create Budget'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.3: Update GoRouter**

In `lib/core/router/app_router.dart`:
```dart
import '../../features/budgets/budgets_screen.dart';

// Replace placeholder:
GoRoute(path: AppRoutes.budgets, builder: (_, __) => const BudgetsScreen()),
```

- [ ] **Step 2.4: Commit**

```bash
git add apps/mobile/lib/features/budgets/
git commit -m "feat(mobile/budgets): add BudgetsScreen and CreateEditBudgetSheet"
```

---

## Task 3: RecurringProvider

**Files:**
- Create: `lib/features/recurring/recurring_provider.dart`
- Create: `test/features/recurring/recurring_provider_test.dart`

- [ ] **Step 3.1: Write failing unit tests**

```dart
// apps/mobile/test/features/recurring/recurring_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/recurring/recurring_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'recurring_provider_test.mocks.dart';

const _workspace = Workspace(id: 'w1', name: 'P', currency: 'USD', ownerId: 'u1');

final _ruleJson = {
  'id': 'r1', 'workspaceId': 'w1', 'categoryId': 'c1',
  'amount': 50000, 'type': 'expense', 'frequency': 'monthly',
  'startDate': '2026-01-01T00:00:00.000Z',
  'nextRunAt': '2026-07-01T00:00:00.000Z', 'isActive': true,
};

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
      activeWorkspaceProvider.overrideWithValue(_workspace),
    ]);
  });

  tearDown(() => container.dispose());

  test('fetchRules loads recurring rules from API', () async {
    adapter.onGet('/workspaces/w1/recurring',
        (server) => server.reply(200, {'data': [_ruleJson]}));

    await container.read(recurringNotifierProvider.notifier).fetchRules();
    expect(container.read(recurringNotifierProvider).length, 1);
  });

  test('deleteRule removes from list', () async {
    adapter
      ..onGet('/workspaces/w1/recurring',
          (server) => server.reply(200, {'data': [_ruleJson]}))
      ..onDelete('/workspaces/w1/recurring/r1',
          (server) => server.reply(200, {'data': null}));

    await container.read(recurringNotifierProvider.notifier).fetchRules();
    await container.read(recurringNotifierProvider.notifier).deleteRule('r1');

    expect(container.read(recurringNotifierProvider), isEmpty);
  });
}
```

- [ ] **Step 3.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/recurring/recurring_provider_test.dart
```

Expected: FAIL — `Cannot find module 'recurring_provider.dart'`

- [ ] **Step 3.3: Implement RecurringProvider**

```dart
// apps/mobile/lib/features/recurring/recurring_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/recurring_rule.dart';

class RecurringNotifier extends Notifier<List<RecurringRule>> {
  @override
  List<RecurringRule> build() => [];

  Future<void> fetchRules() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/workspaces/${workspace.id}/recurring');
    state = (response.data['data'] as List)
        .map((j) => RecurringRule.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRule({
    required String categoryId,
    required int amount,
    required String type,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.post(
          '/workspaces/${workspace.id}/recurring',
          data: {
            'categoryId': categoryId,
            'amount': amount,
            'type': type,
            'frequency': frequency,
            'startDate': startDate.toIso8601String(),
            if (endDate != null) 'endDate': endDate.toIso8601String(),
            if (description != null) 'description': description,
          },
        );
    final rule = RecurringRule.fromJson(response.data['data'] as Map<String, dynamic>);
    state = [rule, ...state];
  }

  Future<void> updateRule(String id, {bool? isActive, DateTime? endDate}) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.put(
          '/workspaces/${workspace.id}/recurring/$id',
          data: {
            if (isActive != null) 'isActive': isActive,
            if (endDate != null) 'endDate': endDate.toIso8601String(),
          },
        );
    final updated = RecurringRule.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.map((r) => r.id == id ? updated : r).toList();
  }

  Future<void> deleteRule(String id) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    await ref.read(apiClientProvider).dio.delete(
          '/workspaces/${workspace.id}/recurring/$id',
        );
    state = state.where((r) => r.id != id).toList();
  }
}

final recurringNotifierProvider =
    NotifierProvider<RecurringNotifier, List<RecurringRule>>(RecurringNotifier.new);
```

- [ ] **Step 3.4: Run tests — verify pass**

```bash
flutter test test/features/recurring/recurring_provider_test.dart
```

Expected: PASS — 2 tests

- [ ] **Step 3.5: Commit**

```bash
git add apps/mobile/lib/features/recurring/recurring_provider.dart apps/mobile/test/features/recurring/recurring_provider_test.dart
git commit -m "feat(mobile/recurring): add RecurringNotifier with CRUD"
```

---

## Task 4: RecurringScreen + CreateEditRecurringSheet
Depends-on: 3

**Files:**
- Create: `lib/features/recurring/recurring_screen.dart`
- Create: `lib/features/recurring/create_edit_recurring_sheet.dart`

- [ ] **Step 4.1: Implement RecurringScreen**

```dart
// apps/mobile/lib/features/recurring/recurring_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/utils/currency_formatter.dart';
import 'recurring_provider.dart';
import 'create_edit_recurring_sheet.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringNotifierProvider.notifier).fetchRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(recurringNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: rules.isEmpty
          ? const Center(child: Text('No recurring rules yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rule.isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      Icons.repeat,
                      color: rule.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(rule.categoryName ?? 'Unknown Category'),
                  subtitle: Text(
                    '${rule.frequency.name} · Next: ${DateFormat.MMMd().format(rule.nextRunAt)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(rule.amount, currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rule.type.name == 'expense'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'toggle') {
                            await ref
                                .read(recurringNotifierProvider.notifier)
                                .updateRule(rule.id, isActive: !rule.isActive);
                          } else if (action == 'delete') {
                            await ref
                                .read(recurringNotifierProvider.notifier)
                                .deleteRule(rule.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(rule.isActive ? 'Pause' : 'Resume'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => CreateEditRecurringSheet.show(context, rule: rule),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateEditRecurringSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }
}
```

- [ ] **Step 4.2: Add `categoriesProvider` (shared FutureProvider)**

Both `AddTransactionSheet` (Phase 5) and `CreateEditRecurringSheet` need to load the category list. Add this shared provider if it does not already exist in Phase 5's files:

```dart
// apps/mobile/lib/features/categories/categories_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/category.dart';

/// Simple FutureProvider that fetches GET /workspaces/:id/categories.
/// Used by AddTransactionSheet (Phase 5) and CreateEditRecurringSheet (Phase 7).
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return [];
  final response = await ref
      .read(apiClientProvider)
      .dio
      .get('/workspaces/${workspace.id}/categories');
  return (response.data['data'] as List)
      .map((j) => Category.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 4.3: Implement CreateEditRecurringSheet**

```dart
// apps/mobile/lib/features/recurring/create_edit_recurring_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/categories/categories_provider.dart';
import '../../shared/models/category.dart';
import '../../shared/models/recurring_rule.dart';
import '../../shared/widgets/amount_field.dart';
import '../../shared/widgets/category_picker.dart'; // defined in Phase 5
import 'recurring_provider.dart';

class CreateEditRecurringSheet extends ConsumerStatefulWidget {
  final RecurringRule? rule;
  const CreateEditRecurringSheet({super.key, this.rule});

  static Future<void> show(BuildContext context, {RecurringRule? rule}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CreateEditRecurringSheet(rule: rule),
      );

  @override
  ConsumerState<CreateEditRecurringSheet> createState() =>
      _CreateEditRecurringSheetState();
}

class _CreateEditRecurringSheetState
    extends ConsumerState<CreateEditRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _amountCents;
  late String _frequency;
  late String _type;
  String? _selectedCategoryId; // replaces the old hardcoded 'c1'
  DateTime _startDate = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCents = widget.rule?.amount ?? 0;
    _frequency = widget.rule?.frequency.name ?? 'monthly';
    _type = widget.rule?.type.name ?? 'expense';
    _selectedCategoryId = widget.rule?.categoryId;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.rule == null) {
        await ref.read(recurringNotifierProvider.notifier).addRule(
              categoryId: _selectedCategoryId!,
              amount: _amountCents,
              type: _type,
              frequency: _frequency,
              startDate: _startDate,
            );
      } else {
        await ref.read(recurringNotifierProvider.notifier).updateRule(
              widget.rule!.id,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save rule')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch categoriesProvider to populate the CategoryPicker.
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.rule != null ? 'Edit Rule' : 'New Recurring Rule',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            // CategoryPicker — same widget used by AddTransactionSheet in Phase 5.
            categoriesAsync.when(
              data: (categories) => CategoryPicker(
                categories: categories
                    .where((c) => c.type.name == _type)
                    .toList(),
                selectedId: _selectedCategoryId,
                onChanged: (id) => setState(() => _selectedCategoryId = id),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load categories'),
            ),
            const SizedBox(height: 16),
            AmountField(
              initialCents: _amountCents,
              onChanged: (v) => _amountCents = v,
              currency: 'USD',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: ['daily', 'weekly', 'monthly', 'yearly']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.rule != null ? 'Update Rule' : 'Create Rule'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4.4: Update GoRouter**

In `lib/core/router/app_router.dart`:
```dart
import '../../features/recurring/recurring_screen.dart';

GoRoute(path: AppRoutes.recurring, builder: (_, __) => const RecurringScreen()),
```

- [ ] **Step 4.5: Run full test suite**

```bash
cd apps/mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 4.6: Commit**

```bash
git add apps/mobile/lib/features/categories/categories_provider.dart apps/mobile/lib/features/recurring/ apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/recurring): add RecurringScreen and CreateEditRecurringSheet with CategoryPicker"
```

---

## Phase 7 Complete

- ✅ `BudgetsNotifier` — fetch budgets + actual spend (via budget-vs-actual endpoint), add/update/delete
- ✅ `BudgetsScreen` — card per budget with `BudgetProgressBar`, edit + delete actions, FAB
- ✅ `CreateEditBudgetSheet` — period selector, amount field, create or update
- ✅ `RecurringNotifier` — fetch rules, add/update (toggle active)/delete
- ✅ `RecurringScreen` — list with active/paused state, next-run date, pause/delete popup
- ✅ `CreateEditRecurringSheet` — type toggle, **CategoryPicker** (reads `categoriesProvider`, filters by selected type, validates non-null before submit), amount field, frequency dropdown
- ✅ `categoriesProvider` — shared `FutureProvider<List<Category>>` in `features/categories/categories_provider.dart`; used by both `AddTransactionSheet` (Phase 5) and `CreateEditRecurringSheet` (Phase 7)
- ✅ Unit tests: 3 budgets + 2 recurring = 5 tests

**Next plan:** `2026-06-16-flutter-phase8.md` — Reports + Export (FL Chart, CSV/PDF download)
