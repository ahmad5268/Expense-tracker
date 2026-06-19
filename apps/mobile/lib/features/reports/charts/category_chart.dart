import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class CategoryChart extends ConsumerWidget {
  const CategoryChart({super.key});

  static const _fallbackColors = [
    Color(0xFF5B67CA),
    Color(0xFFE07B54),
    Color(0xFF4CAF50),
    Color(0xFFFFC107),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
    Color(0xFF795548),
  ];

  Color _colorFor(String? hex, int index) {
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return _fallbackColors[index % _fallbackColors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = ref.watch(reportsNotifierProvider).byCategory;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (byCategory.isEmpty) {
      return const Center(child: Text('No expense data for this period'));
    }

    final total = byCategory.fold<int>(0, (sum, c) => sum + c.total);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Expenses by Category',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sections: byCategory.asMap().entries.map((e) {
                  final i = e.key;
                  final cat = e.value;
                  final pct =
                      total > 0 ? (cat.total / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: cat.total.toDouble(),
                    title: '${pct.toStringAsFixed(1)}%',
                    color: _colorFor(cat.color, i),
                    radius: 80,
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...byCategory.asMap().entries.map((e) {
            final i = e.key;
            final cat = e.value;
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                color: _colorFor(cat.color, i),
              ),
              title: Text(cat.categoryName),
              trailing: Text(CurrencyFormatter.format(cat.total, currency)),
              dense: true,
            );
          }),
        ],
      ),
    );
  }
}
