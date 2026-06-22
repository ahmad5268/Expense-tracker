import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/budget.dart';
import '../../shared/widgets/amount_field.dart';
import 'budgets_provider.dart';

class CreateEditBudgetSheet extends ConsumerStatefulWidget {
  final Budget? budget;
  const CreateEditBudgetSheet({super.key, this.budget});

  static Future<void> show(BuildContext context, {Budget? budget}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CreateEditBudgetSheet(budget: budget),
      );

  @override
  ConsumerState<CreateEditBudgetSheet> createState() =>
      _CreateEditBudgetSheetState();
}

class _CreateEditBudgetSheetState extends ConsumerState<CreateEditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late String _period;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.budget?.amount ?? 0;
    _amountController = TextEditingController(
      text: initial > 0 ? (initial / 100.0).toStringAsFixed(2) : '',
    );
    _period = widget.budget?.period.name ?? 'monthly';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final amountCents = AmountField.parseCents(_amountController.text);
    final now = DateTime.now();
    try {
      if (widget.budget != null) {
        await ref.read(budgetsNotifierProvider.notifier).updateBudget(
              widget.budget!.id,
              amount: amountCents,
            );
      } else {
        await ref.read(budgetsNotifierProvider.notifier).addBudget(
              amount: amountCents,
              period: _period.toUpperCase(),
              year: now.year,
              month: _period == 'monthly' ? now.month : null,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save budget')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;
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
            Text(isEditing ? 'Edit Budget' : 'New Budget',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (!isEditing)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'yearly', label: Text('Yearly')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            const SizedBox(height: 16),
            AmountField(controller: _amountController, label: 'Budget Amount'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? 'Update Budget' : 'Create Budget'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
