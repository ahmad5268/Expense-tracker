# Flutter App — Phase 4: Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Dashboard screen that shows the monthly summary (income/expense/net), the 5 most recent transactions, and budget progress bars — all for the active workspace.

**Architecture:** A single `DashboardNotifier` fetches the monthly summary and recent transactions in parallel. Budget progress is derived from the budgets list (fetched in Phase 7's `BudgetsProvider`, stubbed here as a local call). The Dashboard is the first screen authenticated users see. A `BottomNavigationBar` (or `NavigationRail` on wide screens) is also wired here as the main shell.

**Tech Stack:** `flutter_riverpod`, `go_router`, `intl`

**Prerequisite:** Phase 3 complete. `activeWorkspaceProvider`, `CurrencyFormatter`, all models available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/features/dashboard/dashboard_provider.dart` | Fetches summary + recent transactions for active workspace |
| `lib/features/dashboard/dashboard_screen.dart` | Root shell with BottomNavigationBar + dashboard body |
| `lib/features/dashboard/widgets/summary_card.dart` | Income/expense/net card |
| `lib/features/dashboard/widgets/recent_transactions_list.dart` | Last 5 transactions widget |
| `lib/features/dashboard/widgets/budget_progress_bar.dart` | Horizontal progress bar (% used, color-coded) |
| `lib/core/router/app_router.dart` | Updated: dashboard route uses `DashboardScreen` shell |
| `test/features/dashboard/dashboard_provider_test.dart` | Unit tests |
| `test/features/dashboard/widgets/summary_card_test.dart` | Widget test |
| `test/features/dashboard/widgets/budget_progress_bar_test.dart` | Widget test |

---

## Task 1: DashboardProvider

**Files:**
- Create: `lib/features/dashboard/dashboard_provider.dart`
- Create: `test/features/dashboard/dashboard_provider_test.dart`

- [ ] **Step 1.1: Write failing unit tests**

```dart
// apps/mobile/test/features/dashboard/dashboard_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/dashboard/dashboard_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'dashboard_provider_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  const workspace = Workspace(id: 'w1', name: 'Personal', currency: 'USD', ownerId: 'u1');

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    final mockStorage = MockSecureStorageService();
    when(mockStorage.getAccessToken()).thenAnswer((_) async => 'tok');
    final client = ApiClient.withDio(dio, mockStorage);

    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      activeWorkspaceProvider.overrideWithValue(workspace),
    ]);
  });

  tearDown(() => container.dispose());

  test('loads summary and recent transactions on fetch', () async {
    adapter
      ..onGet('/workspaces/w1/reports/summary', (server) => server.reply(200, {
            'data': {'totalIncome': 100000, 'totalExpense': 75000, 'net': 25000, 'year': 2026, 'month': 6}
          }))
      ..onGet('/workspaces/w1/transactions', (server) => server.reply(200, {
            'data': []
          }));

    await container.read(dashboardNotifierProvider.notifier).load();

    final state = container.read(dashboardNotifierProvider);
    expect(state.totalIncome, 100000);
    expect(state.totalExpense, 75000);
    expect(state.net, 25000);
  });

  test('state is DashboardState.empty when workspace is null', () async {
    container = ProviderContainer(overrides: [
      activeWorkspaceProvider.overrideWithValue(null),
    ]);
    final state = container.read(dashboardNotifierProvider);
    expect(state.totalIncome, 0);
  });
}
```

- [ ] **Step 1.2: Generate mocks and run to verify failure**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dashboard/dashboard_provider_test.dart
```

Expected: FAIL — `Cannot find module 'dashboard_provider.dart'`

- [ ] **Step 1.3: Implement DashboardProvider**

```dart
// apps/mobile/lib/features/dashboard/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/transaction.dart';

class DashboardState {
  final int totalIncome;
  final int totalExpense;
  final int net;
  final List<Transaction> recentTransactions;
  final bool isLoading;

  const DashboardState({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.net = 0,
    this.recentTransactions = const [],
    this.isLoading = false,
  });

  DashboardState copyWith({
    int? totalIncome,
    int? totalExpense,
    int? net,
    List<Transaction>? recentTransactions,
    bool? isLoading,
  }) =>
      DashboardState(
        totalIncome: totalIncome ?? this.totalIncome,
        totalExpense: totalExpense ?? this.totalExpense,
        net: net ?? this.net,
        recentTransactions: recentTransactions ?? this.recentTransactions,
        isLoading: isLoading ?? this.isLoading,
      );
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  Future<void> load() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;

    state = state.copyWith(isLoading: true);
    final now = DateTime.now();
    final client = ref.read(apiClientProvider);

    try {
      final results = await Future.wait([
        client.dio.get(
          '/workspaces/${workspace.id}/reports/summary',
          queryParameters: {'year': now.year, 'month': now.month},
        ),
        client.dio.get(
          '/workspaces/${workspace.id}/transactions',
          queryParameters: {'limit': 5, 'page': 1},
        ),
      ]);

      final summary = results[0].data['data'] as Map<String, dynamic>;
      final txList = (results[1].data['data'] as List)
          .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
          .toList();

      state = DashboardState(
        totalIncome: summary['totalIncome'] as int,
        totalExpense: summary['totalExpense'] as int,
        net: summary['net'] as int,
        recentTransactions: txList,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/features/dashboard/dashboard_provider_test.dart
```

