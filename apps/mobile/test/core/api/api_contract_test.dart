// API contract tests: verify that every model's fromJson() can parse the exact
// shape that the NestJS backend sends.  These tests have zero network I/O.

import 'package:expense_tracker/shared/models/budget.dart';
import 'package:expense_tracker/shared/models/transaction.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -----------------------------------------------------------------------
  // Transaction
  // -----------------------------------------------------------------------
  group('API contract: Transaction', () {
    // Minimal payload the API sends for an expense transaction.
    final Map<String, dynamic> expenseJson = {
      'id': 'uuid-1',
      'workspaceId': 'ws-1',
      'userId': 'u-1',
      'categoryId': 'cat-1',
      'categoryName': 'Food',
      'categoryIcon': '🍔',
      'amount': 5000, // Always an integer (cents)
      'type': 'EXPENSE',
      'date': '2026-06-01T00:00:00.000Z',
      'description': 'Lunch',
      'recurringRuleId': null,
      'createdAt': '2026-06-01T00:00:00.000Z',
    };

    test('fromJson accepts full EXPENSE payload', () {
      expect(() => Transaction.fromJson(expenseJson), returnsNormally);
      final tx = Transaction.fromJson(expenseJson);
      expect(tx.id, 'uuid-1');
      expect(tx.workspaceId, 'ws-1');
      expect(tx.userId, 'u-1');
      expect(tx.categoryId, 'cat-1');
      expect(tx.categoryName, 'Food');
      expect(tx.amount, 5000);
      expect(tx.type, TransactionType.expense);
      expect(tx.description, 'Lunch');
      expect(tx.recurringRuleId, isNull);
    });

    test('amount is stored as int, never a double', () {
      final tx = Transaction.fromJson(expenseJson);
      expect(tx.amount, isA<int>());
      expect(tx.amount, isNot(isA<double>()));
      expect(tx.amount, 5000);
    });

    test('fromJson accepts INCOME type', () {
      final incomeJson = {
        ...expenseJson,
        'type': 'INCOME',
        'description': null,
        'recurringRuleId': null,
      };
      final tx = Transaction.fromJson(incomeJson);
      expect(tx.type, TransactionType.income);
    });

    test('fromJson accepts optional fields as null', () {
      final minimalJson = {
        'id': 'uuid-2',
        'workspaceId': 'ws-1',
        'userId': 'u-1',
        'categoryId': 'cat-1',
        'categoryName': null,
        'categoryIcon': null,
        'amount': 1000,
        'type': 'EXPENSE',
        'date': '2026-06-01T00:00:00.000Z',
        'description': null,
        'recurringRuleId': null,
        'createdAt': '2026-06-01T00:00:00.000Z',
      };
      expect(() => Transaction.fromJson(minimalJson), returnsNormally);
      final tx = Transaction.fromJson(minimalJson);
      expect(tx.description, isNull);
      expect(tx.categoryName, isNull);
      expect(tx.recurringRuleId, isNull);
    });

    test('date is parsed as DateTime', () {
      final tx = Transaction.fromJson(expenseJson);
      expect(tx.date, isA<DateTime>());
      expect(tx.createdAt, isA<DateTime>());
    });
  });

  // -----------------------------------------------------------------------
  // Budget
  // -----------------------------------------------------------------------
  group('API contract: Budget', () {
    final Map<String, dynamic> monthlyBudgetJson = {
      'id': 'b-1',
      'workspaceId': 'ws-1',
      'categoryId': 'cat-1',
      'categoryName': 'Food',
      'amount': 50000, // 500.00 in cents
      'period': 'MONTHLY',
      'year': 2026,
      'month': 6,
    };

    test('fromJson accepts MONTHLY budget with category', () {
      expect(() => Budget.fromJson(monthlyBudgetJson), returnsNormally);
      final b = Budget.fromJson(monthlyBudgetJson);
      expect(b.id, 'b-1');
      expect(b.workspaceId, 'ws-1');
      expect(b.categoryId, 'cat-1');
      expect(b.categoryName, 'Food');
      expect(b.amount, 50000);
      expect(b.period, BudgetPeriod.monthly);
      expect(b.year, 2026);
      expect(b.month, 6);
    });

    test('amount is stored as int', () {
      final b = Budget.fromJson(monthlyBudgetJson);
      expect(b.amount, isA<int>());
    });

    test('fromJson accepts YEARLY budget without category', () {
      final yearlyJson = {
        'id': 'b-2',
        'workspaceId': 'ws-1',
        'categoryId': null,
        'categoryName': null,
        'amount': 600000,
        'period': 'YEARLY',
        'year': 2026,
        'month': null,
      };
      expect(() => Budget.fromJson(yearlyJson), returnsNormally);
      final b = Budget.fromJson(yearlyJson);
      expect(b.period, BudgetPeriod.yearly);
      expect(b.month, isNull);
      expect(b.categoryId, isNull);
      expect(b.categoryName, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // User
  // -----------------------------------------------------------------------
  group('API contract: User', () {
    final Map<String, dynamic> userJson = {
      'id': 'u-1',
      'email': 'a@b.com',
      'name': 'Ali',
      'avatarUrl': null,
      'oauthProvider': null,
    };

    test('fromJson accepts API response shape', () {
      expect(() => User.fromJson(userJson), returnsNormally);
      final u = User.fromJson(userJson);
      expect(u.id, 'u-1');
      expect(u.email, 'a@b.com');
      expect(u.name, 'Ali');
      expect(u.avatarUrl, isNull);
      expect(u.oauthProvider, isNull);
    });

    test('fromJson accepts user with avatarUrl and oauthProvider set', () {
      final fullJson = {
        'id': 'u-2',
        'email': 'b@c.com',
        'name': 'Bob',
        'avatarUrl': 'https://example.com/avatar.png',
        'oauthProvider': 'google',
      };
      final u = User.fromJson(fullJson);
      expect(u.avatarUrl, 'https://example.com/avatar.png');
      expect(u.oauthProvider, 'google');
    });
  });

  // -----------------------------------------------------------------------
  // Workspace
  // -----------------------------------------------------------------------
  group('API contract: Workspace', () {
    final Map<String, dynamic> workspaceJson = {
      'id': 'ws-1',
      'name': 'Acme',
      'currency': 'USD',
      'ownerId': 'u-1',
      'members': [
        {
          'userId': 'u-1',
          'name': 'Ali',
          'avatarUrl': null,
          'role': 'OWNER',
        },
        {
          'userId': 'u-2',
          'name': 'Bob',
          'avatarUrl': 'https://example.com/bob.png',
          'role': 'MEMBER',
        },
      ],
    };

    test('fromJson accepts workspace with members', () {
      expect(() => Workspace.fromJson(workspaceJson), returnsNormally);
      final ws = Workspace.fromJson(workspaceJson);
      expect(ws.id, 'ws-1');
      expect(ws.name, 'Acme');
      expect(ws.currency, 'USD');
      expect(ws.ownerId, 'u-1');
      expect(ws.members.length, 2);
    });

    test('fromJson accepts workspace with empty members list', () {
      final json = {
        'id': 'ws-2',
        'name': 'Empty',
        'currency': 'EUR',
        'ownerId': 'u-1',
        'members': <dynamic>[],
      };
      final ws = Workspace.fromJson(json);
      expect(ws.members, isEmpty);
    });

    test('WorkspaceMember roles are parsed correctly', () {
      final ws = Workspace.fromJson(workspaceJson);
      expect(ws.members[0].role, MemberRole.owner);
      expect(ws.members[1].role, MemberRole.member);
    });

    test('WorkspaceMember fromJson accepts null avatarUrl', () {
      final memberJson = {
        'userId': 'u-3',
        'name': 'Carol',
        'avatarUrl': null,
        'role': 'ADMIN',
      };
      expect(() => WorkspaceMember.fromJson(memberJson), returnsNormally);
      final m = WorkspaceMember.fromJson(memberJson);
      expect(m.role, MemberRole.admin);
      expect(m.avatarUrl, isNull);
    });
  });
}
