import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/notifications/notification_bell.dart';
import 'package:expense_tracker/features/notifications/notifications_provider.dart';

Widget buildBell(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(appBar: AppBar(actions: const [NotificationBell()])),
    ),
  );
}

void main() {
  testWidgets('shows bell icon', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildBell(container));
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('shows badge when unread count > 0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(notificationsNotifierProvider.notifier).state =
        const NotificationsState(unreadCount: 3);
    await tester.pumpWidget(buildBell(container));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('no badge when unread count is 0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(buildBell(container));
    expect(find.text('0'), findsNothing);
  });
}
