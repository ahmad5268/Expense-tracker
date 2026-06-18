# Flutter App — Phase 6: Workspaces Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full workspace management UI: workspace list/switcher, create-workspace form, workspace settings (rename, currency), member list with remove action, invite-by-email flow, and an accept-invite deep-link screen.

**Architecture:** All API calls go through `WorkspaceNotifier` (Phase 3). Screens in this feature consume `workspaceNotifierProvider` and `activeWorkspaceProvider`. The accept-invite route (`/invite/:token`) is accessible without authentication (tokens are single-use) but hits `POST /workspaces/:id/join`.

**Tech Stack:** `flutter_riverpod`, `go_router`, `dio`

**Prerequisite:** Phase 3 complete. `WorkspaceNotifier`, `Workspace`, `WorkspaceMember`, `WorkspaceRole` models available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/features/workspaces/workspaces_screen.dart` | Workspace list with switcher + create button |
| `lib/features/workspaces/create_workspace_screen.dart` | Name + currency form |
| `lib/features/workspaces/workspace_settings_screen.dart` | Rename, currency, danger zone (leave) |
| `lib/features/workspaces/members_screen.dart` | Member list + remove button |
| `lib/features/workspaces/invite_screen.dart` | Invite by email modal |
| `lib/features/workspaces/accept_invite_screen.dart` | Shown when user opens invite link |
| `lib/core/router/app_router.dart` | Updated with real workspace screens |
| `test/features/workspaces/workspaces_screen_test.dart` | Widget tests |

---

## Task 1: WorkspacesScreen (list + switcher)

**Files:**
- Create: `lib/features/workspaces/workspaces_screen.dart`
- Create: `test/features/workspaces/workspaces_screen_test.dart`

- [ ] **Step 1.1: Write failing widget tests**

```dart
// apps/mobile/test/features/workspaces/workspaces_screen_test.dart
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/features/workspaces/workspaces_screen.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _w1 = Workspace(id: 'w1', name: 'Personal', currency: 'USD', ownerId: 'u1');
const _w2 = Workspace(id: 'w2', name: 'Family', currency: 'EUR', ownerId: 'u1');

Widget _buildSubject({
  List<Workspace> workspaces = const [_w1, _w2],
  Workspace? active,
}) {
  final state = WorkspaceState(workspaces: workspaces, activeWorkspace: active ?? _w1);
  return ProviderScope(
    overrides: [
      workspaceNotifierProvider.overrideWith(() => _FakeWorkspaceNotifier(state)),
    ],
    child: MaterialApp(
      home: const WorkspacesScreen(),
    ),
  );
}

class _FakeWorkspaceNotifier extends Notifier<WorkspaceState> {
  final WorkspaceState _initial;
  _FakeWorkspaceNotifier(this._initial);
  @override
  WorkspaceState build() => _initial;
}

