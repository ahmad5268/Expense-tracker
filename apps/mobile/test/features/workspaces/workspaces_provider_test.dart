import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient apiClient;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SecureStorageService.withPrefs(prefs);

    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    apiClient = ApiClient.withDio(dio, storage);

    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
  });

  tearDown(() => container.dispose());

  test('loadWorkspaces populates workspaces list', () async {
    adapter.onGet(
      '/workspaces',
      (server) => server.reply(200, {
        'data': [
          {'id': 'w1', 'name': 'Test WS', 'currency': 'USD', 'ownerId': 'u1'},
        ],
      }),
    );

    await container.read(workspaceNotifierProvider.notifier).loadWorkspaces();

    final state = container.read(workspaceNotifierProvider);
    expect(state.workspaces, hasLength(1));
    expect(state.workspaces.first.name, 'Test WS');
    expect(state.activeWorkspace, isNotNull);
  });

  test('createWorkspace adds workspace and sets it active', () async {
    adapter.onPost(
      '/workspaces',
      (server) => server.reply(201, {
        'data': {'id': 'w2', 'name': 'New WS', 'currency': 'EUR', 'ownerId': 'u1'},
      }),
      data: {'name': 'New WS', 'currency': 'EUR'},
    );

    final workspace = await container
        .read(workspaceNotifierProvider.notifier)
        .createWorkspace(name: 'New WS', currency: 'EUR');

    expect(workspace.id, 'w2');
    expect(workspace, isA<Workspace>());
    final state = container.read(workspaceNotifierProvider);
    expect(state.workspaces, hasLength(1));
    expect(state.activeWorkspace?.id, 'w2');
  });
}
