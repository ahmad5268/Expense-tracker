import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/category.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return [];
  final response = await ref
      .read(apiClientProvider)
      .dio
      .get('/workspaces/${workspace.id}/categories');
  return (response.data['data'] as List)
      .map((j) => Category.fromJson(j as Map<String, dynamic>))
      .toList();
});
