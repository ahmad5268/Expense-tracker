import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transactions_provider.dart';
import 'add_transaction_sheet.dart';
import 'widgets/transaction_list_item.dart';
import '../workspaces/workspace_provider.dart';
import '../../shared/models/transaction.dart';
import '../../shared/widgets/date_range_picker_field.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(transactionsNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => const AddTransactionSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _FilterBar(state: state),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
                            const SizedBox(height: 8),
                            Text(state.error!, textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(transactionsNotifierProvider.notifier).load(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                : state.transactions.isEmpty
                    ? const Center(child: Text('No transactions found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: state.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = state.transactions[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: TransactionListItem(
                              transaction: tx,
                              currency: workspace?.currency ?? 'USD',
                              onDelete: () => ref.read(transactionsNotifierProvider.notifier).delete(tx.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final TransactionsState state;
  const _FilterBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = state.filter;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          DateRangePickerField(
            from: filter.from,
            to: filter.to,
            onChanged: (range) => ref.read(transactionsNotifierProvider.notifier).setFilter(
                  filter.copyWith(
                    from: range?.start,
                    to: range?.end,
                    clearFrom: range == null,
                    clearTo: range == null,
                  ),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeChip(label: 'All', isSelected: filter.type == null, onTap: () {
                ref.read(transactionsNotifierProvider.notifier).setFilter(filter.copyWith(clearType: true));
              }),
              const SizedBox(width: 8),
              _TypeChip(label: 'Expense', isSelected: filter.type == TransactionType.expense, onTap: () {
                ref.read(transactionsNotifierProvider.notifier).setFilter(filter.copyWith(type: TransactionType.expense));
              }),
              const SizedBox(width: 8),
              _TypeChip(label: 'Income', isSelected: filter.type == TransactionType.income, onTap: () {
                ref.read(transactionsNotifierProvider.notifier).setFilter(filter.copyWith(type: TransactionType.income));
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
