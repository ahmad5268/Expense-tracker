import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/workspaces/workspaces_screen.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

class _StubWorkspaceNotifier extends WorkspaceNotifier {
  final WorkspaceState _initial;
  _StubWorkspaceNotifier(this._initial);

  @override
  WorkspaceState build() => _initial;

  @override
  Future<void> loadWorkspaces() async {}
}

Widget buildTestApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: WorkspacesScreen()),
  );
}

void main() {
  testWidgets('shows workspace cards after loading', (tester) async {
    const ws = Workspace(id: 'w1', name: 'Acme', currency: 'USD', ownerId: 'u1', members: []);
    final container = ProviderContainer(overrides: [
      workspaceNotifierProvider.overrideWith(
        () => _StubWorkspaceNotifier(const WorkspaceState(
          workspaces: [ws],
          activeWorkspace: ws,
        )),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestApp(container));
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
  });

  testWidgets('shows empty state when no workspaces', (tester) async {
    final container = ProviderContainer(overrides: [
      workspaceNotifierProvider.overrideWith(
        () => _StubWorkspaceNotifier(const WorkspaceState()),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestApp(container));
    await tester.pump();
    expect(find.text('No workspaces yet'), findsOneWidget);
  });

  testWidgets('active workspace shows Active chip', (tester) async {
    const ws = Workspace(id: 'w1', name: 'Acme', currency: 'USD', ownerId: 'u1', members: []);
    final container = ProviderContainer(overrides: [
      workspaceNotifierProvider.overrideWith(
        () => _StubWorkspaceNotifier(const WorkspaceState(
          workspaces: [ws],
          activeWorkspace: ws,
        )),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestApp(container));
    await tester.pump();
    expect(find.text('Active'), findsOneWidget);
  });
}
