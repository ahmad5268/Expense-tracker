import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/features/dashboard/widgets/budget_progress_bar.dart';

void main() {
  testWidgets('shows green bar when under 80%', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetProgressBar(label: 'Food', spent: 50, budget: 100, currency: 'USD')),
    ));
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('shows warning amber at 80-99%', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetProgressBar(label: 'Bills', spent: 85, budget: 100, currency: 'USD')),
    ));
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('shows red bar at 100% or over', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BudgetProgressBar(label: 'Over', spent: 120, budget: 100, currency: 'USD')),
    ));
    expect(find.text('100%'), findsOneWidget);
  });
}
