import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats USD cents to dollar string', () {
      expect(CurrencyFormatter.format(1000, 'USD'), r'$10.00');
    });

    test('formats EUR cents', () {
      expect(CurrencyFormatter.format(2550, 'EUR'), '€25.50');
    });

    test('formats GBP cents', () {
      expect(CurrencyFormatter.format(500, 'GBP'), '£5.00');
    });

    test('zero cents formats as zero', () {
      expect(CurrencyFormatter.format(0, 'USD'), r'$0.00');
    });

    test('large amount formats correctly', () {
      expect(CurrencyFormatter.format(100000, 'USD'), r'$1,000.00');
    });

    test('unknown currency uses code as prefix', () {
      final result = CurrencyFormatter.format(500, 'KWD');
      expect(result, contains('KWD'));
    });
  });
}
