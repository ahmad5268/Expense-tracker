import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';

void main() {
  late SecureStorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SecureStorageService (web/prefs path)', () {
    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      storage = SecureStorageService.withPrefs(prefs);
    });

    test('saveTokens persists both tokens', () async {
      await storage.saveTokens(accessToken: 'at', refreshToken: 'rt');
      expect(await storage.getAccessToken(), 'at');
      expect(await storage.getRefreshToken(), 'rt');
    });

    test('getAccessToken returns null when not set', () async {
      expect(await storage.getAccessToken(), isNull);
    });

    test('getRefreshToken returns null when not set', () async {
      expect(await storage.getRefreshToken(), isNull);
    });

    test('clearTokens removes both keys', () async {
      await storage.saveTokens(accessToken: 'at', refreshToken: 'rt');
      await storage.clearTokens();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
