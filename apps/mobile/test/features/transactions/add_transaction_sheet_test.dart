import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/features/transactions/add_transaction_sheet.dart';
import 'package:expense_tracker/features/transactions/transactions_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/category.dart';
import 'package:expense_tracker/shared/models/transaction.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

// ---------------------------------------------------------------------------
// Stub notifiers — prevent real API calls
// ---------------------------------------------------------------------------

class _StubTransactionsNotifier extends TransactionsNotifier {
  final TransactionsState _initial;
  bool fetchCategoriesCalled = false;

  _StubTransactionsNotifier(this._initial);

  @override
  TransactionsState build() => _initial;

  @override
  Future<void> load() async {}

  @override
  Future<void> fetchCategories() async {
    fetchCategoriesCalled = true;
  }

  @override
  Future<void> create({
    required String categoryId,
    required int amount,
    required TransactionType type,
    required DateTime date,
    String? description,
  }) async {}
}

class _StubWorkspaceNotifier extends WorkspaceNotifier {
  final WorkspaceState _initial;
  _StubWorkspaceNotifier(this._initial);

  @override
  WorkspaceState build() => _initial;

  @override
  Future<void> loadWorkspaces() async {}
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _testWorkspace = Workspace(
  id: 'w1',
  name: 'Test WS',
  currency: 'USD',
  ownerId: 'u1',
  members: [],
);

const _expenseCategory = Category(
  id: 'cat1',
  workspaceId: 'w1',
  name: 'Food',
  icon: '🍔',
  color: '#EF4444',
  type: CategoryType.expense,
);

const _incomeCategory = Category(
  id: 'cat2',
  workspaceId: 'w1',
  name: 'Salary',
  icon: '💼',
  color: '#10B981',
  type: CategoryType.income,
);

// ---------------------------------------------------------------------------
// Helper — builds the sheet inside a Scaffold (simulates a bottom sheet)
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required _StubTransactionsNotifier txNotifier,
  WorkspaceState? workspaceState,
}) {
  final wsState = workspaceState ??
      const WorkspaceState(
        workspaces: [_testWorkspace],
        activeWorkspace: _testWorkspace,
      );

  final container = ProviderContainer(overrides: [
    transactionsNotifierProvider.overrideWith(() => txNotifier),
    workspaceNotifierProvider.overrideWith(
      () => _StubWorkspaceNotifier(wsState),
    ),
  ]);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ProviderScope(
                parent: container,
                child: const AddTransactionSheet(),
              ),
            ),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders without error when categories are available',
      (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(
        categories: [_expenseCategory, _incomeCategory],
      ),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // The sheet header should be visible (header + submit button both use this text)
    expect(find.text('Add Transaction'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows category chips for selected transaction type',
      (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(
        categories: [_expenseCategory, _incomeCategory],
      ),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Default type is expense, so 'Food' chip should be visible
    expect(find.text('Food'), findsOneWidget);
    // Income category 'Salary' should NOT be visible while on Expense tab
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('calls fetchCategories when categories are empty on init',
      (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(categories: []),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    // pump a few frames: pumpAndSettle would hang on CircularProgressIndicator
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.fetchCategoriesCalled, isTrue);
  });

  testWidgets('does not call fetchCategories when categories are already present',
      (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(categories: [_expenseCategory]),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(notifier.fetchCategoriesCalled, isFalse);
  });

  testWidgets('shows Expense and Income segment buttons', (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(categories: [_expenseCategory, _incomeCategory]),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
  });

  testWidgets('switching type shows income categories', (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(
        categories: [_expenseCategory, _incomeCategory],
      ),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Switch to Income
    await tester.tap(find.text('Income'));
    await tester.pump();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  testWidgets('Add Transaction button is present', (tester) async {
    final notifier = _StubTransactionsNotifier(
      const TransactionsState(categories: [_expenseCategory]),
    );

    await tester.pumpWidget(_buildSubject(txNotifier: notifier));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // The submit button inside the sheet
    expect(find.widgetWithText(ElevatedButton, 'Add Transaction'), findsOneWidget);
  });
}
