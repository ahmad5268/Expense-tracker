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
