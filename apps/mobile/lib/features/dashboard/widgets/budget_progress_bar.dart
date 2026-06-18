import 'package:flutter/material.dart';

class BudgetProgressBar extends StatelessWidget {
  final String label;
  final int spent;
  final int budget;
  final String currency;

  const BudgetProgressBar({
    super.key,
    required this.label,
    required this.spent,
    required this.budget,
    required this.currency,
  });

  double get ratio => budget == 0 ? 0 : spent / budget;

  Color get barColor {
    if (ratio >= 1.0) return const Color(0xFFEF4444);
    if (ratio >= 0.8) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
