import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

enum NotificationType {
  @JsonValue('BUDGET_ALERT') budgetAlert,
  @JsonValue('RECURRING_REMINDER') recurringReminder,
  @JsonValue('MONTHLY_SUMMARY') monthlySummary,
  @JsonValue('INVITE') invite,
}

@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String userId,
    required NotificationType type,
    required Map<String, dynamic> payload,
    @Default(false) bool isRead,
    DateTime? readAt,
    required DateTime createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
