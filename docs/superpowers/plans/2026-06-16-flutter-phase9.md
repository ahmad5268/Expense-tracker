# Flutter App — Phase 9: Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the real-time notification system: a WebSocket client that connects to `/notifications` with JWT auth, a `NotificationsProvider` that exposes unread count and notification list, a `NotificationBell` app-bar widget with a badge, and a `NotificationsScreen` (list, mark read, delete).

**Architecture:** `WebSocketClient` wraps `socket_io_client`. It connects on app launch (once the access token is available), joins the user's room, and streams incoming events. `NotificationsNotifier` subscribes to the stream and prepends new items. On cold start it fetches the existing list from the REST API. The `NotificationBell` widget watches `unreadCountProvider` (derived from the notifier) for the badge value.

**Tech Stack:** `socket_io_client ^2.0.3`, `flutter_riverpod`, `dio`, `intl`

**Prerequisite:** Phase 3 complete. `NotificationItem` model, `ApiClient`, `SecureStorageService` available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/core/api/websocket_client.dart` | Socket.IO client — connect, disconnect, stream events |
| `lib/features/notifications/notifications_provider.dart` | List + unread count; WebSocket listener + REST fetch |
| `lib/features/notifications/notification_bell.dart` | AppBar widget with badge |
| `lib/features/notifications/notifications_screen.dart` | List of notifications, mark-read, delete |
| `lib/core/router/app_router.dart` | Updated: notifications route uses NotificationsScreen |
| `test/core/api/websocket_client_test.dart` | Unit tests |
| `test/features/notifications/notifications_provider_test.dart` | Provider unit tests |
| `test/features/notifications/notification_bell_test.dart` | Widget test for badge |

---

## Task 1: WebSocketClient

**Files:**
- Create: `lib/core/api/websocket_client.dart`
- Create: `test/core/api/websocket_client_test.dart`

- [ ] **Step 1.1: Write failing unit tests**

```dart
// apps/mobile/test/core/api/websocket_client_test.dart
import 'package:expense_tracker/core/api/websocket_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebSocketClient', () {
    test('initial state is disconnected', () {
      final client = WebSocketClient(
        baseUrl: 'http://localhost:3000',
        tokenProvider: () async => null,
      );
      expect(client.isConnected, false);
    });

    test('notificationStream is a broadcast stream', () {
      final client = WebSocketClient(
        baseUrl: 'http://localhost:3000',
        tokenProvider: () async => 'tok',
      );
      expect(client.notificationStream.isBroadcast, true);
    });

    test('dispose marks client as disconnected', () {
      final client = WebSocketClient(
        baseUrl: 'http://localhost:3000',
        tokenProvider: () async => 'tok',
      );
      client.dispose();
      expect(client.isConnected, false);
    });

    test('disconnect prevents auto-reconnect by capping reconnect attempts', () {
      // After explicit disconnect(), _reconnectAttempts is set to max so
      // _onDisconnect will not schedule further reconnects.
      final client = WebSocketClient(
        baseUrl: 'http://localhost:3000',
        tokenProvider: () async => 'tok',
      );
      client.disconnect();
      // isConnected is false and no reconnect timer is pending.
      expect(client.isConnected, false);
    });
  });
}
```

- [ ] **Step 1.2: Run test — verify it fails**

```bash
cd apps/mobile && flutter test test/core/api/websocket_client_test.dart
```

Expected: FAIL — `Cannot find module 'websocket_client.dart'`

- [ ] **Step 1.3: Implement WebSocketClient**

```dart
// apps/mobile/lib/core/api/websocket_client.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../auth/secure_storage.dart';

typedef TokenProvider = Future<String?> Function();

/// WebSocketClient wraps socket_io_client and implements [WidgetsBindingObserver]
/// to automatically disconnect when the app is backgrounded and reconnect on resume.
/// This prevents battery drain from keeping a socket alive in the background.
class WebSocketClient with WidgetsBindingObserver {
  final String _baseUrl;
  final TokenProvider _tokenProvider;
  io.Socket? _socket;
  bool _isConnected = false;

  // Exponential backoff reconnection state.
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseDelay = Duration(seconds: 2);

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  bool get isConnected => _isConnected;

  Stream<Map<String, dynamic>> get notificationStream => _controller.stream;

