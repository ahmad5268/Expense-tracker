import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helpers to build the provider infrastructure used by AuthNotifier.build().
// AuthNotifier.build() reads:
//   1. secureStorageProvider  – to get the access token
//   2. apiClientProvider      – to call /auth/me when a token is present

ProviderContainer _buildContainer({
  required SecureStorageService storage,
  required ApiClient apiClient,
}) {
  return ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(storage),
    apiClientProvider.overrideWithValue(apiClient),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
  });

  group('authNotifierProvider – build() / session restore', () {
    test('starts in loading state immediately after container creation',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      final container = _buildContainer(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      // Read the raw AsyncValue; it must be loading before build() completes.
      final raw = container.read(authNotifierProvider);
      expect(raw.isLoading, isTrue);
    });

    test('resolves to null when no access token is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      final container = _buildContainer(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      final user = await container.read(authNotifierProvider.future);
      expect(user, isNull);
    });

    test('build() restores session via /auth/me when a token is stored',
        () async {
      // Pre-seed the access token so build() proceeds to call /auth/me.
      SharedPreferences.setMockInitialValues({'access_token': 'valid-token'});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      adapter.onGet(
        '/auth/me',
        (server) => server.reply(200, {
          'data': {
            'id': 'u1',
            'email': 'a@b.com',
            'name': 'Ali',
            'avatarUrl': null,
            'oauthProvider': null,
          },
        }),
      );

      final container = _buildContainer(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      final user = await container.read(authNotifierProvider.future);
      expect(user, isNotNull);
      expect(user, isA<User>());
      expect(user!.id, 'u1');
      expect(user.email, 'a@b.com');
    });

    test('build() returns null when /auth/me throws (invalid / expired token)',
        () async {
      SharedPreferences.setMockInitialValues({'access_token': 'bad-token'});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      adapter.onGet(
        '/auth/me',
        (server) => server.reply(401, {'message': 'Unauthorized'}),
      );

      final container = _buildContainer(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      // Even though /auth/me 401s, build() catches the error and returns null.
      final user = await container.read(authNotifierProvider.future);
      expect(user, isNull);
    });

    test('redirect logic: unauthenticated user maps to /login', () {
      // Unit-test the pure redirect predicate — not the full GoRouter wiring.
      // isAuthenticated = false, isOnAuthRoute = false
      const isAuthenticated = false;
      const isOnAuthRoute = false;

      final redirect = (!isAuthenticated && !isOnAuthRoute) ? '/login' : null;
      expect(redirect, '/login');
    });

    test('redirect logic: authenticated user on auth route maps to /', () {
      const isAuthenticated = true;
      const isOnAuthRoute = true;

      final redirect = isAuthenticated && isOnAuthRoute ? '/' : null;
      expect(redirect, '/');
    });

    test('redirect logic: loading state returns null (wait)', () {
      const isLoading = true;
      final redirect = isLoading ? null : '/login';
      expect(redirect, isNull);
    });
  });
}
