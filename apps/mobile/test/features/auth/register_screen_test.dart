import 'package:expense_tracker/features/auth/auth_provider.dart';
import 'package:expense_tracker/features/auth/auth_service.dart';
import 'package:expense_tracker/features/auth/register_screen.dart';
import 'package:expense_tracker/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  User? registerResult;
  bool registerCalled = false;
  String? lastName;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    registerCalled = true;
    lastName = name;
    lastEmail = email;
    lastPassword = password;
    if (registerResult == null) throw Exception('Email already taken');
    return registerResult!;
  }

  @override
  Future<User> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword({required String email}) async {}
}

Widget _buildSubject(_FakeAuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: RegisterScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthService fakeService;

  setUp(() => fakeService = _FakeAuthService());

  testWidgets('shows name, email, password fields and register button',
      (tester) async {
    await tester.pumpWidget(_buildSubject(fakeService));

    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('registerButton')), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeService));

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pump();

    // Name and email validators produce 'Required'; password produces 'At least 8 characters'
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('shows error banner when register service throws', (tester) async {
    // registerResult is null, so fake throws
    await tester.pumpWidget(_buildSubject(fakeService));

    await tester.enterText(find.byKey(const Key('nameField')), 'Ahmad');
    await tester.enterText(find.byKey(const Key('emailField')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pump(); // trigger setState for loading
    await tester.pump(); // allow async to complete

    expect(
      find.text('Registration failed. Email may already be taken.'),
      findsOneWidget,
    );
  });

  testWidgets('password toggle button changes obscureText', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeService));

    // Password field starts obscured — the eye-off icon should be visible
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // Tap the toggle to reveal the password
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    // Now the eye-open (visible) icon should be shown
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Tap again to obscure once more
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('calls register with form values on valid submit', (tester) async {
    fakeService.registerResult =
        const User(id: 'u1', email: 'test@example.com', name: 'Test User');

    await tester.pumpWidget(_buildSubject(fakeService));

    await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
    await tester.enterText(
        find.byKey(const Key('emailField')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('passwordField')), 'password123');
    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pump();

    expect(fakeService.registerCalled, isTrue);
    expect(fakeService.lastName, 'Test User');
    expect(fakeService.lastEmail, 'test@example.com');
    expect(fakeService.lastPassword, 'password123');
  });
}
