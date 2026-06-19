import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../features/dashboard/widgets/budget_progress_bar.dart';
import 'budgets_provider.dart';
import 'create_edit_budget_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(budgetsNotifierProvider.notifier).fetchBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetsNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.budgets.isEmpty
              ? const Center(child: Text('No budgets yet. Tap + to add one.'))
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(budgetsNotifierProvider.notifier).fetchBudgets(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.budgets.length,
                    itemBuilder: (context, index) {
                      final budget = state.budgets[index];
                      final spent = state.spentFor(budget.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    budget.categoryName ?? 'Total Budget',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            CreateEditBudgetSheet.show(
                                                context, budget: budget),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => ref
                                            .read(budgetsNotifierProvider.notifier)
                                            .deleteBudget(budget.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              BudgetProgressBar(
                                label: budget.period.name,
                                spent: spent,
                                budget: budget.amount,
                                currency: currency,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateEditBudgetSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Budget'),
      ),
    );
  }
}
