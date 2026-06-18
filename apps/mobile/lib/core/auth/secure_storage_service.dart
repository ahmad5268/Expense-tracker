import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// On web, flutter_secure_storage falls back to localStorage which is not secure.
// Use SharedPreferences on web (same limitation, but explicit).
// On mobile, use FlutterSecureStorage (Keychain / Keystore).
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
    if (kIsWeb) {
      await _prefs!.setString(_accessKey, accessToken);
      await _prefs.setString(_refreshKey, refreshToken);
    } else {
      await _secure!.write(key: _accessKey, value: accessToken);
      await _secure.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    return kIsWeb
        ? _prefs!.getString(_accessKey)
        : _secure!.read(key: _accessKey);
  }

  Future<String?> getRefreshToken() async {
    return kIsWeb
        ? _prefs!.getString(_refreshKey)
        : _secure!.read(key: _refreshKey);
  }

  Future<void> clearTokens() async {
    if (kIsWeb) {
      await _prefs!.remove(_accessKey);
      await _prefs.remove(_refreshKey);
    } else {
      await _secure!.delete(key: _accessKey);
      await _secure.delete(key: _refreshKey);
    }
  }
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
