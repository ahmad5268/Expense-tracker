import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/features/dashboard/widgets/summary_card.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

void main() {
  const workspace = Workspace(id: 'w1', name: 'Test', currency: 'USD', ownerId: 'u1', members: []);

  testWidgets('shows income, expense, and net rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          totalIncome: 100000,
          totalExpense: 60000,
          net: 40000,
          workspace: workspace,
        ),
      ),
    ));
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net'), findsOneWidget);
  });

  testWidgets('shows formatted amounts in USD', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          totalIncome: 100000,
          totalExpense: 60000,
          net: 40000,
          workspace: workspace,
        ),
      ),
    ));
    expect(find.textContaining('1,000'), findsWidgets);
  });
}
