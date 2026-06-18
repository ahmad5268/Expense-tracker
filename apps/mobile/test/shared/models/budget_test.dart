import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/models/budget.dart';

void main() {
  group('Budget model', () {
    test('fromJson parses MONTHLY budget', () {
      final budget = Budget.fromJson({
        'id': 'b1',
        'workspaceId': 'w1',
        'amount': 50000,
        'period': 'MONTHLY',
        'year': 2026,
        'month': 6,
      });
      expect(budget.period, BudgetPeriod.monthly);
      expect(budget.amount, 50000);
      expect(budget.month, 6);
    });

    test('fromJson parses YEARLY budget without month', () {
      final budget = Budget.fromJson({
        'id': 'b2',
        'workspaceId': 'w1',
        'amount': 1200000,
        'period': 'YEARLY',
        'year': 2026,
      });
      expect(budget.period, BudgetPeriod.yearly);
      expect(budget.month, isNull);
    });
  });
}
