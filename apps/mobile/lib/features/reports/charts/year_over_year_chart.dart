import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../reports_provider.dart';

class YearOverYearChart extends ConsumerWidget {
  const YearOverYearChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsNotifierProvider).yearOverYear;

    if (data.isEmpty) {
      return const Center(child: Text('No year-over-year data available'));
    }

    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;

    final thisYearExpense = <int, double>{};
    final lastYearExpense = <int, double>{};
    for (final p in data) {
      if (p.type != 'EXPENSE') continue;
      if (p.month > 1200) {
        thisYearExpense[p.month % 100] = p.total / 100.0;
      } else {
        lastYearExpense[p.month % 100] = p.total / 100.0;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Year Over Year Comparison',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            _Legend(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                label: '$lastYear'),
            const SizedBox(width: 16),
            _Legend(color: const Color(0xFF4F46E5), label: '$currentYear'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                groupsSpace: 12,
                barGroups: List.generate(12, (i) {
                  final m = i + 1;
                  return BarChartGroupData(
                    x: m,
                    barRods: [
                      BarChartRodData(
                        toY: lastYearExpense[m] ?? 0,
                        color:
                            const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: thisYearExpense[m] ?? 0,
                        color: const Color(0xFF4F46E5),
                        width: 8,
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        DateFormat.MMM()
                            .format(DateTime(2026, v.toInt())),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label),
      ]);
}
