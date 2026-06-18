import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/models/transaction.dart';

void main() {
  group('Transaction model', () {
    test('fromJson parses amount as int (cents)', () {
      final tx = Transaction.fromJson({
        'id': 't1',
        'workspaceId': 'w1',
        'userId': 'u1',
        'categoryId': 'c1',
        'amount': 4999,
        'type': 'EXPENSE',
        'date': '2026-06-01T00:00:00.000Z',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(tx.amount, 4999);
      expect(tx.type, TransactionType.expense);
    });

    test('amount is never a float', () {
      final tx = Transaction.fromJson({
        'id': 't2',
        'workspaceId': 'w1',
        'userId': 'u1',
        'categoryId': 'c1',
        'amount': 100,
        'type': 'INCOME',
        'date': '2026-06-01T00:00:00.000Z',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(tx.amount, isA<int>());
    });
  });
}
