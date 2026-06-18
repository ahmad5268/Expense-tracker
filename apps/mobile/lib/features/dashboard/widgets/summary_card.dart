import 'package:flutter/material.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/models/workspace.dart';

class SummaryCard extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int net;
  final Workspace workspace;

  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.workspace,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row(
              label: 'Income',
              amount: totalIncome,
              color: const Color(0xFF10B981),
              currency: workspace.currency,
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Expenses',
              amount: totalExpense,
              color: const Color(0xFFEF4444),
              currency: workspace.currency,
            ),
            const Divider(color: Colors.white24, height: 24),
            _Row(
              label: 'Net',
              amount: net,
              color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              currency: workspace.currency,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final String currency;

  const _Row({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(
          CurrencyFormatter.format(amount.abs(), currency),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }
}
