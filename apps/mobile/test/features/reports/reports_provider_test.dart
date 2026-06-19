import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/reports/reports_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'reports_provider_test.mocks.dart';

const _workspace = Workspace(id: 'w1', name: 'P', currency: 'USD', ownerId: 'u1');

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;
  final now = DateTime.now();

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

  test('fetchReports loads summary data', () async {
    adapter
      ..onGet('/workspaces/w1/reports/summary',
          (server) => server.reply(200, {
                'data': {'totalIncome': 100000, 'totalExpense': 75000, 'net': 25000}
              }),
          queryParameters: {'year': now.year, 'month': now.month})
      ..onGet('/workspaces/w1/reports/by-category',
          (server) => server.reply(200, {'data': []}),
          queryParameters: {'year': now.year, 'month': now.month})
      ..onGet('/workspaces/w1/reports/trends',
          (server) => server.reply(200, {'data': []}),
          queryParameters: {'year': now.year})
      ..onGet('/workspaces/w1/reports/budget-vs-actual',
          (server) => server.reply(200, {'data': []}),
          queryParameters: {'year': now.year, 'month': now.month})
      ..onGet('/workspaces/w1/reports/year-over-year',
          (server) => server.reply(200, {'data': []}))
      ..onGet('/workspaces/w1/reports/heatmap',
          (server) => server.reply(200, {'data': []}),
          queryParameters: {'year': now.year});

    await container
        .read(reportsNotifierProvider.notifier)
        .fetchReports(year: now.year, month: now.month);
    final state = container.read(reportsNotifierProvider);
    expect(state.totalIncome, 100000);
    expect(state.totalExpense, 75000);
    expect(state.net, 25000);
    expect(state.isLoading, false);
  });
}
