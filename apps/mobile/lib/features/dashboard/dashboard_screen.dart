import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dashboard_provider.dart';
import 'widgets/recent_transactions_list.dart';
import '../workspaces/workspace_provider.dart';
import '../notifications/notification_bell.dart';
import '../transactions/add_transaction_sheet.dart';
import '../../core/router/app_router.dart';
import '../../shared/utils/currency_formatter.dart';

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
      floatingActionButton: workspace != null
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const AddTransactionSheet(),
              ),
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: workspace == null
          ? _EmptyWorkspaceState()
          : dash.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => ref.read(dashboardNotifierProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: [
                      _HeroCard(
                        totalIncome: dash.totalIncome,
                        totalExpense: dash.totalExpense,
                        net: dash.net,
                        currency: workspace.currency,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _StatChip(
                            label: 'Income',
                            amount: dash.totalIncome,
                            color: const Color(0xFF10B981),
                            icon: Icons.arrow_downward_rounded,
                            currency: workspace.currency,
                          ),
                          const SizedBox(width: 12),
                          _StatChip(
                            label: 'Expenses',
                            amount: dash.totalExpense,
                            color: const Color(0xFFEF4444),
                            icon: Icons.arrow_upward_rounded,
                            currency: workspace.currency,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.transactions),
                            child: const Text('See all', style: TextStyle(color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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

class _HeroCard extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int net;
  final String currency;

  const _HeroCard({
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM y').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Net Balance',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(net.abs(), currency),
            style: TextStyle(
              color: net < 0 ? const Color(0xFFFCA5A5) : Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          if (net < 0)
            const Text('over budget', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final String currency;

  const _StatChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(amount, currency),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWorkspaceState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 40, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No workspace yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a workspace to start tracking\nyour income and expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.workspacesCreate),
              icon: const Icon(Icons.add),
              label: const Text('Create Workspace', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
