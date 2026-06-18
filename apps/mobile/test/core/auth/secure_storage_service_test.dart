import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';

@GenerateNiceMocks([MockSpec<SharedPreferences>()])
import 'secure_storage_service_test.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;
  late SecureStorageService storage;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    storage = SecureStorageService.withPrefs(mockPrefs);
  });

  group('SecureStorageService', () {
    test('saveTokens persists both tokens', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
      await storage.saveTokens(accessToken: 'at', refreshToken: 'rt');
      verify(mockPrefs.setString('access_token', 'at')).called(1);
      verify(mockPrefs.setString('refresh_token', 'rt')).called(1);
    });

    test('getAccessToken returns stored value', () async {
      when(mockPrefs.getString('access_token')).thenReturn('at');
      expect(await storage.getAccessToken(), 'at');
    });

    test('getRefreshToken returns stored value', () async {
      when(mockPrefs.getString('refresh_token')).thenReturn('rt');
      expect(await storage.getRefreshToken(), 'rt');
    });

    test('clearTokens removes all keys', () async {
      when(mockPrefs.remove(any)).thenAnswer((_) async => true);
      await storage.clearTokens();
      verify(mockPrefs.remove('access_token')).called(1);
      verify(mockPrefs.remove('refresh_token')).called(1);
    });
  });
}
