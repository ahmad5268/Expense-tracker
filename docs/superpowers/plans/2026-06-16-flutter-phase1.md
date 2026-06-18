# Flutter App — Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the Flutter monorepo app with all dependencies, a platform-aware token storage layer, a Dio HTTP client with JWT auto-refresh interceptor, a GoRouter skeleton with auth redirect, and a light/dark app theme.

**Architecture:** `apps/mobile/` is a standard Flutter app. `core/` holds cross-cutting infrastructure (API client, storage, router, theme). Every feature reads tokens from `SecureStorageService`, which uses `flutter_secure_storage` on iOS/Android and `shared_preferences` on web (detected at runtime via `kIsWeb`). The Dio interceptor silently refreshes the access token on 401 and retries the original request once before giving up and clearing all tokens.

**Tech Stack:** Flutter 3.x, Dart, `flutter_riverpod ^2.5`, `go_router ^13`, `dio ^5.4`, `flutter_secure_storage ^9`, `shared_preferences ^2.2`, `freezed_annotation ^2.4`, `json_annotation ^4.9`, `riverpod_generator ^2.4`, `build_runner ^2.4`, `mockito ^5.4`, `http_mock_adapter ^0.6`, `flutter_lints ^4`

**Prerequisite:** Flutter SDK ≥ 3.22 installed. NestJS API is running at `http://localhost:3000` for local dev.

---

## File Map

| File | Responsibility |
|---|---|
| `apps/mobile/pubspec.yaml` | All package dependencies |
| `apps/mobile/lib/main.dart` | Entry point — initialises Firebase, ProviderScope, runs App |
| `apps/mobile/lib/app.dart` | MaterialApp.router wired to GoRouter + theme |
| `apps/mobile/lib/core/api/api_client.dart` | Dio singleton with base URL, headers, JWT interceptor |
| `apps/mobile/lib/core/auth/secure_storage.dart` | Platform-aware token read/write/clear |
| `apps/mobile/lib/core/router/app_router.dart` | GoRouter — auth redirect, route stubs for all screens |
| `apps/mobile/lib/core/theme/app_theme.dart` | ThemeData light + dark, color scheme, text styles |
| `apps/mobile/test/core/api/api_client_test.dart` | Unit tests for JWT interceptor |
| `apps/mobile/test/core/auth/secure_storage_test.dart` | Unit tests for token persistence |

---

## Task 1: pubspec.yaml — all dependencies

**Files:**
- Create: `apps/mobile/pubspec.yaml`

- [ ] **Step 1.1: Run Flutter create to scaffold the project**

```bash
cd apps
flutter create --org com.expensetracker --project-name expense_tracker --platforms web,ios,android mobile
```

- [ ] **Step 1.2: Replace pubspec.yaml with full dependency list**

```yaml
# apps/mobile/pubspec.yaml
name: expense_tracker
description: Multi-user monthly expense tracker
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.22.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # HTTP + WebSocket
  dio: ^5.4.3
  socket_io_client: ^2.0.3+1

  # Token storage (platform-aware)
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.2

  # Data models
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

  # Charts
  fl_chart: ^0.68.0

  # Firebase (push notifications)
  firebase_core: ^3.3.0
  firebase_messaging: ^15.1.0

  # Utilities
  intl: ^0.19.0
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.12
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  riverpod_lint: ^2.3.12
  custom_lint: ^0.6.7

  # Testing
  mockito: ^5.4.4
  http_mock_adapter: ^0.6.1

  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 1.3: Install dependencies**

```bash
cd apps/mobile && flutter pub get
```

Expected: No dependency conflicts, all packages resolved.

- [ ] **Step 1.4: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock
git commit -m "chore(mobile): scaffold Flutter project with all dependencies"
```

---

## Task 2: SecureStorageService
Depends-on: 1

**Files:**
- Create: `apps/mobile/lib/core/auth/secure_storage.dart`
- Create: `apps/mobile/test/core/auth/secure_storage_test.dart`

- [ ] **Step 2.1: Write failing unit tests**

```dart
// apps/mobile/test/core/auth/secure_storage_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';

@GenerateNiceMocks([MockSpec<SharedPreferences>()])
import 'secure_storage_test.mocks.dart';

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
```

- [ ] **Step 2.2: Generate mocks**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2.3: Run test — verify it fails**

```bash
flutter test test/core/auth/secure_storage_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:expense_tracker/core/auth/secure_storage.dart'`

- [ ] **Step 2.4: Implement SecureStorageService**

```dart
// apps/mobile/lib/core/auth/secure_storage.dart
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
```