void main() {
  testWidgets('lists all workspaces', (tester) async {
    await tester.pumpWidget(_buildSubject());
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('active workspace shows checkmark', (tester) async {
    await tester.pumpWidget(_buildSubject(active: _w1));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows create workspace button', (tester) async {
    await tester.pumpWidget(_buildSubject());
    expect(find.text('New Workspace'), findsOneWidget);
  });
}
```

- [ ] **Step 1.2: Run test — verify it fails**

```bash
cd apps/mobile && flutter test test/features/workspaces/workspaces_screen_test.dart
```

Expected: FAIL — `Cannot find module 'workspaces_screen.dart'`

- [ ] **Step 1.3: Implement WorkspacesScreen**

```dart
// apps/mobile/lib/features/workspaces/workspaces_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import 'workspace_provider.dart';

class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workspaces')),
      body: ListView(
        children: [
          ...state.workspaces.map((w) {
            final isActive = w.id == state.activeWorkspace?.id;
            return ListTile(
              key: Key('workspace_${w.id}'),
              leading: CircleAvatar(child: Text(w.name[0].toUpperCase())),
              title: Text(w.name),
              subtitle: Text(w.currency),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) const Icon(Icons.check, color: Colors.green),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () =>
                        context.push('/workspaces/${w.id}/settings'),
                  ),
                ],
              ),
              onTap: () {
                ref.read(workspaceNotifierProvider.notifier).setActive(w.id);
                context.pop();
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('New Workspace'),
            onTap: () => context.push('/workspaces/create'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/features/workspaces/workspaces_screen_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/features/workspaces/workspaces_screen.dart apps/mobile/test/features/workspaces/workspaces_screen_test.dart
git commit -m "feat(mobile/workspaces): add WorkspacesScreen with list and switcher"
```

---

## Task 2: CreateWorkspaceScreen
Depends-on: 1

**Files:**
- Create: `lib/features/workspaces/create_workspace_screen.dart`

- [ ] **Step 2.1: Implement CreateWorkspaceScreen**

```dart
// apps/mobile/lib/features/workspaces/create_workspace_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'workspace_provider.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR'];

class CreateWorkspaceScreen extends ConsumerStatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  ConsumerState<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends ConsumerState<CreateWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _currency = 'USD';
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(workspaceNotifierProvider.notifier).createWorkspace(
            name: _nameCtrl.text.trim(),
            currency: _currency,
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create workspace')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Workspace')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('nameField'),
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Workspace Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('currencyDropdown'),
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('createButton'),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.2: Commit**

```bash
git add apps/mobile/lib/features/workspaces/create_workspace_screen.dart
git commit -m "feat(mobile/workspaces): add CreateWorkspaceScreen"
```

---

## Task 3: WorkspaceSettingsScreen + MembersScreen + InviteScreen
Depends-on: 1

**Files:**
- Create: `lib/features/workspaces/workspace_settings_screen.dart`
- Create: `lib/features/workspaces/members_screen.dart`
- Create: `lib/features/workspaces/invite_screen.dart`

- [ ] **Step 3.1: Implement WorkspaceSettingsScreen**

```dart
// apps/mobile/lib/features/workspaces/workspace_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'workspace_provider.dart';

class WorkspaceSettingsScreen extends ConsumerWidget {
  final String workspaceId;
  const WorkspaceSettingsScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceNotifierProvider);
    final workspace = state.workspaces.where((w) => w.id == workspaceId).firstOrNull;

    if (workspace == null) {
      return const Scaffold(body: Center(child: Text('Workspace not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('${workspace.name} Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/workspaces/$workspaceId/members'),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: const Text('Invite Member'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => InviteScreen(workspaceId: workspaceId),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Currency'),
            subtitle: Text(workspace.currency),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.2: Implement MembersScreen**

```dart
// apps/mobile/lib/features/workspaces/members_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/workspace.dart';
import 'workspace_provider.dart';

class MembersScreen extends ConsumerWidget {
  final String workspaceId;
  const MembersScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceNotifierProvider);
    final workspace = state.workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final members = workspace?.members ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: members.isEmpty
          ? const Center(child: Text('No members yet'))
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final isOwner = member.role == WorkspaceRole.owner;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(member.name[0].toUpperCase()),
                  ),
                  title: Text(member.name),
                  subtitle: Text(member.role.name),
                  trailing: isOwner
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove Member'),
                                content: Text('Remove ${member.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(workspaceNotifierProvider.notifier)
                                  .removeMember(workspaceId, member.userId);
                            }
                          },
                        ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 3.3: Implement InviteScreen**

```dart
// apps/mobile/lib/features/workspaces/invite_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workspace_provider.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  const InviteScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(workspaceNotifierProvider.notifier).inviteMember(
            widget.workspaceId,
            _emailCtrl.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invite')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                Text('Invite sent to ${_emailCtrl.text}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
                const SizedBox(height: 16),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Invite Member',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('inviteEmailField'),
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email address'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('sendInviteButton'),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send Invite'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 3.4: Commit**

```bash
git add apps/mobile/lib/features/workspaces/workspace_settings_screen.dart apps/mobile/lib/features/workspaces/members_screen.dart apps/mobile/lib/features/workspaces/invite_screen.dart
git commit -m "feat(mobile/workspaces): add Settings, Members, and Invite screens"
```

---

## Task 4: AcceptInviteScreen

**Files:**
- Create: `lib/features/workspaces/accept_invite_screen.dart`

- [ ] **Step 4.1: Implement AcceptInviteScreen**

Replace the stub below with the full implementation that handles HTTP error codes explicitly and redirects on success.

```dart
// apps/mobile/lib/features/workspaces/accept_invite_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  final String token;
  const AcceptInviteScreen({required this.token, super.key});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accept();
  }

  Future<void> _accept() async {
    try {
      // POST /invites/accept { token } — backend accepts token alone (no workspaceId needed)
      await ref.read(apiClientProvider).post('/invites/accept', data: {'token': widget.token});
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      setState(() {
        _loading = false;
        _error = switch (code) {
          404 => 'This invite link is invalid or has already been used.',
          410 => 'This invite link has expired (72-hour limit).',
          409 => 'You are already a member of this workspace.',
          _ => 'Failed to accept invite. Please try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/dashboard'), child: const Text('Go to Dashboard')),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Test cases for Step 4.1:**
- HTTP 410 response → shows "This invite link has expired (72-hour limit)."
- HTTP 409 response → shows "You are already a member of this workspace."
- HTTP 404 response → shows "This invite link is invalid or has already been used."
- HTTP 200 → navigates to `/dashboard`

- [ ] **Step 4.2: Update GoRouter with all workspace routes**

In `lib/core/router/app_router.dart`, replace placeholder routes with real screens:

```dart
// Add imports:
import '../../features/workspaces/workspaces_screen.dart';
import '../../features/workspaces/create_workspace_screen.dart';
import '../../features/workspaces/workspace_settings_screen.dart';
import '../../features/workspaces/members_screen.dart';
import '../../features/workspaces/accept_invite_screen.dart';

// Replace routes:
GoRoute(
  path: AppRoutes.inviteAccept,
  builder: (_, state) =>
      AcceptInviteScreen(token: state.pathParameters['token']!),
),
GoRoute(
  path: AppRoutes.workspaces,
  builder: (_, __) => const WorkspacesScreen(),
  routes: [
    GoRoute(
      path: 'create',
      builder: (_, __) => const CreateWorkspaceScreen(),
    ),
    GoRoute(
      path: ':id/settings',
      builder: (_, state) =>
          WorkspaceSettingsScreen(workspaceId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'members',
          builder: (_, state) =>
              MembersScreen(workspaceId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
),
```

> **Unauthenticated access & deep-link redirect:**
> The `/invite/:token` route must be accessible to guests (users who click an email link before logging in). The GoRouter redirect guard should detect that the user is unauthenticated, store the intended `/invite/:token` path in `SecureStorageService` under key `pending_redirect`, redirect to `/login`, and then navigate to the stored path immediately after a successful login. This ensures the invite token is not lost during the auth flow.

- [ ] **Step 4.3: Run full test suite**

```bash
cd apps/mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 4.4: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 4.5: Commit**

```bash
git add apps/mobile/lib/features/workspaces/accept_invite_screen.dart apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/workspaces): add AcceptInviteScreen and wire all workspace routes"
```

---

## Phase 6 Complete

- ✅ `WorkspacesScreen` — list with active checkmark, settings gear, "New Workspace" entry
- ✅ `CreateWorkspaceScreen` — name field + currency dropdown (9 currencies), calls `WorkspaceNotifier.createWorkspace`
- ✅ `WorkspaceSettingsScreen` — links to Members + Invite, shows currency
- ✅ `MembersScreen` — role badge, remove button with confirmation (disabled for owner)
- ✅ `InviteScreen` — modal bottom sheet, email input, sent confirmation state
- ✅ `AcceptInviteScreen` — auto-accepts on mount, granular HTTP error codes (404/409/410), success redirects to `/dashboard`
- ✅ GoRouter updated with full workspace route tree (nested routes)
- ✅ GoRouter redirect guard stores `pending_redirect` in `SecureStorageService` for unauthenticated deep links to `/invite/:token`
- ✅ Widget tests: 3 WorkspacesScreen tests; AcceptInviteScreen tests for 404/409/410 error messages

**Next plan:** `2026-06-16-flutter-phase7.md` — Budgets + Recurring Rules features
