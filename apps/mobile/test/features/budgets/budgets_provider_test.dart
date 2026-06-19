import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
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
  'id': 'b1',
  'workspaceId': 'w1',
  'amount': 100000,
  'period': 'MONTHLY',
  'year': 2026,
  'month': 6,
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
    adapter
      ..onGet('/workspaces/w1/budgets',
          (server) => server.reply(200, {'data': [_budgetJson]}))
      ..onGet('/workspaces/w1/reports/budget-vs-actual',
          (server) => server.reply(200, {'data': []}),
          queryParameters: {'year': DateTime.now().year, 'month': DateTime.now().month});

    await container.read(budgetsNotifierProvider.notifier).fetchBudgets();
    final state = container.read(budgetsNotifierProvider);
    expect(state.budgets.length, 1);
    expect(state.budgets.first.amount, 100000);
  });

  test('addBudget appends to list', () async {
    adapter.onPost(
      '/workspaces/w1/budgets',
      (server) => server.reply(201, {'data': _budgetJson}),
      data: {'amount': 100000, 'period': 'monthly', 'year': 2026, 'month': 6},
    );

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
      ..onGet('/workspaces/w1/reports/budget-vs-actual',
          (server) => server.reply(200, {'data': []}))
      ..onDelete('/workspaces/w1/budgets/b1',
          (server) => server.reply(200, {'data': null}));

    await container.read(budgetsNotifierProvider.notifier).fetchBudgets();
    await container.read(budgetsNotifierProvider.notifier).deleteBudget('b1');

    expect(container.read(budgetsNotifierProvider).budgets, isEmpty);
  });
}
