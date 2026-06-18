import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType {
  @JsonValue('EXPENSE') expense,
  @JsonValue('INCOME') income,
}

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String workspaceId,
    required String userId,
    required String categoryId,
    String? categoryName,
    String? categoryIcon,
    required int amount,
    required TransactionType type,
    String? description,
    required DateTime date,
    String? recurringRuleId,
    required DateTime createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
