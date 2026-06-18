import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/workspace.dart';

class WorkspaceState {
  const WorkspaceState({
    this.workspaces = const [],
    this.activeWorkspace,
  });

  final List<Workspace> workspaces;
  final Workspace? activeWorkspace;

  WorkspaceState copyWith({
    List<Workspace>? workspaces,
    Workspace? activeWorkspace,
  }) {
    return WorkspaceState(
      workspaces: workspaces ?? this.workspaces,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
    );
  }
}

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadWorkspaces() async {
    final response = await _api.dio.get('/workspaces');
    final list = (response.data['data'] as List)
        .map((j) => Workspace.fromJson(j as Map<String, dynamic>))
        .toList();
    final active = list.isNotEmpty ? list.first : null;
    state = WorkspaceState(workspaces: list, activeWorkspace: active);
  }

  Future<Workspace> createWorkspace({
    required String name,
    required String currency,
  }) async {
    final response = await _api.dio.post('/workspaces', data: {
      'name': name,
      'currency': currency,
    });
    final workspace = Workspace.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
    state = state.copyWith(
      workspaces: [...state.workspaces, workspace],
      activeWorkspace: state.activeWorkspace ?? workspace,
    );
    return workspace;
  }

  void setActiveWorkspace(Workspace workspace) {
    state = state.copyWith(activeWorkspace: workspace);
  }

  void setActive(String workspaceId) {
    final workspace = state.workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (workspace != null) state = state.copyWith(activeWorkspace: workspace);
  }

  Future<void> inviteMember(String workspaceId, String email) async {
    await _api.dio.post('/workspaces/$workspaceId/invite', data: {'email': email});
  }

  Future<void> removeMember(String workspaceId, String userId) async {
    await _api.dio.delete('/workspaces/$workspaceId/members/$userId');
    state = state.copyWith(
      workspaces: state.workspaces.map((w) {
        if (w.id != workspaceId) return w;
        return w.copyWith(members: w.members.where((m) => m.userId != userId).toList());
      }).toList(),
    );
  }
}

final workspaceNotifierProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);

final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  return ref.watch(workspaceNotifierProvider).activeWorkspace;
});
