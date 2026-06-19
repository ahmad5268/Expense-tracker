import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_provider.dart';
import 'widgets/summary_card.dart';
import 'widgets/recent_transactions_list.dart';
import '../workspaces/workspace_provider.dart';
import '../notifications/notification_bell.dart';
import '../../core/router/app_router.dart';

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

    // Reload when workspace becomes available (loaded by shell after mount)
    ref.listen(activeWorkspaceProvider, (prev, next) {
      if (next != null && prev?.id != next.id) {
        ref.read(dashboardNotifierProvider.notifier).load();
      }
    });

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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      const Text('No workspace yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      const Text('Create a workspace to get started', style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.workspacesCreate),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Workspace'),
                      ),
                    ],
                  ),
                )
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
