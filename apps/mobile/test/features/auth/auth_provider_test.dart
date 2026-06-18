import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
}
