import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'u1',
        'email': 'test@example.com',
        'name': 'Test User',
        'avatarUrl': null,
        'oauthProvider': null,
      };
      final user = User.fromJson(json);
      expect(user.id, 'u1');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
    });

    test('toJson round-trips correctly', () {
      const user = User(id: 'u1', email: 'a@b.com', name: 'A');
      final json = user.toJson();
      final decoded = User.fromJson(json);
      expect(decoded, user);
    });

    test('copyWith changes only specified fields', () {
      const user = User(id: 'u1', email: 'a@b.com', name: 'A');
      final updated = user.copyWith(name: 'B');
      expect(updated.name, 'B');
      expect(updated.email, 'a@b.com');
    });
  });
}
