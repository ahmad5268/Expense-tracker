# Flutter App — Phase 2: Auth Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full authentication feature: User Freezed model, AuthService (API calls), AuthProvider (Riverpod state), Login/Register/ForgotPassword screens, Google/Apple OAuth buttons, and GoRouter auth redirect guard.

**Architecture:** `AuthProvider` is an `AsyncNotifier<AuthState>` that holds the current `User?` and exposes `login/register/logout/refresh` methods. The GoRouter `redirect` callback watches `authStateProvider` — unauthenticated users land on `/login`, authenticated users skip auth routes to `/`. OAuth is handled by launching a browser URL and catching the redirect deep link.

**Tech Stack:** `flutter_riverpod`, `go_router`, `dio`, `freezed`, `json_annotation`, `url_launcher`

**Prerequisite:** Phase 1 complete. `ApiClient`, `SecureStorageService`, `appRouterProvider` all available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/shared/models/user.dart` | Freezed User model + JSON serialization |
| `lib/features/auth/auth_service.dart` | Raw API calls: login, register, refresh, logout, forgotPassword |
| `lib/features/auth/auth_provider.dart` | Riverpod `AsyncNotifier<User?>` — auth state + actions |
| `lib/features/auth/login_screen.dart` | Login form + OAuth buttons |
| `lib/features/auth/register_screen.dart` | Registration form |
| `lib/features/auth/forgot_password_screen.dart` | Email input + send reset link |
| `lib/features/auth/widgets/oauth_buttons.dart` | Google + Apple sign-in buttons |
| `lib/core/router/app_router.dart` | Updated with `redirect` guard watching `authStateProvider` |
| `test/features/auth/auth_provider_test.dart` | Unit tests for AuthProvider |
| `test/features/auth/login_screen_test.dart` | Widget tests for LoginScreen |

---

## Task 1: User model (Freezed)

**Files:**
- Create: `lib/shared/models/user.dart`
- Create: `lib/shared/models/user.g.dart` (generated)
- Create: `lib/shared/models/user.freezed.dart` (generated)

- [ ] **Step 1.1: Write User model**

```dart
// apps/mobile/lib/shared/models/user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    String? avatarUrl,
    String? oauthProvider,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

- [ ] **Step 1.2: Run code generation**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

Expected: `user.freezed.dart` and `user.g.dart` generated with no errors.

- [ ] **Step 1.3: Write model serialization test**

```dart
// apps/mobile/test/shared/models/user_test.dart
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
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/shared/models/user_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/shared/models/user.dart apps/mobile/lib/shared/models/user.freezed.dart apps/mobile/lib/shared/models/user.g.dart apps/mobile/test/shared/models/user_test.dart
git commit -m "feat(mobile/models): add Freezed User model"
```

---

## Task 2: AuthService
Depends-on: 1

**Files:**
- Create: `lib/features/auth/auth_service.dart`
- Create: `test/features/auth/auth_service_test.dart`

- [ ] **Step 2.1: Write failing unit tests**

