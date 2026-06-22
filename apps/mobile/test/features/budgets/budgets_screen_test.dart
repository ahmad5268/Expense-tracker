import 'package:expense_tracker/features/budgets/budgets_provider.dart';
import 'package:expense_tracker/features/budgets/budgets_screen.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/budget.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake notifier that returns a fixed BudgetsState without touching the network.
class _FakeBudgetsNotifier extends BudgetsNotifier {
  final BudgetsState _fixed;

  _FakeBudgetsNotifier(this._fixed);

  @override
  BudgetsState build() => _fixed;

  // No-op: prevents the real HTTP call triggered by initState's
  // addPostFrameCallback.
  @override
  Future<void> fetchBudgets() async {}
}

const _workspace = Workspace(
  id: 'w1',
  name: 'Test WS',
  currency: 'USD',
  ownerId: 'u1',
  members: [],
);

Widget _buildSubject(_FakeBudgetsNotifier notifier) {
  return ProviderScope(
    overrides: [
      budgetsNotifierProvider.overrideWith(() => notifier),
      activeWorkspaceProvider.overrideWith((_) => _workspace),
    ],
    child: const MaterialApp(home: BudgetsScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state message when no budgets', (tester) async {
    final notifier = _FakeBudgetsNotifier(
      const BudgetsState(budgets: [], isLoading: false),
    );
    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump(); // settle post-frame callback

    expect(find.text('No budgets yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('shows loading indicator when isLoading is true', (tester) async {
    final notifier = _FakeBudgetsNotifier(
      const BudgetsState(budgets: [], isLoading: true),
    );
    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders budget item with progress bar at 50%', (tester) async {
    const budget = Budget(
      id: 'b1',
      workspaceId: 'w1',
      amount: 10000, // 100.00 USD in cents
      period: BudgetPeriod.monthly,
      year: 2026,
      month: 6,
    );

    final notifier = _FakeBudgetsNotifier(
      BudgetsState(
        budgets: [budget],
        // spent 5000 / budget 10000 = 50%
        actualSpend: {'b1': 5000},
        isLoading: false,
      ),
    );

    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    // BudgetProgressBar renders a LinearProgressIndicator.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Percentage label should show 50%.
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('shows "Total Budget" label when categoryName is null',
      (tester) async {
    const budget = Budget(
      id: 'b2',
      workspaceId: 'w1',
      categoryId: null,
      categoryName: null,
      amount: 10000,
      period: BudgetPeriod.monthly,
      year: 2026,
      month: 6,
    );

    final notifier = _FakeBudgetsNotifier(
      BudgetsState(budgets: [budget], actualSpend: {}, isLoading: false),
    );

    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    expect(find.text('Total Budget'), findsOneWidget);
  });

  testWidgets('budget bar color is amber at 90% spend (warning threshold)',
      (tester) async {
    // 9000 spent / 10000 limit = 90%  → falls in 80–99% range → #F59E0B
    const budget = Budget(
      id: 'b3',
      workspaceId: 'w1',
      amount: 10000,
      period: BudgetPeriod.monthly,
      year: 2026,
      month: 6,
    );

    final notifier = _FakeBudgetsNotifier(
      BudgetsState(
        budgets: [budget],
        actualSpend: {'b3': 9000},
        isLoading: false,
      ),
    );

    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    expect(find.text('90%'), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final animation =
        indicator.valueColor as AlwaysStoppedAnimation<Color>;
    expect(animation.value, const Color(0xFFF59E0B));
  });

  testWidgets('budget bar color is red at or above 100% spend',
      (tester) async {
    // 10000 spent / 10000 limit = 100%  → #EF4444
    const budget = Budget(
      id: 'b4',
      workspaceId: 'w1',
      amount: 10000,
      period: BudgetPeriod.monthly,
      year: 2026,
      month: 6,
    );

    final notifier = _FakeBudgetsNotifier(
      BudgetsState(
        budgets: [budget],
        actualSpend: {'b4': 10000},
        isLoading: false,
      ),
    );

    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final animation =
        indicator.valueColor as AlwaysStoppedAnimation<Color>;
    expect(animation.value, const Color(0xFFEF4444));
  });

  testWidgets('renders multiple budget cards', (tester) async {
    const budgets = [
      Budget(
        id: 'b1',
        workspaceId: 'w1',
        amount: 10000,
        period: BudgetPeriod.monthly,
        year: 2026,
        month: 6,
        categoryName: 'Food',
      ),
      Budget(
        id: 'b2',
        workspaceId: 'w1',
        amount: 20000,
        period: BudgetPeriod.monthly,
        year: 2026,
        month: 6,
        categoryName: 'Transport',
      ),
    ];

    final notifier = _FakeBudgetsNotifier(
      BudgetsState(budgets: budgets, actualSpend: {}, isLoading: false),
    );

    await tester.pumpWidget(_buildSubject(notifier));
    await tester.pump();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });
}
