import 'package:flutter/material.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final VoidCallback? onDelete;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.currency,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense
            ? const Color(0xFFEF4444).withValues(alpha: 0.1)
            : const Color(0xFF10B981).withValues(alpha: 0.1),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          size: 18,
        ),
      ),
      title: Text(
        transaction.description ?? transaction.categoryName ?? 'Transaction',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        DateFormat('MMM d, y').format(transaction.date),
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isExpense ? '-' : '+'}${CurrencyFormatter.format(transaction.amount, currency)}',
            style: TextStyle(
              color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
