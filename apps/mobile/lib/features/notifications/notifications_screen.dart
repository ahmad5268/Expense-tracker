import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notifications_provider.dart';
import '../../shared/models/notification_item.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsNotifierProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _NotificationTile(item: item);
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  const _NotificationTile({required this.item});

  String get _title {
    switch (item.type) {
      case NotificationType.budgetAlert: return 'Budget Alert';
      case NotificationType.recurringReminder: return 'Recurring Reminder';
      case NotificationType.monthlySummary: return 'Monthly Summary';
      case NotificationType.invite: return 'Workspace Invitation';
    }
  }

  IconData get _icon {
    switch (item.type) {
      case NotificationType.budgetAlert: return Icons.warning_amber_rounded;
      case NotificationType.recurringReminder: return Icons.repeat;
      case NotificationType.monthlySummary: return Icons.bar_chart;
      case NotificationType.invite: return Icons.person_add_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.isRead ? null : const Color(0xFF4F46E5).withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          child: Icon(_icon, color: const Color(0xFF4F46E5), size: 20),
        ),
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          DateFormat('MMM d, h:mm a').format(item.createdAt),
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: !item.isRead ? Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
        ) : null,
      ),
    );
  }
}
