import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;

  const AmountField({super.key, required this.controller, this.label});

  static int parseCents(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(cleaned) ?? 0;
    return (amount * 100).round();
  }

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(
        labelText: widget.label ?? 'Amount',
        prefixText: '\$ ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Amount is required';
        final cents = AmountField.parseCents(value);
        if (cents <= 0) return 'Amount must be positive';
        return null;
      },
    );
  }
}