```dart
// apps/mobile/test/features/auth/auth_service_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'auth_service_test.mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MockSecureStorageService mockStorage;
  late AuthService service;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    mockStorage = MockSecureStorageService();
    when(mockStorage.getAccessToken()).thenAnswer((_) async => null);
    final client = ApiClient.withDio(dio, mockStorage);
    service = AuthService(client, mockStorage);
  });

  group('AuthService.login', () {
    test('returns User and saves tokens on success', () async {
      when(mockStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken')))
          .thenAnswer((_) async {});
      adapter.onPost('/auth/login', (server) => server.reply(200, {
            'data': {
              'accessToken': 'at',
              'refreshToken': 'rt',
              'user': {'id': 'u1', 'email': 'a@b.com', 'name': 'A'},
            }
          }));

      final user = await service.login(email: 'a@b.com', password: 'pass');
      expect(user.id, 'u1');
      verify(mockStorage.saveTokens(accessToken: 'at', refreshToken: 'rt')).called(1);
    });

    test('throws DioException on invalid credentials', () async {
      adapter.onPost('/auth/login',
          (server) => server.reply(401, {'message': 'Invalid credentials'}));
      expect(() => service.login(email: 'a@b.com', password: 'wrong'),
          throwsA(isA<DioException>()));
    });
  });

  group('AuthService.register', () {
    test('returns User and saves tokens', () async {
      when(mockStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken')))
          .thenAnswer((_) async {});
      adapter.onPost('/auth/register', (server) => server.reply(201, {
            'data': {
              'accessToken': 'at',
              'refreshToken': 'rt',
              'user': {'id': 'u2', 'email': 'b@c.com', 'name': 'B'},
            }
          }));

      final user = await service.register(email: 'b@c.com', password: 'pass', name: 'B');
      expect(user.email, 'b@c.com');
    });
  });

  group('AuthService.logout', () {
    test('calls logout endpoint and clears tokens', () async {
      when(mockStorage.getAccessToken()).thenAnswer((_) async => 'tok');
      when(mockStorage.clearTokens()).thenAnswer((_) async {});
      adapter.onPost('/auth/logout', (server) => server.reply(200, {'data': null}));

      await service.logout();
      verify(mockStorage.clearTokens()).called(1);
    });
  });

  group('AuthService.forgotPassword', () {
    test('calls forgot-password endpoint', () async {
      adapter.onPost('/auth/forgot-password',
          (server) => server.reply(200, {'data': null}));
      await expectLater(service.forgotPassword(email: 'a@b.com'), completes);
    });
  });
}
```

- [ ] **Step 2.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/auth/auth_service_test.dart
```

Expected: FAIL — `Cannot find module 'auth_service.dart'`

- [ ] **Step 2.3: Implement AuthService**

```dart
// apps/mobile/lib/features/auth/auth_service.dart
import '../../core/api/api_client.dart';
import '../../core/auth/secure_storage.dart';
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
    return _handleAuthResponse(response.data['data']);
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
    return _handleAuthResponse(response.data['data']);
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
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
flutter test test/features/auth/auth_service_test.dart
```

Expected: PASS — 5 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/mobile/lib/features/auth/auth_service.dart apps/mobile/test/features/auth/auth_service_test.dart
git commit -m "feat(mobile/auth): add AuthService with login/register/logout/forgotPassword"
```

---

## Task 3: AuthProvider (Riverpod)
Depends-on: 2

**Files:**
- Create: `lib/features/auth/auth_provider.dart`
- Create: `test/features/auth/auth_provider_test.dart`

- [ ] **Step 3.1: Write failing unit tests**

```dart
// apps/mobile/test/features/auth/auth_provider_test.dart
import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<AuthService>()])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockAuthService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockAuthService();
    container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() => container.dispose());

  const user = User(id: 'u1', email: 'a@b.com', name: 'A');

  test('initial state is null (not authenticated)', () {
    expect(container.read(authNotifierProvider).value, isNull);
  });

  test('login updates state to authenticated user', () async {
    when(mockService.login(email: 'a@b.com', password: 'pass'))
        .thenAnswer((_) async => user);
    await container.read(authNotifierProvider.notifier).login(
          email: 'a@b.com',
          password: 'pass',
        );
    expect(container.read(authNotifierProvider).value, user);
  });

  test('logout clears state', () async {
    when(mockService.login(email: 'a@b.com', password: 'pass'))
        .thenAnswer((_) async => user);
    when(mockService.logout()).thenAnswer((_) async {});

    await container.read(authNotifierProvider.notifier).login(email: 'a@b.com', password: 'pass');
    await container.read(authNotifierProvider.notifier).logout();
    expect(container.read(authNotifierProvider).value, isNull);
  });

  test('login failure keeps state null and rethrows', () async {
    when(mockService.login(email: any, password: any))
        .thenThrow(Exception('Invalid credentials'));
    expect(
      () => container.read(authNotifierProvider.notifier).login(email: 'a@b.com', password: 'bad'),
      throwsException,
    );
    expect(container.read(authNotifierProvider).value, isNull);
  });
}
```

