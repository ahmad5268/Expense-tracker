import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_client.dart';
import '../../shared/models/notification_item.dart';

class NotificationsState {
  final List<NotificationItem> items;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  NotificationsState build() {
    ref.onDispose(() => _sub?.cancel());
    return const NotificationsState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.dio.get('/notifications');
      final items = (response.data['data'] as List)
          .map((j) => NotificationItem.fromJson(j as Map<String, dynamic>))
          .toList();
      final unread = items.where((n) => n.readAt == null).length;
      state = NotificationsState(items: items, unreadCount: unread, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void subscribeToWebSocket(WebSocketClient wsClient) {
    _sub?.cancel();
    _sub = wsClient.events.listen((data) {
      final item = NotificationItem.fromJson(data);
      state = state.copyWith(
        items: [item, ...state.items],
        unreadCount: state.unreadCount + 1,
      );
    });
  }

  Future<void> markAllRead() async {
    await _api.dio.patch('/notifications/read-all');
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(readAt: DateTime.now())).toList(),
      unreadCount: 0,
    );
  }

}

final notificationsNotifierProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);
