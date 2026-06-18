import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workspace_provider.dart';
import '../../shared/models/workspace.dart';

class WorkspacesScreen extends ConsumerStatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  ConsumerState<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<WorkspacesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceNotifierProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Workspaces', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).pushNamed('/workspaces/create'),
        child: const Icon(Icons.add),
      ),
      body: state.workspaces.isEmpty
          ? const Center(child: Text('No workspaces yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.workspaces.length,
              itemBuilder: (context, index) {
                final w = state.workspaces[index];
                final isActive = state.activeWorkspace?.id == w.id;
                return _WorkspaceCard(workspace: w, isActive: isActive);
              },
            ),
    );
  }
}

class _WorkspaceCard extends ConsumerWidget {
  final Workspace workspace;
  final bool isActive;

  const _WorkspaceCard({required this.workspace, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive ? const BorderSide(color: Color(0xFF4F46E5), width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          child: Text(workspace.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
        ),
        title: Text(workspace.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${workspace.currency} · ${workspace.members.length} members', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) const Chip(
              label: Text('Active', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5))),
              backgroundColor: Color(0xFFEEF2FF),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () => Navigator.of(context).pushNamed('/workspaces/${workspace.id}/settings'),
            ),
          ],
        ),
        onTap: () => ref.read(workspaceNotifierProvider.notifier).setActive(workspace.id),
      ),
    );
  }
}
