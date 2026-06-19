import 'dart:convert';
import '../../core/api/api_client.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../shared/models/user.dart';

class AuthService {
  final ApiClient _client;
  final SecureStorageService _storage;

  AuthService(this._client, this._storage);

  Future<User> login({required String email, required String password}) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(response.data['data'] as Map<String, dynamic>);
  }

  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    return _handleAuthResponse(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } finally {
      await _storage.clearTokens();
    }
  }

  Future<void> forgotPassword({required String email}) async {
    await _client.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<User> _handleAuthResponse(Map<String, dynamic> data) async {
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _storage.saveUser(jsonEncode(user.toJson()));
    return user;
  }
}