- [ ] **Step 3.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/auth/auth_provider_test.dart
```

Expected: FAIL — `Cannot find module 'auth_provider.dart'`

- [ ] **Step 3.3: Implement AuthProvider**

```dart
// apps/mobile/lib/features/auth/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/secure_storage.dart';
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
  Future<User?> build() async => null;

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
```

- [ ] **Step 3.4: Run tests — verify pass**

```bash
flutter test test/features/auth/auth_provider_test.dart
```

Expected: PASS — 4 tests

- [ ] **Step 3.5: Commit**

```bash
git add apps/mobile/lib/features/auth/auth_provider.dart apps/mobile/test/features/auth/auth_provider_test.dart
git commit -m "feat(mobile/auth): add AuthNotifier Riverpod provider"
```

---

## Task 4: GoRouter auth redirect guard
Depends-on: 3

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 4.1: Update GoRouter to redirect based on auth state**

```dart
// apps/mobile/lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
// Feature screen imports added in later phases — stubs used until then
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';

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

final _authRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

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
  final authListenable = ValueNotifier<AsyncValue<Object?>>(const AsyncLoading());

  ref.listen(authNotifierProvider, (_, next) {
    authListenable.value = next;
  });

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.valueOrNull != null;
      final isOnAuthRoute = _authRoutes.contains(state.matchedLocation);

      if (!isAuthenticated && !isOnAuthRoute &&
          !state.matchedLocation.startsWith('/invite')) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isOnAuthRoute) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: AppRoutes.inviteAccept,
        builder: (_, state) =>
            _PlaceholderScreen('Accept Invite ${state.pathParameters['token']}'),
      ),
      GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const _PlaceholderScreen('Dashboard')),
      GoRoute(path: AppRoutes.transactions, builder: (_, __) => const _PlaceholderScreen('Transactions')),
      GoRoute(path: AppRoutes.budgets, builder: (_, __) => const _PlaceholderScreen('Budgets')),
      GoRoute(path: AppRoutes.recurring, builder: (_, __) => const _PlaceholderScreen('Recurring')),
      GoRoute(path: AppRoutes.reports, builder: (_, __) => const _PlaceholderScreen('Reports')),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const _PlaceholderScreen('Notifications')),
      GoRoute(path: AppRoutes.workspaces, builder: (_, __) => const _PlaceholderScreen('Workspaces')),
      GoRoute(
        path: AppRoutes.workspaceSettings,
        builder: (_, state) =>
            _PlaceholderScreen('Settings ${state.pathParameters['id']}'),
      ),
    ],
  );
});
```

- [ ] **Step 4.2: Commit**

```bash
git add apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/router): add auth redirect guard to GoRouter"
```

---

## Task 5: OAuth buttons widget
Depends-on: 2

**Files:**
- Create: `lib/features/auth/widgets/oauth_buttons.dart`

- [ ] **Step 5.1: Implement OAuthButtons**

```dart
// apps/mobile/lib/features/auth/widgets/oauth_buttons.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class OAuthButtons extends StatelessWidget {
  const OAuthButtons({super.key});

  Future<void> _launchOAuth(BuildContext context, String provider) async {
    final uri = Uri.parse('$_apiBaseUrl/auth/$provider');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $provider login')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => _launchOAuth(context, 'google'),
          icon: const Icon(Icons.g_mobiledata, size: 24),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _launchOAuth(context, 'apple'),
          icon: const Icon(Icons.apple, size: 24),
          label: const Text('Continue with Apple'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5.2: Commit**

```bash
git add apps/mobile/lib/features/auth/widgets/oauth_buttons.dart
git commit -m "feat(mobile/auth): add Google and Apple OAuth buttons"
```

---

## Task 6: Login, Register, and ForgotPassword screens
Depends-on: 4, 5

**Files:**
- Create: `lib/features/auth/login_screen.dart`
- Create: `lib/features/auth/register_screen.dart`
- Create: `lib/features/auth/forgot_password_screen.dart`
- Create: `test/features/auth/login_screen_test.dart`

- [ ] **Step 6.1: Write failing widget test for LoginScreen**

```dart
// apps/mobile/test/features/auth/login_screen_test.dart
import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/features/auth/login_screen.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<AuthService>()])
import 'login_screen_test.mocks.dart';

Widget _buildSubject(MockAuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: const LoginScreen(),
      ),
    );

void main() {
  late MockAuthService mockService;

  setUp(() => mockService = MockAuthService());

  testWidgets('shows email and password fields', (tester) async {
    await tester.pumpWidget(_buildSubject(mockService));
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  });

  testWidgets('shows error on empty form submission', (tester) async {
    await tester.pumpWidget(_buildSubject(mockService));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('calls AuthService.login with form values', (tester) async {
    when(mockService.login(email: 'a@b.com', password: 'pass'))
        .thenAnswer((_) async => const User(id: 'u1', email: 'a@b.com', name: 'A'));
    await tester.pumpWidget(_buildSubject(mockService));
    await tester.enterText(find.byKey(const Key('emailField')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'pass');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();
    verify(mockService.login(email: 'a@b.com', password: 'pass')).called(1);
  });
}
```

- [ ] **Step 6.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/auth/login_screen_test.dart
```

Expected: FAIL — `Cannot find module 'login_screen.dart'`

- [ ] **Step 6.3: Implement LoginScreen**

```dart
// apps/mobile/lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import 'auth_provider.dart';
import 'widgets/oauth_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      await ref.read(authNotifierProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
    } catch (e) {
      setState(() => _errorMessage = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Expense Tracker',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextFormField(
                  key: const Key('emailField'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('passwordField'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('loginButton'),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign In'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
                const Divider(height: 32),
                const OAuthButtons(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push(AppRoutes.register),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6.4: Implement RegisterScreen**

```dart
// apps/mobile/lib/features/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
import 'widgets/oauth_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      await ref.read(authNotifierProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            name: _name.text.trim(),
          );
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed. Email may be taken.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('nameField'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('emailField'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('passwordField'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'At least 8 characters' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('registerButton'),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Account'),
                ),
                const Divider(height: 32),
                const OAuthButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6.5: Implement ForgotPasswordScreen**

```dart
// apps/mobile/lib/features/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'auth_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).forgotPassword(email: _email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reset email')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Reset link sent. Check your email.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Enter your email to receive a password reset link.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('emailField'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send Reset Link'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 6.6: Run widget tests**

```bash
flutter test test/features/auth/
```

Expected: PASS — all auth tests

- [ ] **Step 6.7: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 6.8: Commit**

```bash
git add apps/mobile/lib/features/auth/ apps/mobile/test/features/auth/
git commit -m "feat(mobile/auth): add Login, Register, ForgotPassword screens"
```

---

## Phase 2 Complete

- ✅ `User` Freezed model with `fromJson`/`toJson` + copyWith
- ✅ `AuthService` — login, register, logout, forgotPassword (API calls + token save)
- ✅ `AuthNotifier` — Riverpod `AsyncNotifier<User?>` with login/register/logout
- ✅ GoRouter auth redirect — unauthenticated → `/login`, authenticated + on auth route → `/`
- ✅ `LoginScreen` — email/password form, validation, error display, loading state, OAuth + register links
- ✅ `RegisterScreen` — name/email/password form with password length validation
- ✅ `ForgotPasswordScreen` — email form, sent confirmation state
- ✅ `OAuthButtons` — launches Google/Apple OAuth via `url_launcher`
- ✅ Unit tests: 3 model + 5 service + 4 provider = 12 tests; 3 widget tests

**Next plan:** `2026-06-16-flutter-phase3.md` — Shared Freezed models (Workspace, Category, Transaction, Budget, RecurringRule, Notification) + WorkspaceProvider
