import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class BudgetVsActualChart extends ConsumerWidget {
  const BudgetVsActualChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(reportsNotifierProvider).budgetVsActual;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (rows.isEmpty) {
      return const Center(child: Text('No budgets set for this period'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Budget vs Actual',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ...rows.map((row) {
          final pct = row.budgetAmount > 0
              ? (row.actualAmount / row.budgetAmount).clamp(0.0, 1.0)
              : 0.0;
          final color = pct >= 1.0
              ? const Color(0xFFEF4444)
              : pct >= 0.8
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.categoryName ?? 'Total Budget'),
                    Text(
                      '${CurrencyFormatter.format(row.actualAmount, currency)} / ${CurrencyFormatter.format(row.budgetAmount, currency)}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct,
                  color: color,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
