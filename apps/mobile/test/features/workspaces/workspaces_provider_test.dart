import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late DioAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test'});
    final prefs = await SharedPreferences.getInstance();
    final storage = SecureStorageService.withPrefs(prefs);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      apiClientProvider.overrideWithValue(ApiClient.withDio(dio, storage)),
    ]);
  });

  tearDown(() => container.dispose());

  test('loadWorkspaces populates state', () async {
    adapter.onGet('/workspaces', (server) => server.reply(200, {
      'data': [
        {'id': 'w1', 'name': 'Home', 'currency': 'EUR', 'ownerId': 'u1', 'members': []},
      ],
    }));

    await container.read(workspaceNotifierProvider.notifier).loadWorkspaces();
    final state = container.read(workspaceNotifierProvider);
    expect(state.workspaces.length, 1);
    expect(state.workspaces.first.name, 'Home');
    expect(state.activeWorkspace?.id, 'w1');
  });

  test('createWorkspace adds to state and sets active if none', () async {
    adapter.onPost('/workspaces', (server) => server.reply(201, {
      'data': {'id': 'w2', 'name': 'New WS', 'currency': 'EUR', 'ownerId': 'u1', 'members': []},
    }), data: {'name': 'New WS', 'currency': 'EUR'});

    final ws = await container.read(workspaceNotifierProvider.notifier).createWorkspace(
      name: 'New WS',
      currency: 'EUR',
    );
    expect(ws.id, 'w2');
    final state = container.read(workspaceNotifierProvider);
    expect(state.activeWorkspace?.id, 'w2');
  });

  test('setActive updates activeWorkspace', () {
    container.read(workspaceNotifierProvider.notifier).state = const WorkspaceState(
      workspaces: [
        Workspace(id: 'w1', name: 'WS1', currency: 'USD', ownerId: 'u1', members: []),
        Workspace(id: 'w2', name: 'WS2', currency: 'EUR', ownerId: 'u1', members: []),
      ],
      activeWorkspace: Workspace(id: 'w1', name: 'WS1', currency: 'USD', ownerId: 'u1', members: []),
    );
    container.read(workspaceNotifierProvider.notifier).setActive('w2');
    expect(container.read(workspaceNotifierProvider).activeWorkspace?.id, 'w2');
  });
}
