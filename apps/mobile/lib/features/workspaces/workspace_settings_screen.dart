import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: Text(workspace.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Members'),
            subtitle: Text('${workspace.members.length} members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/workspaces/$workspaceId/settings/members'),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: const Text('Invite Member'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/workspaces/$workspaceId/settings/invite'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Currency'),
            trailing: Text(workspace.currency, style: const TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }
}
