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

  static String compact(int cents) {
    final amount = cents / 100.0;
    if (amount >= 1000000) return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(1)}k';
    return '\$${amount.toStringAsFixed(0)}';
  }
}
