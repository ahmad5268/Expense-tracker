import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/budget.dart';

class BudgetsState {
  final List<Budget> budgets;
  final Map<String, int> actualSpend;
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
