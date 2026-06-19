import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../features/notifications/notifications_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(workspaceNotifierProvider.notifier).loadWorkspaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) {
      return Scaffold(
        backgroundColor: AppTheme.colorBackground,
        body: Row(
          children: [
            const _Sidebar(),
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    return _MobileShell(child: widget.child);
  }
}

class _MobileShell extends ConsumerWidget {
  final Widget child;
  const _MobileShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final unread = ref.watch(notificationsNotifierProvider.select((s) => s.unreadCount));

    int idx = 0;
    if (location.startsWith('/transactions')) idx = 1;
    if (location.startsWith('/budgets')) idx = 2;
    if (location.startsWith('/reports')) idx = 3;
    if (location.startsWith('/notifications')) idx = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          const routes = [
            AppRoutes.dashboard,
            AppRoutes.transactions,
            AppRoutes.budgets,
            AppRoutes.reports,
            AppRoutes.notifications,
          ];
          context.go(routes[i]);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Budgets'),
          const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications)),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final unread = ref.watch(notificationsNotifierProvider.select((s) => s.unreadCount));
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 220,
      color: AppTheme.colorSidebar,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC))),
                    Text('Tracker', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),

          // Workspace switcher
          Padding(
            padding: const EdgeInsets.all(12),
            child: workspace != null
                ? GestureDetector(
                    onTap: () => context.go(AppRoutes.workspaces),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          _wsAvatar(workspace.name),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              workspace.name,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.unfold_more, color: Color(0xFF475569), size: 14),
                        ],
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => context.go(AppRoutes.workspacesCreate),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFF4F46E5), size: 14),
                          SizedBox(width: 6),
                          Text('Create Workspace', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Navigation
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _NavLabel('MAIN'),
                  _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: AppRoutes.dashboard, location: location),
                  _NavItem(icon: Icons.receipt_long_outlined, label: 'Transactions', route: AppRoutes.transactions, location: location),
                  const _NavLabel('PLANNING'),
                  _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Budgets', route: AppRoutes.budgets, location: location),
                  _NavItem(icon: Icons.repeat_outlined, label: 'Recurring', route: AppRoutes.recurring, location: location),
                  const _NavLabel('ANALYTICS'),
                  _NavItem(icon: Icons.bar_chart_outlined, label: 'Reports', route: AppRoutes.reports, location: location),
                  _NavItem(icon: Icons.notifications_outlined, label: 'Notifications', route: AppRoutes.notifications, location: location, badge: unread > 0 ? unread : null),
                  if (workspace != null) ...[
                    const _NavLabel('WORKSPACE'),
                    _NavItem(icon: Icons.settings_outlined, label: 'Settings', route: '/workspaces/${workspace.id}/settings', location: location),
                    _NavItem(icon: Icons.group_outlined, label: 'Members', route: '/workspaces/${workspace.id}/settings/members', location: location),
                  ],
                ],
              ),
            ),
          ),

          // Footer: user info + logout
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)), overflow: TextOverflow.ellipsis),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 16),
                  tooltip: 'Logout',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wsAvatar(String name) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'W',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  final String text;
  const _NavLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF334155), letterSpacing: 1.5)),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String location;
  final int? badge;

  const _NavItem({required this.icon, required this.label, required this.route, required this.location, this.badge});

  bool get _active => route == '/' ? location == '/' : location.startsWith(route);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _active ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _active ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _active ? Colors.white : const Color(0xFF94A3B8))),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
