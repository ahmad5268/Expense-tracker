import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

enum BudgetPeriod {
  @JsonValue('MONTHLY') monthly,
  @JsonValue('YEARLY') yearly,
}

@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String workspaceId,
    String? categoryId,
    String? categoryName,
    required int amount,
    required BudgetPeriod period,
    required int year,
    int? month,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
}
