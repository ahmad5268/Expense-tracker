import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage_service.dart';
import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manual fake using `implements` (no super constructor needed)
class _FakeAuthService implements AuthService {

  User? loginResult;
  Exception? loginError;
  User? registerResult;
  bool logoutCalled = false;

  @override
  Future<User> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<User> register(
      {required String email,
      required String password,
      required String name}) async {
    return registerResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> forgotPassword({required String email}) async {}
}

// -------------------------------------------------------------------------
// Helpers for build()-level tests that need a real Dio + storage stack
// -------------------------------------------------------------------------

ProviderContainer _buildContainerWithDio({
  required SecureStorageService storage,
  required ApiClient apiClient,
  AuthService? authService,
}) {
  return ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(storage),
    apiClientProvider.overrideWithValue(apiClient),
    if (authService != null)
      authServiceProvider.overrideWithValue(authService),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Group 1: AuthService-level tests (login / logout / register)
  // These use a fake AuthService and override the provider directly.
  // ------------------------------------------------------------------
  group('AuthNotifier – login / logout / register', () {
    late _FakeAuthService fakeService;
    late ProviderContainer container;

    setUp(() {
      fakeService = _FakeAuthService();
      container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fakeService)],
      );
    });

    tearDown(() => container.dispose());

    const user = User(id: 'u1', email: 'a@b.com', name: 'A');

    test('initial state is null (not authenticated)', () {
      expect(container.read(authNotifierProvider).value, isNull);
    });

    test('login updates state to authenticated user', () async {
      fakeService.loginResult = user;
      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'a@b.com', password: 'pass');
      expect(container.read(authNotifierProvider).value, user);
    });

    test('logout clears state', () async {
      fakeService.loginResult = user;
      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'a@b.com', password: 'pass');
      await container.read(authNotifierProvider.notifier).logout();
      expect(container.read(authNotifierProvider).value, isNull);
      expect(fakeService.logoutCalled, isTrue);
    });

    test('login failure keeps state null and rethrows', () async {
      fakeService.loginError = Exception('Invalid credentials');
      await expectLater(
        () => container
            .read(authNotifierProvider.notifier)
            .login(email: 'a@b.com', password: 'bad'),
        throwsException,
      );
      expect(container.read(authNotifierProvider).value, isNull);
    });
  });

  // ------------------------------------------------------------------
  // Group 2: build() – session restore via /auth/me
  // These need a real Dio stack so they can mock the HTTP endpoint.
  // ------------------------------------------------------------------
  group('AuthNotifier.build() – session restore', () {
    late Dio dio;
    late DioAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      adapter = DioAdapter(dio: dio);
    });

    test('build() resolves to null when no access token is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      final container =
          _buildContainerWithDio(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      final user = await container.read(authNotifierProvider.future);
      expect(user, isNull);
    });

    test('build() restores session via /auth/me when token exists', () async {
      // Pre-seed a stored access token so build() calls /auth/me.
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

      final container =
          _buildContainerWithDio(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      final user = await container.read(authNotifierProvider.future);
      expect(user, isNotNull);
      expect(user!.id, 'u1');
      expect(user.email, 'a@b.com');
      expect(user.name, 'Ali');
    });

    test('build() returns null when /auth/me throws (invalid token)', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'expired-token'});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureStorageService.withPrefs(prefs);
      final client = ApiClient.withDio(dio, storage);

      // /auth/me returns 401 – the interceptor will try to refresh, fail,
      // then the catch-all in build() returns null gracefully.
      adapter.onGet(
        '/auth/me',
        (server) => server.reply(401, {'message': 'Unauthorized'}),
      );
      adapter.onPost(
        '/auth/refresh',
        (server) => server.reply(401, {'message': 'Invalid refresh token'}),
      );

      final container =
          _buildContainerWithDio(storage: storage, apiClient: client);
      addTearDown(container.dispose);

      // build() catches the error and returns null rather than entering
      // the AsyncError state.
      final user = await container.read(authNotifierProvider.future);
      expect(user, isNull);
    });
  });
}