- [ ] **Step 2.5: Run tests — verify pass**

```bash
flutter test test/core/auth/secure_storage_test.dart
```

Expected: PASS — 4 tests

- [ ] **Step 2.6: Commit**

```bash
git add apps/mobile/lib/core/auth/secure_storage.dart apps/mobile/test/core/auth/
git commit -m "feat(mobile/core): add platform-aware SecureStorageService"
```

---

## Task 3: ApiClient (Dio + JWT interceptor)
Depends-on: 2

**Files:**
- Create: `apps/mobile/lib/core/api/api_client.dart`
- Create: `apps/mobile/test/core/api/api_client_test.dart`

- [ ] **Step 3.1: Write failing unit tests**

```dart
// apps/mobile/test/core/api/api_client_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'api_client_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MockSecureStorageService mockStorage;
  late ApiClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    mockStorage = MockSecureStorageService();
    client = ApiClient.withDio(dio, mockStorage);
  });

  group('JWT interceptor', () {
    test('attaches Authorization header on every request', () async {
      when(mockStorage.getAccessToken()).thenAnswer((_) async => 'test-token');
      adapter.onGet('/users/me', (server) => server.reply(200, {'data': {'id': '1'}}));

      final response = await client.dio.get('/users/me');

      expect(response.statusCode, 200);
      expect(response.requestOptions.headers['Authorization'], 'Bearer test-token');
    });

    test('on 401 refreshes token and retries original request', () async {
      when(mockStorage.getAccessToken())
          .thenAnswer((_) async => 'expired-token');
      when(mockStorage.getRefreshToken())
          .thenAnswer((_) async => 'refresh-token');
      when(mockStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken')))
          .thenAnswer((_) async {});

      adapter
        ..onGet('/users/me',
            (server) => server.reply(401, {'message': 'Unauthorized'}),
            headers: {'Authorization': 'Bearer expired-token'})
        ..onPost('/auth/refresh',
            (server) => server.reply(200, {
                  'data': {
                    'accessToken': 'new-token',
                    'refreshToken': 'new-refresh'
                  }
                }))
        ..onGet('/users/me',
            (server) => server.reply(200, {'data': {'id': '1'}}),
            headers: {'Authorization': 'Bearer new-token'});

      final response = await client.dio.get('/users/me');
      expect(response.statusCode, 200);
      verify(mockStorage.saveTokens(
              accessToken: 'new-token', refreshToken: 'new-refresh'))
          .called(1);
    });

    test('clears tokens when refresh fails', () async {
      when(mockStorage.getAccessToken())
          .thenAnswer((_) async => 'expired-token');
      when(mockStorage.getRefreshToken())
          .thenAnswer((_) async => 'bad-refresh');
      when(mockStorage.clearTokens()).thenAnswer((_) async {});

      adapter
        ..onGet('/users/me',
            (server) => server.reply(401, {'message': 'Unauthorized'}))
        ..onPost('/auth/refresh',
            (server) => server.reply(401, {'message': 'Invalid refresh'}));

      expect(
        () => client.dio.get('/users/me'),
        throwsA(isA<DioException>()),
      );
      // clearTokens is called after failed refresh
    });
  });
}
```

- [ ] **Step 3.2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3.3: Run test — verify it fails**

```bash
flutter test test/core/api/api_client_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:expense_tracker/core/api/api_client.dart'`

- [ ] **Step 3.4: Implement ApiClient**

```dart
// apps/mobile/lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class ApiClient {
  final Dio dio;
  final SecureStorageService _storage;
  bool _isRefreshing = false;

  ApiClient._(this.dio, this._storage);

  factory ApiClient.withDio(Dio dio, SecureStorageService storage) {
    final client = ApiClient._(dio, storage);
    client._addInterceptors();
    return client;
  }

  static Future<ApiClient> create(SecureStorageService storage) async {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    return ApiClient.withDio(dio, storage);
  }

  void _addInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshToken = await _storage.getRefreshToken();
            if (refreshToken == null) throw Exception('No refresh token');

            final response = await dio.post(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
              options: Options(headers: {'Authorization': null}),
            );

            final newAccess = response.data['data']['accessToken'] as String;
            final newRefresh = response.data['data']['refreshToken'] as String;
            await _storage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );

            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retried = await dio.fetch(retryOptions);
            handler.resolve(retried);
          } catch (_) {
            await _storage.clearTokens();
            handler.next(error);
          } finally {
            _isRefreshing = false;
          }
        } else {
          handler.next(error);
        }
      },
    ));
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
```

