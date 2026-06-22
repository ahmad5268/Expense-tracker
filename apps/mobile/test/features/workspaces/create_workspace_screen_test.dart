import 'package:expense_tracker/features/workspaces/create_workspace_screen.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake notifier that records calls and never touches the network.
class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  bool createCalled = false;
  String? lastCreatedName;
  String? lastCreatedCurrency;

  @override
  WorkspaceState build() => const WorkspaceState();

  @override
  Future<Workspace> createWorkspace({
    required String name,
    required String currency,
  }) async {
    createCalled = true;
    lastCreatedName = name;
    lastCreatedCurrency = currency;
    const ws = Workspace(
      id: 'new-ws',
      name: 'Test',
      currency: 'USD',
      ownerId: 'u1',
    );
    state = WorkspaceState(workspaces: [ws], activeWorkspace: ws);
    return ws;
  }
}

// Wraps the screen in a MaterialApp without GoRouter so we can test widgets
// in isolation; context.go('/') would otherwise throw.
Widget _buildSubject(_FakeWorkspaceNotifier notifier) {
  return ProviderScope(
    overrides: [
      workspaceNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      home: Builder(
        // A Navigator-based wrapper so GoRouter's context.go does not crash.
        builder: (context) => const CreateWorkspaceScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWorkspaceNotifier fakeNotifier;

  setUp(() => fakeNotifier = _FakeWorkspaceNotifier());

  testWidgets('shows name and currency input fields', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeNotifier));

    // Name field – identified by the label text used in InputDecoration.
    expect(find.widgetWithText(TextFormField, 'Workspace Name'), findsOneWidget);
    // Currency selector rendered as a DropdownButtonFormField.
    expect(
      find.widgetWithText(DropdownButtonFormField<String>, 'Currency'),
      findsOneWidget,
    );
    // Submit button.
    expect(find.widgetWithText(ElevatedButton, 'Create Workspace'),
        findsOneWidget);
  });

  testWidgets('shows validation error when name is empty on submit',
      (tester) async {
    await tester.pumpWidget(_buildSubject(fakeNotifier));

    // Tap submit without filling in the name.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Workspace'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(fakeNotifier.createCalled, isFalse);
  });

  testWidgets('calls createWorkspace with trimmed name and selected currency',
      (tester) async {
    await tester.pumpWidget(_buildSubject(fakeNotifier));

    // Fill in the name field.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Workspace Name'),
      '  My Workspace  ',
    );

    // Submit the form.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Workspace'));
    await tester.pump();

    expect(fakeNotifier.createCalled, isTrue);
    expect(fakeNotifier.lastCreatedName, 'My Workspace');
    // Default currency is USD.
    expect(fakeNotifier.lastCreatedCurrency, 'USD');
  });

  testWidgets('does not call createWorkspace when name is whitespace only',
      (tester) async {
    await tester.pumpWidget(_buildSubject(fakeNotifier));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Workspace Name'),
      '   ',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Workspace'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    expect(fakeNotifier.createCalled, isFalse);
  });
}
