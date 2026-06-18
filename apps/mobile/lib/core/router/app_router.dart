import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';

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

final _authRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

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
  final authListenable = ValueNotifier<AsyncValue<Object?>>(const AsyncLoading());

  ref.listen(authNotifierProvider, (_, next) {
    authListenable.value = next;
  });

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.valueOrNull != null;
      final isOnAuthRoute = _authRoutes.contains(state.matchedLocation);

      if (!isAuthenticated &&
          !isOnAuthRoute &&
          !state.matchedLocation.startsWith('/invite')) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isOnAuthRoute) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.register,
          builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: AppRoutes.inviteAccept,
        builder: (_, state) =>
            _PlaceholderScreen('Accept Invite ${state.pathParameters['token']}'),
      ),
      GoRoute(
          path: AppRoutes.dashboard,
          builder: (_, __) => const _PlaceholderScreen('Dashboard')),
      GoRoute(
          path: AppRoutes.transactions,
          builder: (_, __) => const _PlaceholderScreen('Transactions')),
      GoRoute(
          path: AppRoutes.budgets,
          builder: (_, __) => const _PlaceholderScreen('Budgets')),
      GoRoute(
          path: AppRoutes.recurring,
          builder: (_, __) => const _PlaceholderScreen('Recurring')),
      GoRoute(
          path: AppRoutes.reports,
          builder: (_, __) => const _PlaceholderScreen('Reports')),
      GoRoute(
          path: AppRoutes.notifications,
          builder: (_, __) => const _PlaceholderScreen('Notifications')),
      GoRoute(
          path: AppRoutes.workspaces,
          builder: (_, __) => const _PlaceholderScreen('Workspaces')),
      GoRoute(
        path: AppRoutes.workspaceSettings,
        builder: (_, state) =>
            _PlaceholderScreen('Settings ${state.pathParameters['id']}'),
      ),
    ],
  );
});