  /// Register this client with [WidgetsBinding] to receive lifecycle callbacks.
  /// Must be called after construction — typically inside [NotificationsNotifier.build].
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called by Flutter when the app lifecycle state changes.
  /// Disconnects on pause/detach to save battery; reconnects on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Prevent auto-reconnect during background
        _reconnectAttempts = _maxReconnectAttempts;
        _socket?.disconnect();
        _isConnected = false;
        break;
      case AppLifecycleState.resumed:
        // Reset and reconnect when app comes to foreground
        _reconnectAttempts = 0;
        connect();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break; // no action during brief inactive states
    }
  }

  Future<void> connect() async {
    if (_isConnected) return;
    final token = await _tokenProvider();
    if (token == null) return;

    _socket = io.io(
      '$_baseUrl/notifications',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _reconnectAttempts = 0; // reset backoff on successful connection
    });

    _socket!.on('notification', (data) {
      if (data is Map) {
        _controller.add(Map<String, dynamic>.from(data));
      }
    });

    // Reconnect with exponential backoff when the socket drops.
    _socket!.onDisconnect(_onDisconnect);

    _socket!.connect();
  }

  /// Called when the socket disconnects unexpectedly. Schedules a reconnect
  /// attempt with exponential backoff (2s, 4s, 8s, 16s, 32s) up to 5 tries.
  void _onDisconnect(_) {
    _isConnected = false;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      final delay = _baseDelay * (1 << _reconnectAttempts); // 2^n seconds
      _reconnectAttempts++;
      Future.delayed(delay, () {
        if (!_isConnected && !_controller.isClosed) {
          connect();
        }
      });
    }
    // After _maxReconnectAttempts the client stops trying; the user can
    // restart the app or the app can call connect() again on resume.
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
    _reconnectAttempts = _maxReconnectAttempts; // prevent auto-reconnect
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    _controller.close();
  }
}

const _wsBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

final webSocketClientProvider = Provider<WebSocketClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final client = WebSocketClient(
    baseUrl: _wsBaseUrl,
    tokenProvider: storage.getAccessToken,
  );
  ref.onDispose(client.dispose);
  return client;
});
```

> **Integration step:** `WebSocketClient.initialize()` must be called inside `NotificationsNotifier.build()` after the client is created, so lifecycle observer registration happens when the provider is first read:
> ```dart
> @override
> NotificationsState build() {
>   final wsClient = ref.read(webSocketClientProvider);
>   wsClient.initialize(); // register WidgetsBindingObserver
>   _startListening();
>   ref.onDispose(_wsSubscription?.cancel);
>   return const NotificationsState();
> }
> ```

**Additional test cases for Step 1.4:**
- Simulate `AppLifecycleState.paused` → assert `_socket.disconnect()` is called and `isConnected` is false
- Simulate `AppLifecycleState.resumed` → assert `connect()` is called
- Simulate `AppLifecycleState.detached` → same as paused
- `initialize()` registers the observer; `dispose()` removes it

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/core/api/websocket_client_test.dart
```

Expected: PASS — 4 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/core/api/websocket_client.dart apps/mobile/test/core/api/websocket_client_test.dart
git commit -m "feat(mobile/core): add WebSocketClient for real-time notifications"
```

---

## Task 2: NotificationsProvider
Depends-on: 1

**Files:**
- Create: `lib/features/notifications/notifications_provider.dart`
- Create: `test/features/notifications/notifications_provider_test.dart`

- [ ] **Step 2.1: Write failing unit tests**

```dart
// apps/mobile/test/features/notifications/notifications_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/api/websocket_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/notifications/notifications_provider.dart';
import 'package:expense_tracker/shared/models/notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>(), MockSpec<WebSocketClient>()])
import 'notifications_provider_test.mocks.dart';

final _notifJson = {
  'id': 'n1', 'userId': 'u1', 'type': 'budgetAlert',
  'payload': {'threshold': 80}, 'isRead': false,
  'createdAt': '2026-06-01T10:00:00.000Z',
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;
  late MockWebSocketClient mockWs;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    final mockStorage = MockSecureStorageService();
    when(mockStorage.getAccessToken()).thenAnswer((_) async => 'tok');
    final client = ApiClient.withDio(dio, mockStorage);

    mockWs = MockWebSocketClient();
    when(mockWs.connect()).thenAnswer((_) async {});
    when(mockWs.notificationStream).thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      webSocketClientProvider.overrideWithValue(mockWs),
    ]);
  });

  tearDown(() => container.dispose());

  test('fetchNotifications loads list from API', () async {
    adapter.onGet('/notifications', (server) => server.reply(200, {
          'data': {'data': [_notifJson], 'total': 1, 'page': 1, 'totalPages': 1}
        }));

    await container.read(notificationsNotifierProvider.notifier).fetchNotifications();
    final state = container.read(notificationsNotifierProvider);
    expect(state.notifications.length, 1);
    expect(state.notifications.first.id, 'n1');
  });

  test('unread count is computed from notifications list', () async {
    adapter.onGet('/notifications', (server) => server.reply(200, {
          'data': {'data': [_notifJson], 'total': 1, 'page': 1, 'totalPages': 1}
        }));

    await container.read(notificationsNotifierProvider.notifier).fetchNotifications();
    final count = container.read(unreadCountProvider);
    expect(count, 1);
  });

  test('markAllRead sets all notifications to read', () async {
    adapter
      ..onGet('/notifications', (server) => server.reply(200, {
            'data': {'data': [_notifJson], 'total': 1, 'page': 1, 'totalPages': 1}
          }))
      ..onPatch('/notifications/read-all',
          (server) => server.reply(200, {'data': {'count': 1}}));

    await container.read(notificationsNotifierProvider.notifier).fetchNotifications();
    await container.read(notificationsNotifierProvider.notifier).markAllRead();

    final count = container.read(unreadCountProvider);
    expect(count, 0);
  });
}
```

- [ ] **Step 2.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/notifications/notifications_provider_test.dart
```

