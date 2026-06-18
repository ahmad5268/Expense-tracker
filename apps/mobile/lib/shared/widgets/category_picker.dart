import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = cat.id == selectedId;
        return ChoiceChip(
          label: Text(cat.name),
          selected: isSelected,
          onSelected: (_) => onSelected(cat.id),
          selectedColor: const Color(0xFF4F46E5),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }
}
