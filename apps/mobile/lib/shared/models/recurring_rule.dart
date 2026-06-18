import 'package:freezed_annotation/freezed_annotation.dart';
import 'transaction.dart';

part 'recurring_rule.freezed.dart';
part 'recurring_rule.g.dart';

enum Frequency {
  @JsonValue('DAILY') daily,
  @JsonValue('WEEKLY') weekly,
  @JsonValue('MONTHLY') monthly,
  @JsonValue('YEARLY') yearly,
}

@freezed
class RecurringRule with _$RecurringRule {
  const factory RecurringRule({
    required String id,
    required String workspaceId,
    required String categoryId,
    String? categoryName,
    required int amount,
    required TransactionType type,
    String? description,
    required Frequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    required DateTime nextRunAt,
    required bool isActive,
  }) = _RecurringRule;

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      _$RecurringRuleFromJson(json);
}
