import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/models/recurring_rule.dart';
import 'package:expense_tracker/shared/models/transaction.dart';

void main() {
  group('RecurringRule model', () {
    test('fromJson parses MONTHLY frequency', () {
      final rule = RecurringRule.fromJson({
        'id': 'r1',
        'workspaceId': 'w1',
        'categoryId': 'c1',
        'amount': 150000,
        'type': 'EXPENSE',
        'frequency': 'MONTHLY',
        'startDate': '2026-01-01T00:00:00.000Z',
        'nextRunAt': '2026-07-01T00:00:00.000Z',
        'isActive': true,
      });
      expect(rule.frequency, Frequency.monthly);
      expect(rule.type, TransactionType.expense);
      expect(rule.isActive, isTrue);
    });
  });
}
