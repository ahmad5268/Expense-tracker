import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/categories/categories_provider.dart';
import '../../shared/models/recurring_rule.dart';
import '../../shared/widgets/amount_field.dart';
import '../../shared/widgets/category_picker.dart';
import 'recurring_provider.dart';

class CreateEditRecurringSheet extends ConsumerStatefulWidget {
  final RecurringRule? rule;
  const CreateEditRecurringSheet({super.key, this.rule});

  static Future<void> show(BuildContext context, {RecurringRule? rule}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CreateEditRecurringSheet(rule: rule),
      );

  @override
  ConsumerState<CreateEditRecurringSheet> createState() =>
      _CreateEditRecurringSheetState();
}

class _CreateEditRecurringSheetState
    extends ConsumerState<CreateEditRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late String _frequency;
  late String _type;
  String? _selectedCategoryId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.rule?.amount ?? 0;
    _amountController = TextEditingController(
      text: initial > 0 ? (initial / 100.0).toStringAsFixed(2) : '',
    );
    _frequency = widget.rule?.frequency.name ?? 'monthly';
    _type = widget.rule?.type.name ?? 'expense';
    _selectedCategoryId = widget.rule?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    setState(() => _loading = true);
    final amountCents = AmountField.parseCents(_amountController.text);
    try {
      if (widget.rule == null) {
        await ref.read(recurringNotifierProvider.notifier).addRule(
              categoryId: _selectedCategoryId!,
              amount: amountCents,
              type: _type,
              frequency: _frequency,
              startDate: DateTime.now(),
            );
      } else {
        await ref.read(recurringNotifierProvider.notifier).updateRule(
              widget.rule!.id,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save rule')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.rule != null ? 'Edit Rule' : 'New Recurring Rule',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) => CategoryPicker(
                categories: categories
                    .where((c) => c.type.name == _type)
                    .toList(),
                selectedId: _selectedCategoryId,
                onSelected: (id) => setState(() => _selectedCategoryId = id),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load categories'),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _amountController, label: 'Amount'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: ['daily', 'weekly', 'monthly', 'yearly']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.rule != null ? 'Update Rule' : 'Create Rule'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
