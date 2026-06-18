import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/shared/models/workspace.dart';

void main() {
  group('Workspace model', () {
    test('fromJson round-trips correctly', () {
      final json = {
        'id': 'w1',
        'name': 'Family Budget',
        'currency': 'USD',
        'ownerId': 'u1',
        'members': [],
      };
      final workspace = Workspace.fromJson(json);
      expect(workspace.id, 'w1');
      expect(workspace.name, 'Family Budget');
      expect(workspace.currency, 'USD');
      expect(workspace.members, isEmpty);
    });

    test('MemberRole maps OWNER from JSON', () {
      final member = WorkspaceMember.fromJson({
        'userId': 'u1',
        'name': 'Alice',
        'role': 'OWNER',
      });
      expect(member.role, MemberRole.owner);
    });

    test('MemberRole maps MEMBER from JSON', () {
      final member = WorkspaceMember.fromJson({
        'userId': 'u2',
        'name': 'Bob',
        'role': 'MEMBER',
      });
      expect(member.role, MemberRole.member);
    });
  });
}
