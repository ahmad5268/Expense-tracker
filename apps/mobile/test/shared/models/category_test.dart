import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/models/category.dart';

void main() {
  group('Category model', () {
    test('fromJson parses EXPENSE type', () {
      final category = Category.fromJson({
        'id': 'c1',
        'workspaceId': 'w1',
        'name': 'Food',
        'icon': 'restaurant',
        'color': '#EF4444',
        'type': 'EXPENSE',
      });
      expect(category.type, CategoryType.expense);
      expect(category.name, 'Food');
    });

    test('fromJson parses INCOME type', () {
      final category = Category.fromJson({
        'id': 'c2',
        'workspaceId': 'w1',
        'name': 'Salary',
        'icon': 'work',
        'color': '#10B981',
        'type': 'INCOME',
      });
      expect(category.type, CategoryType.income);
    });
  });
}