Expected: PASS — 2 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/features/dashboard/dashboard_provider.dart apps/mobile/test/features/dashboard/dashboard_provider_test.dart
git commit -m "feat(mobile/dashboard): add DashboardNotifier with summary + recent transactions"
```

---

## Task 2: SummaryCard widget
Depends-on: 1

**Files:**
- Create: `lib/features/dashboard/widgets/summary_card.dart`
- Create: `test/features/dashboard/widgets/summary_card_test.dart`

- [ ] **Step 2.1: Write failing widget test**

```dart
// apps/mobile/test/features/dashboard/widgets/summary_card_test.dart
import 'package:expense_tracker/features/dashboard/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SummaryCard displays formatted income, expense, net', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          totalIncome: 100000,
          totalExpense: 75000,
          net: 25000,
          currency: 'USD',
        ),
      ),
    ));

    expect(find.text('\$1,000.00'), findsOneWidget); // income
    expect(find.text('\$750.00'), findsOneWidget);   // expense
    expect(find.text('\$250.00'), findsOneWidget);   // net
  });

  testWidgets('SummaryCard shows negative net in red', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          totalIncome: 50000,
          totalExpense: 80000,
          net: -30000,
          currency: 'USD',
        ),
      ),
    ));

    final netText = tester.widget<Text>(find.text('-\$300.00'));
    expect(netText.style?.color, Colors.red);
  });
}
```

- [ ] **Step 2.2: Run test — verify it fails**

```bash
flutter test test/features/dashboard/widgets/summary_card_test.dart
```

Expected: FAIL — `Cannot find module 'summary_card.dart'`

- [ ] **Step 2.3: Implement SummaryCard**

```dart
// apps/mobile/lib/features/dashboard/widgets/summary_card.dart
import 'package:flutter/material.dart';
import '../../../shared/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int net;
  final String currency;

  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Month', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatColumn(
                  label: 'Income',
                  value: CurrencyFormatter.format(totalIncome, currency),
                  color: Colors.green,
                ),
                const Spacer(),
                _StatColumn(
                  label: 'Expenses',
                  value: CurrencyFormatter.format(totalExpense, currency),
                  color: Colors.red,
                ),
                const Spacer(),
                _StatColumn(
                  label: 'Net',
                  value: CurrencyFormatter.format(net, currency),
                  color: net >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
flutter test test/features/dashboard/widgets/summary_card_test.dart
```

Expected: PASS — 2 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/mobile/lib/features/dashboard/widgets/summary_card.dart apps/mobile/test/features/dashboard/widgets/summary_card_test.dart
git commit -m "feat(mobile/dashboard): add SummaryCard widget with income/expense/net"
```

---

## Task 3: BudgetProgressBar widget
Depends-on: 1

**Files:**
- Create: `lib/features/dashboard/widgets/budget_progress_bar.dart`
- Create: `test/features/dashboard/widgets/budget_progress_bar_test.dart`

- [ ] **Step 3.1: Write failing widget test**

```dart
// apps/mobile/test/features/dashboard/widgets/budget_progress_bar_test.dart
import 'package:expense_tracker/features/dashboard/widgets/budget_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BudgetProgressBar shows label and percentage', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetProgressBar(
          label: 'Food & Dining',
          spent: 8500,
          limit: 10000,
          currency: 'USD',
        ),
      ),
    ));

    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('BudgetProgressBar is orange at 80% and above', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetProgressBar(
          label: 'Transport',
          spent: 8000,
          limit: 10000,
          currency: 'USD',
        ),
      ),
    ));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, Colors.orange);
  });

  testWidgets('BudgetProgressBar is red when exceeded', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetProgressBar(
          label: 'Shopping',
          spent: 11000,
          limit: 10000,
          currency: 'USD',
        ),
      ),
    ));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, Colors.red);
  });
}
```

- [ ] **Step 3.2: Run test — verify it fails**

```bash
flutter test test/features/dashboard/widgets/budget_progress_bar_test.dart
```

Expected: FAIL — `Cannot find module 'budget_progress_bar.dart'`

- [ ] **Step 3.3: Implement BudgetProgressBar**

```dart
// apps/mobile/lib/features/dashboard/widgets/budget_progress_bar.dart
import 'package:flutter/material.dart';
import '../../../shared/utils/currency_formatter.dart';

class BudgetProgressBar extends StatelessWidget {
  final String label;
  final int spent;
  final int limit;
  final String currency;

  const BudgetProgressBar({
    super.key,
    required this.label,
    required this.spent,
    required this.limit,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final percent = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final percentInt = (percent * 100).round();

    final color = percentInt >= 100
        ? Colors.red
        : percentInt >= 80
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '$percentInt%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent,
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 2),
          Text(
            '${CurrencyFormatter.format(spent, currency)} / ${CurrencyFormatter.format(limit, currency)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.4: Run tests — verify pass**

```bash
flutter test test/features/dashboard/widgets/budget_progress_bar_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 3.5: Commit**

```bash
git add apps/mobile/lib/features/dashboard/widgets/budget_progress_bar.dart apps/mobile/test/features/dashboard/widgets/budget_progress_bar_test.dart
git commit -m "feat(mobile/dashboard): add BudgetProgressBar with color thresholds"
```

---

## Task 4: RecentTransactionsList widget
Depends-on: 1

**Files:**
- Create: `lib/features/dashboard/widgets/recent_transactions_list.dart`

- [ ] **Step 4.1: Implement RecentTransactionsList**

```dart
// apps/mobile/lib/features/dashboard/widgets/recent_transactions_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/utils/currency_formatter.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final String currency;
  final VoidCallback onSeeAll;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.currency,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(onPressed: onSeeAll, child: const Text('See All')),
              ],
            ),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No transactions yet')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final isExpense = tx.type == TransactionType.expense;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isExpense
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      child: Text(tx.categoryIcon ?? '💰'),
                    ),
                    title: Text(tx.categoryName ?? 'Unknown'),
                    subtitle: Text(DateFormat.MMMd().format(tx.date)),
                    trailing: Text(
                      '${isExpense ? '-' : '+'}${CurrencyFormatter.format(tx.amount, currency)}',
                      style: TextStyle(
                        color: isExpense ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4.2: Commit**

```bash
git add apps/mobile/lib/features/dashboard/widgets/recent_transactions_list.dart
git commit -m "feat(mobile/dashboard): add RecentTransactionsList widget"
```

---

## Task 5: DashboardScreen + main shell
Depends-on: 2, 3, 4

**Files:**
- Create: `lib/features/dashboard/dashboard_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 5.1: Implement DashboardScreen with BottomNavigationBar shell**

```dart
// apps/mobile/lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../features/workspaces/workspace_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/summary_card.dart';
import 'widgets/recent_transactions_list.dart';
import 'widgets/budget_progress_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Text(workspace?.name ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.push(AppRoutes.workspaces),
            tooltip: 'Switch Workspace',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
      body: dashboard.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(dashboardNotifierProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SummaryCard(
                    totalIncome: dashboard.totalIncome,
                    totalExpense: dashboard.totalExpense,
                    net: dashboard.net,
                    currency: currency,
                  ),
                  const SizedBox(height: 16),
                  RecentTransactionsList(
                    transactions: dashboard.recentTransactions,
                    currency: currency,
                    onSeeAll: () => context.push(AppRoutes.transactions),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Budgets'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 1: context.go(AppRoutes.transactions);
            case 2: context.go(AppRoutes.reports);
            case 3: context.go(AppRoutes.budgets);
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 5.2: Update GoRouter to use DashboardScreen**

In `lib/core/router/app_router.dart`, change the dashboard route:

```dart
// Change placeholder:
// GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const _PlaceholderScreen('Dashboard')),
// To real screen:
GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const DashboardScreen()),
```

Add the import at the top:
```dart
import '../../features/dashboard/dashboard_screen.dart';
```

- [ ] **Step 5.3: Run flutter analyze**

```bash
cd apps/mobile && flutter analyze
```

Expected: No issues.

- [ ] **Step 5.4: Run full test suite**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 5.5: Commit**

```bash
git add apps/mobile/lib/features/dashboard/ apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/dashboard): add DashboardScreen with summary, recent transactions, bottom nav"
```

---

## Phase 4 Complete

- ✅ `DashboardNotifier` — parallel fetch of monthly summary + recent transactions (last 5)
- ✅ `SummaryCard` — income/expense/net, formatted in workspace currency
- ✅ `BudgetProgressBar` — green < 80%, orange 80–99%, red ≥ 100%
- ✅ `RecentTransactionsList` — icon + category name + date + signed amount
- ✅ `DashboardScreen` — pull-to-refresh, workspace name in AppBar, `NavigationBar` shell
- ✅ Widget tests: 2 SummaryCard + 3 BudgetProgressBar = 5 tests

**Next plan:** `2026-06-16-flutter-phase5.md` — Transactions feature (paginated list, filters, add/edit sheet)
