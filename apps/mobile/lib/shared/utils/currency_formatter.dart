import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(int cents, String currencyCode) {
    final amount = cents / 100.0;
    final formatter = NumberFormat.currency(
      symbol: _symbol(currencyCode),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String _symbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '$code ';
    }
  }
}
