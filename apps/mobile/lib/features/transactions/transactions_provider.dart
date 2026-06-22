import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/transaction.dart';
import '../../shared/models/category.dart';

class TransactionFilter {
  final DateTime? from;
  final DateTime? to;
  final TransactionType? type;
  final String? categoryId;
  final int page;

  const TransactionFilter({this.from, this.to, this.type, this.categoryId, this.page = 1});

  TransactionFilter copyWith({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? categoryId,
    int? page,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearType = false,
    bool clearCategory = false,
  }) =>
      TransactionFilter(
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        type: clearType ? null : (type ?? this.type),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        page: page ?? this.page,
      );

  Map<String, dynamic> toQueryParams() => {
        'page': page,
        'limit': 20,
        if (from != null) 'from': from!.toIso8601String(),
        if (to != null) 'to': to!.toIso8601String(),
        if (type != null) 'type': type!.name.toUpperCase(),
        if (categoryId != null) 'categoryId': categoryId,
      };
}

class TransactionsState {
  final List<Transaction> transactions;
  final List<Category> categories;
  final int total;
  final int totalPages;
  final TransactionFilter filter;
  final bool isLoading;

  const TransactionsState({
    this.transactions = const [],
    this.categories = const [],
    this.total = 0,
    this.totalPages = 1,
    this.filter = const TransactionFilter(),
    this.isLoading = false,
  });

  TransactionsState copyWith({
    List<Transaction>? transactions,
    List<Category>? categories,
    int? total,
    int? totalPages,
    TransactionFilter? filter,
    bool? isLoading,
  }) =>
      TransactionsState(
        transactions: transactions ?? this.transactions,
        categories: categories ?? this.categories,
        total: total ?? this.total,
        totalPages: totalPages ?? this.totalPages,
        filter: filter ?? this.filter,
        isLoading: isLoading ?? this.isLoading,
      );
}

class TransactionsNotifier extends Notifier<TransactionsState> {
  @override
  TransactionsState build() => const TransactionsState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> load() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    state = state.copyWith(isLoading: true);

    try {
      final results = await Future.wait([
        _api.dio.get('/workspaces/${workspace.id}/transactions',
            queryParameters: state.filter.toQueryParams()),
        _api.dio.get('/workspaces/${workspace.id}/categories'),
      ]);

      final txData = results[0].data;
      final txList = (txData['data'] as List)
          .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
          .toList();
      final catList = (results[1].data['data'] as List)
          .map((j) => Category.fromJson(j as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        transactions: txList,
        categories: catList,
        total: txData['meta']['total'] as int,
        totalPages: txData['meta']['totalPages'] as int,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Lightweight fetch used by add-transaction sheet so a categories load
  // never fails silently because of a concurrent transactions error.
  Future<void> fetchCategories() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    final res = await _api.dio.get('/workspaces/${workspace.id}/categories');
    final catList = (res.data['data'] as List)
        .map((j) => Category.fromJson(j as Map<String, dynamic>))
        .toList();
    state = state.copyWith(categories: catList);
  }

  Future<void> create({
    required String categoryId,
    required int amount,
    required TransactionType type,
    required DateTime date,
    String? description,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    await _api.dio.post('/workspaces/${workspace.id}/transactions', data: {
      'categoryId': categoryId,
      'amount': amount,
      'type': type.name.toUpperCase(),
      'date': date.toIso8601String(),
      if (description != null) 'description': description,
    });
    await load();
  }

  Future<void> delete(String transactionId) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    await _api.dio.delete('/workspaces/${workspace.id}/transactions/$transactionId');
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != transactionId).toList(),
    );
  }

  Future<void> setFilter(TransactionFilter filter) async {
    state = state.copyWith(filter: filter.copyWith(page: 1));
    await load();
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, TransactionsState>(TransactionsNotifier.new);