Expected: FAIL — `Cannot find module 'notifications_provider.dart'`

- [ ] **Step 2.3: Implement NotificationsProvider**

```dart
// apps/mobile/lib/features/notifications/notifications_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_client.dart';
import '../../shared/models/notification_item.dart';

class NotificationsState {
  final List<NotificationItem> notifications;
  final bool isLoading;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
      );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  NotificationsState build() {
    _startListening();
    ref.onDispose(_wsSubscription?.cancel);
    return const NotificationsState();
  }

  Future<void> _startListening() async {
    final wsClient = ref.read(webSocketClientProvider);
    await wsClient.connect();
    _wsSubscription = wsClient.notificationStream.listen((data) {
      try {
        final item = NotificationItem.fromJson(data);
        state = state.copyWith(
          notifications: [item, ...state.notifications],
        );
      } catch (_) {}
    });
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true);
    final response = await ref.read(apiClientProvider).dio.get(
          '/notifications',
          queryParameters: {'page': 1, 'limit': 50},
        );
    final data = response.data['data'];
    final items = (data['data'] as List)
        .map((j) => NotificationItem.fromJson(j as Map<String, dynamic>))
        .toList();
    state = NotificationsState(notifications: items, isLoading: false);
  }

  Future<void> markRead(String id) async {
    await ref.read(apiClientProvider).dio.patch('/notifications/$id/read');
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true, readAt: DateTime.now());
        return n;
      }).toList(),
    );
  }

  Future<void> markAllRead() async {
    await ref.read(apiClientProvider).dio.patch('/notifications/read-all');
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList(),
    );
  }

  Future<void> deleteNotification(String id) async {
    await ref.read(apiClientProvider).dio.delete('/notifications/$id');
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
  }
}

final notificationsNotifierProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
        NotificationsNotifier.new);

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsNotifierProvider).notifications;
  return notifications.where((n) => !n.isRead).length;
});
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
flutter test test/features/notifications/notifications_provider_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/mobile/lib/features/notifications/notifications_provider.dart apps/mobile/test/features/notifications/notifications_provider_test.dart
git commit -m "feat(mobile/notifications): add NotificationsNotifier with WebSocket listener + REST fetch"
```

---

## Task 3: NotificationBell widget
Depends-on: 2

**Files:**
- Create: `lib/features/notifications/notification_bell.dart`
- Create: `test/features/notifications/notification_bell_test.dart`

- [ ] **Step 3.1: Write failing widget test**

```dart
// apps/mobile/test/features/notifications/notification_bell_test.dart
import 'package:expense_tracker/core/api/websocket_client.dart';
import 'package:expense_tracker/features/notifications/notification_bell.dart';
import 'package:expense_tracker/features/notifications/notifications_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<WebSocketClient>()])
import 'notification_bell_test.mocks.dart';

class _FakeNotificationsNotifier extends Notifier<NotificationsState> {
  final int unreadCount;
  _FakeNotificationsNotifier(this.unreadCount);
  @override
  NotificationsState build() => NotificationsState(
        notifications: List.generate(
          unreadCount,
          (i) => throw UnimplementedError(), // count only
        ),
      );
}

void main() {
  late MockWebSocketClient mockWs;

  setUp(() {
    mockWs = MockWebSocketClient();
    when(mockWs.connect()).thenAnswer((_) async {});
    when(mockWs.notificationStream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('shows bell icon', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [webSocketClientProvider.overrideWithValue(mockWs)],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [NotificationBell()]),
        ),
      ),
    ));
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('shows badge with unread count when > 0', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        webSocketClientProvider.overrideWithValue(mockWs),
        unreadCountProvider.overrideWithValue(3),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [NotificationBell()]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides badge when unread count is 0', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        webSocketClientProvider.overrideWithValue(mockWs),
        unreadCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [NotificationBell()]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('0'), findsNothing);
  });
}
```

- [ ] **Step 3.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/notifications/notification_bell_test.dart
```

Expected: FAIL — `Cannot find module 'notification_bell.dart'`

- [ ] **Step 3.3: Implement NotificationBell**

```dart
// apps/mobile/lib/features/notifications/notification_bell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import 'notifications_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push(AppRoutes.notifications),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3.4: Run tests — verify pass**

