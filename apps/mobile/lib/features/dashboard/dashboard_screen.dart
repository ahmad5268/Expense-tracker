import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';
import 'widgets/summary_card.dart';
import 'widgets/recent_transactions_list.dart';
import '../workspaces/workspace_provider.dart';
import '../notifications/notification_bell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dashboardNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(workspace?.name ?? 'Dashboard', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: dash.isLoading
          ? const Center(child: CircularProgressIndicator())
          : workspace == null
              ? const Center(child: Text('Select a workspace'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(dashboardNotifierProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SummaryCard(
                        totalIncome: dash.totalIncome,
                        totalExpense: dash.totalExpense,
                        net: dash.net,
                        workspace: workspace,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      RecentTransactionsList(
                        transactions: dash.recentTransactions,
                        workspace: workspace,
                      ),
                    ],
                  ),
                ),
    );
  }
}
