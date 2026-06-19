import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../shared/models/user.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final storage = ref.read(secureStorageProvider);
    final accessToken = await storage.getAccessToken();
    if (accessToken == null) return null;

    // Token exists — validate it (or refresh if expired) via /auth/me.
    // The Dio interceptor handles 401 → refresh → retry automatically.
    // It also clears tokens when refresh fails, so we don't do that here.
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.get('/auth/me');
      return User.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      state = AsyncData(user);
    } catch (e, st) {
      state = const AsyncData(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authServiceProvider)
          .register(email: email, password: password, name: name);
      state = AsyncData(user);
    } catch (e, st) {
      state = const AsyncData(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
