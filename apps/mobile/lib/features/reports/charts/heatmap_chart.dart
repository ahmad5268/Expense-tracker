import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class HeatmapChart extends ConsumerWidget {
  const HeatmapChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmap = ref.watch(reportsNotifierProvider).heatmap;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (heatmap.isEmpty) {
      return const Center(child: Text('No spending data available'));
    }

    final dataByDay = {for (final d in heatmap) d.day: d.total};
    final maxTotal = heatmap.map((d) => d.total).reduce(math.max);

    final year = DateTime.parse(heatmap.first.day).year;
    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);
    final totalDays = dec31.difference(jan1).inDays + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Spending Heatmap ($year)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Darker = more spending',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: totalDays,
            itemBuilder: (context, index) {
              final day = jan1.add(Duration(days: index));
              final key = DateFormat('yyyy-MM-dd').format(day);
              final total = dataByDay[key] ?? 0;
              final intensity = maxTotal > 0 ? total / maxTotal : 0.0;
              return Tooltip(
                message: '$key: ${CurrencyFormatter.format(total, currency)}',
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
