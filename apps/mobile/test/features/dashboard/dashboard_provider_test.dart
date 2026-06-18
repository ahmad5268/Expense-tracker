import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/dashboard/dashboard_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

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
      workspaceNotifierProvider.overrideWith(() {
        final notifier = WorkspaceNotifier();
        return notifier;
      }),
    ]);

    container.read(workspaceNotifierProvider.notifier).state = const WorkspaceState(
      workspaces: [
        Workspace(id: 'w1', name: 'My WS', currency: 'USD', ownerId: 'u1', members: []),
      ],
      activeWorkspace: Workspace(id: 'w1', name: 'My WS', currency: 'USD', ownerId: 'u1', members: []),
    );
  });

  tearDown(() => container.dispose());

  test('load populates dashboard state from API', () async {
    final now = DateTime.now();
    adapter
      ..onGet(
          '/workspaces/w1/reports/summary',
          (server) => server.reply(200, {
                'data': {'totalIncome': 5000, 'totalExpense': 3000, 'net': 2000},
              }),
          queryParameters: {'year': now.year, 'month': now.month})
      ..onGet(
          '/workspaces/w1/transactions',
          (server) => server.reply(200, {
                'data': [],
                'meta': {'total': 0, 'page': 1, 'limit': 5, 'totalPages': 1},
              }),
          queryParameters: {'limit': 5, 'page': 1});

    await container.read(dashboardNotifierProvider.notifier).load();
    final state = container.read(dashboardNotifierProvider);

    expect(state.totalIncome, 5000);
    expect(state.totalExpense, 3000);
    expect(state.net, 2000);
    expect(state.isLoading, false);
  });

  test('load does nothing when no active workspace', () async {
    container.read(workspaceNotifierProvider.notifier).state =
        const WorkspaceState();
    await container.read(dashboardNotifierProvider.notifier).load();
    final state = container.read(dashboardNotifierProvider);
    expect(state.totalIncome, 0);
  });
}
