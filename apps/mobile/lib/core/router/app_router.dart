import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Route paths — single source of truth
class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const inviteAccept = '/invite/:token';
  static const dashboard = '/';
  static const transactions = '/transactions';
  static const budgets = '/budgets';
  static const recurring = '/recurring';
  static const reports = '/reports';
  static const notifications = '/notifications';
  static const workspaces = '/workspaces';
  static const workspaceSettings = '/workspaces/:id/settings';
}

// Temporary placeholder screen for route stubs
class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen(this.name);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: Text(name)),
      );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Auth redirect will be wired in Phase 2 once AuthProvider exists.
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const _PlaceholderScreen('Login'),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const _PlaceholderScreen('Register'),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const _PlaceholderScreen('Forgot Password'),
      ),
      GoRoute(
        path: AppRoutes.inviteAccept,
        builder: (_, state) => _PlaceholderScreen(
            'Accept Invite ${state.pathParameters['token']}'),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const _PlaceholderScreen('Dashboard'),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (_, __) => const _PlaceholderScreen('Transactions'),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        builder: (_, __) => const _PlaceholderScreen('Budgets'),
      ),
      GoRoute(
        path: AppRoutes.recurring,
        builder: (_, __) => const _PlaceholderScreen('Recurring'),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, __) => const _PlaceholderScreen('Reports'),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const _PlaceholderScreen('Notifications'),
      ),
      GoRoute(
        path: AppRoutes.workspaces,
        builder: (_, __) => const _PlaceholderScreen('Workspaces'),
      ),
      GoRoute(
        path: AppRoutes.workspaceSettings,
        builder: (_, state) => _PlaceholderScreen(
            'Workspace Settings ${state.pathParameters['id']}'),
      ),
    ],
  );
});