```bash
flutter test test/features/notifications/notification_bell_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 3.5: Update DashboardScreen to use NotificationBell**

In `lib/features/dashboard/dashboard_screen.dart`, replace the `IconButton` with:

```dart
// Remove:
// IconButton(
//   icon: const Icon(Icons.notifications_outlined),
//   onPressed: () => context.push(AppRoutes.notifications),
// ),

// Replace with:
const NotificationBell(),
```

Add import:
```dart
import '../../features/notifications/notification_bell.dart';
```

- [ ] **Step 3.6: Commit**

```bash
git add apps/mobile/lib/features/notifications/notification_bell.dart apps/mobile/test/features/notifications/notification_bell_test.dart apps/mobile/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat(mobile/notifications): add NotificationBell with unread badge"
```

---

## Task 4: NotificationsScreen
Depends-on: 2

**Files:**
- Create: `lib/features/notifications/notifications_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 4.1: Implement NotificationsScreen**

```dart
// apps/mobile/lib/features/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/models/notification_item.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsNotifierProvider.notifier).fetchNotifications();
    });
  }

  String _buildTitle(NotificationItem item) => switch (item.type) {
        NotificationType.budgetAlert =>
          'Budget Alert — ${item.payload['threshold']}% reached',
        NotificationType.monthlySummary => 'Monthly Summary Ready',
        NotificationType.recurringReminder => 'Recurring Transaction',
        NotificationType.invite => 'Workspace Invitation',
      };

  String _buildSubtitle(NotificationItem item) => switch (item.type) {
        NotificationType.budgetAlert =>
          'Your budget has reached ${item.payload['threshold']}% of its limit.',
        NotificationType.monthlySummary =>
          'View your ${item.payload['period'] ?? ''} summary.',
        NotificationType.recurringReminder =>
          'A recurring transaction was created.',
        NotificationType.invite =>
          'You have been invited to a workspace.',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => ref
                  .read(notificationsNotifierProvider.notifier)
                  .markAllRead(),
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? const Center(child: Text('No notifications yet'))
              : ListView.separated(
                  itemCount: state.notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = state.notifications[index];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => ref
                          .read(notificationsNotifierProvider.notifier)
                          .deleteNotification(item.id),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isRead
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                          child: Icon(
                            switch (item.type) {
                              NotificationType.budgetAlert => Icons.warning_outlined,
                              NotificationType.monthlySummary => Icons.bar_chart,
                              NotificationType.recurringReminder => Icons.repeat,
                              NotificationType.invite => Icons.group_add_outlined,
                            },
                          ),
                        ),
                        title: Text(
                          _buildTitle(item),
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_buildSubtitle(item)),
                            Text(
                              DateFormat.yMMMd().add_jm().format(item.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!item.isRead) {
                            ref
                                .read(notificationsNotifierProvider.notifier)
                                .markRead(item.id);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
```

- [ ] **Step 4.2: Update GoRouter**

In `lib/core/router/app_router.dart`:
```dart
import '../../features/notifications/notifications_screen.dart';

GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
```

- [ ] **Step 4.3: Run full test suite**

```bash
cd apps/mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 4.4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 4.5: Commit**

```bash
git add apps/mobile/lib/features/notifications/ apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/notifications): add NotificationsScreen with mark-read, swipe-to-delete"
```

---

## Phase 9 Complete

- ✅ `WebSocketClient` — socket.io connection to `/notifications`, JWT auth header, broadcast stream
- ✅ **Reconnection logic:** exponential backoff on disconnect (`_onDisconnect`): delays of 2s, 4s, 8s, 16s, 32s for up to 5 attempts; resets counter on successful connect; explicit `disconnect()` stops auto-reconnect
- ✅ **Lifecycle hooks:** `WebSocketClient` implements `WidgetsBindingObserver` — disconnects on `paused`/`detached`, reconnects on `resumed`, no action on `inactive`/`hidden`; `initialize()` called in `NotificationsNotifier.build()`
- ✅ `NotificationsNotifier` — fetches existing list on init, prepends real-time events from WebSocket
- ✅ `unreadCountProvider` — derived from notification list (no extra API call)
- ✅ `NotificationBell` — AppBar widget with red circular badge (hidden when 0)
- ✅ `NotificationsScreen` — list with swipe-to-delete, mark-all-read, type icons, bold for unread
- ✅ `DashboardScreen` — uses `NotificationBell` instead of raw `IconButton`
- ✅ Unit tests: 4 WebSocket + 3 provider = 7 tests; 3 widget tests for bell

**Next plan:** `2026-06-16-flutter-phase10.md` — Flutter CI/CD (GitHub Actions: analyze, test, build web, Vercel deploy)
