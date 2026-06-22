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

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // API returns nested category: { name, icon } and user: { name }.
    // The generated code looks for flat categoryName/categoryIcon keys, so
    // we lift them here before delegating to the generated factory.
    final cat = json['category'] as Map<String, dynamic>?;
    return _$TransactionFromJson({
      ...json,
      if (cat != null) 'categoryName': cat['name'],
      if (cat != null) 'categoryIcon': cat['icon'],
    });
  }
}
