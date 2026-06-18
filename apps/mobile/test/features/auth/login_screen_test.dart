import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/features/auth/login_screen.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {

  User? result;
  bool loginCalled = false;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<User> login({required String email, required String password}) async {
    loginCalled = true;
    lastEmail = email;
    lastPassword = password;
    if (result == null) throw Exception('Invalid credentials');
    return result!;
  }

  @override
  Future<User> register(
          {required String email,
          required String password,
          required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword({required String email}) async {}
}

Widget _buildSubject(_FakeAuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  late _FakeAuthService fakeService;

  setUp(() => fakeService = _FakeAuthService());

  testWidgets('shows email and password fields', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeService));
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  });

  testWidgets('shows error on empty form submission', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeService));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('calls AuthService.login with form values', (tester) async {
    fakeService.result =
        const User(id: 'u1', email: 'a@b.com', name: 'A');
    await tester.pumpWidget(_buildSubject(fakeService));
    await tester.enterText(find.byKey(const Key('emailField')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'pass');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();
    expect(fakeService.loginCalled, isTrue);
    expect(fakeService.lastEmail, 'a@b.com');
    expect(fakeService.lastPassword, 'pass');
  });
}
