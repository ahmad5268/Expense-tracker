import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

enum MemberRole {
  @JsonValue('OWNER') owner,
  @JsonValue('ADMIN') admin,
  @JsonValue('MEMBER') member,
}

@freezed
class WorkspaceMember with _$WorkspaceMember {
  const factory WorkspaceMember({
    required String userId,
    required String name,
    String? avatarUrl,
    required MemberRole role,
  }) = _WorkspaceMember;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceMemberFromJson(json);
}

@freezed
class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    required String currency,
    required String ownerId,
    @Default([]) List<WorkspaceMember> members,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
