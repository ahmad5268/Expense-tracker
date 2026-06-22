import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/features/dashboard/dashboard_provider.dart';
import 'package:expense_tracker/features/dashboard/dashboard_screen.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

// ---------------------------------------------------------------------------
// Stub notifiers — override build() so no network calls are made
// ---------------------------------------------------------------------------

class _StubDashboardNotifier extends DashboardNotifier {
  final DashboardState _initial;
  _StubDashboardNotifier(this._initial);

  @override
  DashboardState build() => _initial;

  @override
  Future<void> load() async {} // no-op: prevents real API calls
}

class _StubWorkspaceNotifier extends WorkspaceNotifier {
  final WorkspaceState _initial;
  _StubWorkspaceNotifier(this._initial);

  @override
  WorkspaceState build() => _initial;

  @override
  Future<void> loadWorkspaces() async {}
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test
// ---------------------------------------------------------------------------

const _testWorkspace = Workspace(
  id: 'w1',
  name: 'My Wallet',
  currency: 'USD',
  ownerId: 'u1',
  members: [],
);

Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    // MaterialApp.router would need a full GoRouter; instead we use a plain
    // MaterialApp and intercept go_router calls with a top-level Navigator so
    // that context.go() / context.pop() calls don't crash.
    child: MaterialApp(
      home: const DashboardScreen(),
    ),
  );
}

ProviderContainer _makeContainer({
  WorkspaceState? workspaceState,
  DashboardState? dashboardState,
}) {
  final ws = workspaceState ?? const WorkspaceState(
    workspaces: [_testWorkspace],
    activeWorkspace: _testWorkspace,
  );
  final dash = dashboardState ?? const DashboardState();

  return ProviderContainer(overrides: [
    workspaceNotifierProvider.overrideWith(() => _StubWorkspaceNotifier(ws)),
    dashboardNotifierProvider.overrideWith(() => _StubDashboardNotifier(dash)),
    // notificationsNotifierProvider has a default build() that returns
    // NotificationsState() with unreadCount=0, so no network call is made.
  ]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading indicator while dashboard is loading',
      (tester) async {
    final container = _makeContainer(
      dashboardState: const DashboardState(isLoading: true),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty workspace state when no active workspace',
      (tester) async {
    final container = _makeContainer(
      workspaceState: const WorkspaceState(), // no active workspace
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    expect(find.text('No workspace yet'), findsOneWidget);
  });

  testWidgets('shows hero balance card with net balance', (tester) async {
    final container = _makeContainer(
      dashboardState: const DashboardState(
        totalIncome: 5000,
        totalExpense: 3000,
        net: 2000,
        isLoading: false,
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    // CurrencyFormatter.format(2000, 'USD') → '$20.00'
    expect(find.text('\$20.00'), findsOneWidget);
    expect(find.text('Net Balance'), findsOneWidget);
  });

  testWidgets('FAB is present when workspace is active', (tester) async {
    final container = _makeContainer(); // default: has active workspace
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('FAB is absent when no active workspace', (tester) async {
    final container = _makeContainer(
      workspaceState: const WorkspaceState(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('workspace name appears in app bar title', (tester) async {
    final container = _makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pump();

    expect(find.text('My Wallet'), findsOneWidget);
  });
}
