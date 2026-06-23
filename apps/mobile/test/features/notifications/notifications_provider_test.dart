import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/notifications/notifications_provider.dart';
import 'package:expense_tracker/shared/models/notification_item.dart';

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

  test('load fetches notifications and counts unread', () async {
    adapter.onGet('/notifications', (server) => server.reply(200, {
      'data': {
        'data': [
          {
            'id': 'n1', 'userId': 'u1', 'type': 'BUDGET_ALERT',
            'payload': {}, 'isRead': false,
            'createdAt': '2026-06-01T00:00:00.000Z',
          },
          {
            'id': 'n2', 'userId': 'u1', 'type': 'MONTHLY_SUMMARY',
            'payload': {}, 'isRead': true,
            'createdAt': '2026-06-01T00:00:00.000Z',
          },
        ],
      },
    }));

    await container.read(notificationsNotifierProvider.notifier).load();
    final state = container.read(notificationsNotifierProvider);

    expect(state.items.length, 2);
    expect(state.unreadCount, 1);
  });

  test('markAllRead sets all isRead to true and unreadCount to 0', () async {
    adapter.onPatch('/notifications/read-all', (server) => server.reply(200, {}));
    container.read(notificationsNotifierProvider.notifier).state = NotificationsState(
      items: [
        NotificationItem(
          id: 'n1', userId: 'u1', type: NotificationType.budgetAlert,
          payload: {}, isRead: false, createdAt: DateTime(2026, 6, 1),
        ),
      ],
      unreadCount: 1,
    );

    await container.read(notificationsNotifierProvider.notifier).markAllRead();
    final state = container.read(notificationsNotifierProvider);
    expect(state.unreadCount, 0);
    expect(state.items.first.isRead, true);
  });

  test('initial state has empty items and 0 unread', () {
    final state = container.read(notificationsNotifierProvider);
    expect(state.items, isEmpty);
    expect(state.unreadCount, 0);
  });
}
