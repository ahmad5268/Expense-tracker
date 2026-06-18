import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePickerField extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTimeRange?> onChanged;

  const DateRangePickerField({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  String get _label {
    if (from == null && to == null) return 'All time';
    final fmt = DateFormat('MMM d');
    if (from != null && to != null) return '${fmt.format(from!)} – ${fmt.format(to!)}';
    if (from != null) return 'From ${fmt.format(from!)}';
    return 'Until ${fmt.format(to!)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: from != null && to != null ? DateTimeRange(start: from!, end: to!) : null,
        );
        onChanged(range);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 18),
              if (from != null || to != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(_label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
