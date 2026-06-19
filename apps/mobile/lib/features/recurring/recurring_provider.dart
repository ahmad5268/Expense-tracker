import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/recurring_rule.dart';

class RecurringNotifier extends Notifier<List<RecurringRule>> {
  @override
  List<RecurringRule> build() => [];

  Future<void> fetchRules() async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/workspaces/${workspace.id}/recurring');
    state = (response.data['data'] as List)
        .map((j) => RecurringRule.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRule({
    required String categoryId,
    required int amount,
    required String type,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.post(
          '/workspaces/${workspace.id}/recurring',
          data: {
            'categoryId': categoryId,
            'amount': amount,
            'type': type,
            'frequency': frequency,
            'startDate': startDate.toIso8601String(),
            if (endDate != null) 'endDate': endDate.toIso8601String(),
            if (description != null) 'description': description,
          },
        );
    final rule = RecurringRule.fromJson(response.data['data'] as Map<String, dynamic>);
    state = [rule, ...state];
  }

  Future<void> updateRule(String id, {bool? isActive, DateTime? endDate}) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.put(
          '/workspaces/${workspace.id}/recurring/$id',
          data: {
            if (isActive != null) 'isActive': isActive,
            if (endDate != null) 'endDate': endDate.toIso8601String(),
          },
        );
    final updated = RecurringRule.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.map((r) => r.id == id ? updated : r).toList();
  }

  Future<void> deleteRule(String id) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    await ref.read(apiClientProvider).dio.delete(
          '/workspaces/${workspace.id}/recurring/$id',
        );
    state = state.where((r) => r.id != id).toList();
  }
}

final recurringNotifierProvider =
    NotifierProvider<RecurringNotifier, List<RecurringRule>>(RecurringNotifier.new);
