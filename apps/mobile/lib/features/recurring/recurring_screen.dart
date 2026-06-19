import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/utils/currency_formatter.dart';
import 'recurring_provider.dart';
import 'create_edit_recurring_sheet.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringNotifierProvider.notifier).fetchRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(recurringNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: rules.isEmpty
          ? const Center(child: Text('No recurring rules yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rule.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.repeat,
                      color: rule.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(rule.categoryName ?? 'Unknown Category'),
                  subtitle: Text(
                    '${rule.frequency.name} · Next: ${DateFormat.MMMd().format(rule.nextRunAt)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(rule.amount, currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rule.type.name == 'expense'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'toggle') {
                            await ref
                                .read(recurringNotifierProvider.notifier)
                                .updateRule(rule.id, isActive: !rule.isActive);
                          } else if (action == 'delete') {
                            await ref
                                .read(recurringNotifierProvider.notifier)
                                .deleteRule(rule.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(rule.isActive ? 'Pause' : 'Resume'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => CreateEditRecurringSheet.show(context, rule: rule),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateEditRecurringSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }
}
