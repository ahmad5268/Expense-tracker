import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workspace_provider.dart';
import '../../shared/models/workspace.dart';

class MembersScreen extends ConsumerWidget {
  final String workspaceId;
  const MembersScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceNotifierProvider);
    final workspace = state.workspaces.where((w) => w.id == workspaceId).firstOrNull;

    if (workspace == null) return const Scaffold(body: Center(child: Text('Workspace not found')));

    final currentUser = state.activeWorkspace?.members
        .where((m) => m.userId == workspace.members.firstOrNull?.userId)
        .firstOrNull;
    final canRemove = currentUser != null &&
        [MemberRole.owner, MemberRole.admin].contains(currentUser.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: workspace.members.length,
        itemBuilder: (context, index) {
          final member = workspace.members[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              child: Text(
                member.name[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(member.name),
            subtitle: Text(member.role.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
            trailing: canRemove && member.role != MemberRole.owner
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                    onPressed: () async {
                      await ref.read(workspaceNotifierProvider.notifier).removeMember(workspaceId, member.userId);
                    },
                  )
                : null,
          );
        },
      ),
    );
  }
}
