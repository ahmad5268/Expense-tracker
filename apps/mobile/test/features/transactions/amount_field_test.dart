import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/widgets/amount_field.dart';

void main() {
  testWidgets('AmountField renders with label', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AmountField(controller: controller, label: 'Amount')),
    ));
    expect(find.text('Amount'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('parseCents converts decimal to cents', (tester) async {
    expect(AmountField.parseCents('10.00'), 1000);
    expect(AmountField.parseCents('9.99'), 999);
    expect(AmountField.parseCents('100'), 10000);
  });

  testWidgets('parseCents returns 0 for empty input', (tester) async {
    expect(AmountField.parseCents(''), 0);
    expect(AmountField.parseCents('abc'), 0);
  });
}
