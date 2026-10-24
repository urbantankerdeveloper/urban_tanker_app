import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/screens/auth_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.test/api');

  String? signupError;
  String? resetError;

  @override
  Future<AuthResult?> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    if (signupError != null) throw ApiException(signupError!, 503);
    return null;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    if (resetError != null) throw ApiException(resetError!, 502);
  }
}

void main() {
  late _FakeApiClient api;
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _FakeApiClient();
    controller = AppController(
      api: api,
      preferences: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> showAuthScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(controller: controller)),
    );
  }

  testWidgets('signup confirms that verification email was sent',
      (tester) async {
    await showAuthScreen(tester);
    await tester.tap(find.text('New here? Create a customer account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Kumar');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'strongpass1');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Account created. Check your email for the confirmation link, then sign in.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('signup displays backend SMTP delivery failures', (tester) async {
    api.signupError =
        'Email confirmation is unavailable. Configure SMTP credentials.';
    await showAuthScreen(tester);
    await tester.tap(find.text('New here? Create a customer account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Kumar');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'strongpass1');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text(api.signupError!), findsOneWidget);
  });

  testWidgets('password reset displays backend email delivery failures',
      (tester) async {
    api.resetError = 'The password reset email could not be sent.';
    await showAuthScreen(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'asha@example.com');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pumpAndSettle();

    expect(find.text(api.resetError!), findsOneWidget);
  });

  testWidgets('password reset shows a non-enumerating success message',
      (tester) async {
    await showAuthScreen(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'asha@example.com');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'If an account exists for that email, password reset instructions have been sent.',
      ),
      findsOneWidget,
    );
  });
}