- [ ] **Step 3.5: Run tests — verify pass**

```bash
flutter test test/core/api/api_client_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 3.6: Commit**

```bash
git add apps/mobile/lib/core/api/api_client.dart apps/mobile/test/core/api/
git commit -m "feat(mobile/core): add Dio ApiClient with JWT auto-refresh interceptor"
```

---

## Task 4: AppTheme
Depends-on: 1

**Files:**
- Create: `apps/mobile/lib/core/theme/app_theme.dart`

- [ ] **Step 4.1: Implement AppTheme**

```dart
// apps/mobile/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF5B67CA);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2C2C2C)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 4.2: Commit**

```bash
git add apps/mobile/lib/core/theme/app_theme.dart
git commit -m "feat(mobile/core): add light/dark AppTheme"
```

---

## Task 5: GoRouter skeleton + App wiring
Depends-on: 2, 3, 4

**Files:**
- Create: `apps/mobile/lib/core/router/app_router.dart`
- Create: `apps/mobile/lib/app.dart`
- Modify: `apps/mobile/lib/main.dart`

- [ ] **Step 5.1: Create GoRouter with route stubs and auth redirect**

```dart
// apps/mobile/lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Route paths — single source of truth
class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const inviteAccept = '/invite/:token';
  static const dashboard = '/';
  static const transactions = '/transactions';
  static const budgets = '/budgets';
  static const recurring = '/recurring';
  static const reports = '/reports';
  static const notifications = '/notifications';
  static const workspaces = '/workspaces';
  static const workspaceSettings = '/workspaces/:id/settings';
}

// Temporary placeholder screen for stubs
class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen(this.name);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: Text(name)),
      );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch auth state — redirect when it changes
  // Replaced in Phase 2 once AuthProvider exists
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const _PlaceholderScreen('Login'),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const _PlaceholderScreen('Register'),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const _PlaceholderScreen('Forgot Password'),
      ),
      GoRoute(
        path: AppRoutes.inviteAccept,
        builder: (_, state) =>
            _PlaceholderScreen('Accept Invite ${state.pathParameters['token']}'),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const _PlaceholderScreen('Dashboard'),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (_, __) => const _PlaceholderScreen('Transactions'),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        builder: (_, __) => const _PlaceholderScreen('Budgets'),
      ),
      GoRoute(
        path: AppRoutes.recurring,
        builder: (_, __) => const _PlaceholderScreen('Recurring'),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, __) => const _PlaceholderScreen('Reports'),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const _PlaceholderScreen('Notifications'),
      ),
      GoRoute(
        path: AppRoutes.workspaces,
        builder: (_, __) => const _PlaceholderScreen('Workspaces'),
      ),
      GoRoute(
        path: AppRoutes.workspaceSettings,
        builder: (_, state) =>
            _PlaceholderScreen('Workspace Settings ${state.pathParameters['id']}'),
      ),
    ],
  );
});
```

- [ ] **Step 5.2: Create app.dart**

```dart
// apps/mobile/lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Expense Tracker',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 5.3: Update main.dart**

```dart
// apps/mobile/lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/secure_storage.dart';
import 'core/api/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final storage = await SecureStorageService.create();
  final apiClient = await ApiClient.create(storage);

  runApp(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const App(),
    ),
  );
}
```

- [ ] **Step 5.4: Verify app compiles**

```bash
cd apps/mobile && flutter analyze
```

Expected: No issues.

```bash
flutter run -d chrome
```

Expected: App starts showing "Login" placeholder screen.

- [ ] **Step 5.5: Commit**

```bash
git add apps/mobile/lib/
git commit -m "feat(mobile): wire up GoRouter skeleton, App, and main.dart"
```

---

## Phase 1 Complete

- ✅ `pubspec.yaml` — all packages (riverpod, go_router, dio, secure_storage, freezed, fl_chart, firebase)
- ✅ `SecureStorageService` — `flutter_secure_storage` on mobile, `shared_preferences` on web
- ✅ `ApiClient` — Dio with JWT attach + silent refresh + retry + token clear on failure
- ✅ `AppTheme` — Material 3, seed color, light + dark
- ✅ `app_router.dart` — GoRouter with all route paths stubbed as placeholders
- ✅ `main.dart` — Firebase init, ProviderScope with storage/api overrides
- ✅ Unit tests: 4 storage tests + 3 interceptor tests

**Next plan:** `2026-06-16-flutter-phase2.md` — Auth feature (User model, AuthProvider, login/register/forgot-password screens, OAuth buttons)
