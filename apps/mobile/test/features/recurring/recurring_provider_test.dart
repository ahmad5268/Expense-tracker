import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
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
  'id': 'r1',
  'workspaceId': 'w1',
  'categoryId': 'c1',
  'amount': 50000,
  'type': 'EXPENSE',
  'frequency': 'MONTHLY',
  'startDate': '2026-01-01T00:00:00.000Z',
  'nextRunAt': '2026-07-01T00:00:00.000Z',
  'isActive': true,
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
