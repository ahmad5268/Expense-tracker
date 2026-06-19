import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class TrendsChart extends ConsumerWidget {
  const TrendsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trends = ref.watch(reportsNotifierProvider).trends;

    if (trends.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    final incomeByMonth = <int, double>{};
    final expenseByMonth = <int, double>{};
    for (final p in trends) {
      if (p.type == 'INCOME') {
        incomeByMonth[p.month] = p.total / 100.0;
      } else {
        expenseByMonth[p.month] = p.total / 100.0;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses (last 12 months)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        DateFormat.MMM()
                            .format(DateTime(2026, value.toInt())),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        CurrencyFormatter.compact(value.toInt() * 100),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                        12,
                        (i) => FlSpot(
                            (i + 1).toDouble(), incomeByMonth[i + 1] ?? 0)),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                        12,
                        (i) => FlSpot(
                            (i + 1).toDouble(), expenseByMonth[i + 1] ?? 0)),
                    isCurved: true,
                    color: const Color(0xFFEF4444),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(children: [
            _Legend(color: Color(0xFF10B981), label: 'Income'),
            SizedBox(width: 16),
            _Legend(color: Color(0xFFEF4444), label: 'Expenses'),
          ]),
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
