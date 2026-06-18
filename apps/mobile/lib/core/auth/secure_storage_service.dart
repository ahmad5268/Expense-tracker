import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// On web, flutter_secure_storage uses localStorage (not secure).
// We explicitly use SharedPreferences on web and FlutterSecureStorage on mobile.
// The runtime choice is made once in create(); withPrefs() is for testing.
class SecureStorageService {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage? _secure;
  final SharedPreferences? _prefs;

  SecureStorageService._(this._secure, this._prefs);

  factory SecureStorageService.withPrefs(SharedPreferences prefs) =>
      SecureStorageService._(null, prefs);

  static Future<SecureStorageService> create() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return SecureStorageService._(null, prefs);
    }
    return SecureStorageService._(const FlutterSecureStorage(), null);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_accessKey, accessToken);
      await prefs.setString(_refreshKey, refreshToken);
    } else {
      await _secure!.write(key: _accessKey, value: accessToken);
      await _secure.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = _prefs;
    if (prefs != null) return prefs.getString(_accessKey);
    return _secure!.read(key: _accessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = _prefs;
    if (prefs != null) return prefs.getString(_refreshKey);
    return _secure!.read(key: _refreshKey);
  }

  Future<void> clearTokens() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } else {
      await _secure!.delete(key: _accessKey);
      await _secure.delete(key: _refreshKey);
    }
  }
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
