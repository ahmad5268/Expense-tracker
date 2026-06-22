import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/transactions/transactions_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:expense_tracker/shared/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late DioAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final prefs = await SharedPreferences.getInstance();
    final storage = SecureStorageService.withPrefs(prefs);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);

    container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      apiClientProvider.overrideWithValue(ApiClient.withDio(dio, storage)),
      workspaceNotifierProvider.overrideWith(() => WorkspaceNotifier()),
    ]);

    container.read(workspaceNotifierProvider.notifier).state = const WorkspaceState(
      activeWorkspace: Workspace(id: 'w1', name: 'My WS', currency: 'USD', ownerId: 'u1', members: []),
    );
  });

  tearDown(() => container.dispose());

  test('load fetches transactions and categories', () async {
    adapter
      ..onGet(
          '/workspaces/w1/transactions',
          (server) => server.reply(200, {
                'data': [
                  {
                    'id': 't1', 'workspaceId': 'w1', 'userId': 'u1', 'categoryId': 'c1',
                    'amount': 500, 'type': 'EXPENSE', 'date': '2026-06-01T00:00:00.000Z',
                    'createdAt': '2026-06-01T00:00:00.000Z',
                  },
                ],
                'meta': {'total': 1, 'page': 1, 'limit': 20, 'totalPages': 1},
              }),
          queryParameters: {'page': 1, 'limit': 20})
      ..onGet('/workspaces/w1/categories', (server) => server.reply(200, <dynamic>[]));


    await container.read(transactionsNotifierProvider.notifier).load();
    final state = container.read(transactionsNotifierProvider);

    expect(state.transactions.length, 1);
    expect(state.transactions.first.amount, 500);
    expect(state.transactions.first.type, TransactionType.expense);
  });

  test('delete removes transaction from state', () async {
    container.read(transactionsNotifierProvider.notifier).state = TransactionsState(
      transactions: [
        Transaction(
          id: 't1', workspaceId: 'w1', userId: 'u1', categoryId: 'c1',
          amount: 500, type: TransactionType.expense,
          date: DateTime(2026, 6, 1), createdAt: DateTime(2026, 6, 1),
        ),
      ],
    );

    adapter.onDelete('/workspaces/w1/transactions/t1', (server) => server.reply(204, null));

    await container.read(transactionsNotifierProvider.notifier).delete('t1');
    final state = container.read(transactionsNotifierProvider);
    expect(state.transactions, isEmpty);
  });

  test('setFilter updates filter and triggers reload', () async {
    adapter
      ..onGet(
          '/workspaces/w1/transactions',
          (server) => server.reply(200, {
                'data': [],
                'meta': {'total': 0, 'page': 1, 'limit': 20, 'totalPages': 1},
              }),
          queryParameters: {'page': 1, 'limit': 20, 'type': 'EXPENSE'})
      ..onGet('/workspaces/w1/categories', (server) => server.reply(200, <dynamic>[]));


    const filter = TransactionFilter(type: TransactionType.expense);
    await container.read(transactionsNotifierProvider.notifier).setFilter(filter);
    final state = container.read(transactionsNotifierProvider);
    expect(state.filter.type, TransactionType.expense);
  });
}
