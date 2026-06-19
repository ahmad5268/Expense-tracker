import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsNotifierProvider);
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
            label: 'Total Income',
            value: CurrencyFormatter.format(state.totalIncome, currency),
            color: const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _StatCard(
            label: 'Total Expenses',
            value: CurrencyFormatter.format(state.totalExpense, currency),
            color: const Color(0xFFEF4444)),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Net Balance',
          value: CurrencyFormatter.format(state.net, currency),
          color: state.net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      );
}
