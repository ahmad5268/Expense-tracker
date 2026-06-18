import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/models/workspace.dart';
import '../../../shared/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class RecentTransactionsList extends ConsumerWidget {
  final List<Transaction> transactions;
  final Workspace workspace;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.workspace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No recent transactions'));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isExpense = tx.type == TransactionType.expense;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          title: Text(
            tx.description ?? tx.categoryName ?? 'Transaction',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            DateFormat('MMM d, y').format(tx.date),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          trailing: Text(
            '${isExpense ? '-' : '+'}${CurrencyFormatter.format(tx.amount, workspace.currency)}',
            style: TextStyle(
              color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
