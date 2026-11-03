import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/screens/auth_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.test/api');

  String? requestError;
  String? verifyError;
  String? loginError;
  String? requestedPhone;
  String? verifiedPhone;
  String? verifiedOtp;
  String? verifiedName;
  String? loggedInCredential;
  String? loggedInPassword;

  ApiException? emailRequestError;
  ApiException? emailVerifyError;
  ApiException? signupError;
  bool signupRequiresVerification = false;
  int signupCalls = 0;
  String? requestedEmail;
  String? verifiedEmail;
  String? verifiedEmailOtp;

  static const _customer = AuthResult(
    user: SessionUser(
      id: null,
      name: 'Asha Kumar',
      username: 'asha',
      role: WorkspaceRole.customer,
    ),
    accessToken: 'test-access-token',
  );

  @override
  Future<AuthResult> login(String credential, String password) async {
    loggedInCredential = credential;
    loggedInPassword = password;
    if (loginError != null) throw ApiException(loginError!, 401);
    throw StateError('A successful login is not expected in this test.');
  }

  @override
  Future<String> requestPhoneAuthOtp(String phone) async {
    requestedPhone = phone;
    if (requestError != null) throw ApiException(requestError!, 503);
    return 'challenge-id';
  }

  @override
  Future<AuthResult> verifyPhoneAuthOtp({
    required String phone,
    required String challengeId,
    required String otp,
    String? name,
  }) async {
    verifiedPhone = phone;
    verifiedOtp = otp;
    verifiedName = name;
    if (verifyError != null) throw ApiException(verifyError!, 400);
    return _customer;
  }

  @override
  Future<AuthResult?> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? themeMode,
  }) async {
    signupCalls++;
    requestedEmail = email;
    if (signupError != null) throw signupError!;
    if (signupRequiresVerification) return null;
    return _customer;
  }

  @override
  Future<String> requestEmailAuthOtp(String email) async {
    requestedEmail = email;
    if (emailRequestError != null) throw emailRequestError!;
    return 'email-challenge';
  }

  @override
  Future<AuthResult> verifyEmailAuthOtp({
    required String email,
    required String challengeId,
    required String otp,
    String? name,
    String? phone,
  }) async {
    verifiedEmail = email;
    verifiedEmailOtp = otp;
    if (emailVerifyError != null) throw emailVerifyError!;
    return _customer;
  }
}

/// The one-time-code boxes are backed by a single TextField inside OtpField.
Finder _otpInput() => find.descendant(
      of: find.byType(OtpField),
      matching: find.byType(TextField),
    );

/// The sign-in / create-account tabs. "Sign in" is also a button label, so
/// tabs are found inside SegmentedTabs.
Finder _tab(String label) => find.descendant(
      of: find.byType(SegmentedTabs),
      matching: find.text(label),
    );

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

Finder _button(String label) => find.descendant(
      of: find.byType(PrimaryButton),
      matching: find.text(label),
    );

String _fieldText(WidgetTester tester, int index) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .controller
    .text;

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
    // The form is taller now, so give the test surface room for the buttons.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(controller: controller)),
    );
  }

  testWidgets('create account opens on phone, with email and tabs offered',
      (tester) async {
    await showAuthScreen(tester);

    expect(find.text('Create your account.'), findsOneWidget);
    expect(_tab('Sign in'), findsOneWidget);
    expect(_tab('Create account'), findsOneWidget);
    expect(_chip('Phone'), findsOneWidget);
    expect(_chip('Email'), findsOneWidget);
    expect(_chip('Username'), findsNothing);
    expect(find.text('10-digit mobile number'), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('existing users can sign in with username and password',
      (tester) async {
    api.loginError = 'Invalid credentials';
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Username'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'asha.kumar',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
    await tester.tap(_button('Sign in'));
    await tester.pumpAndSettle();

    expect(api.loggedInCredential, 'asha.kumar');
    expect(api.loggedInPassword, 'incorrect');
    expect(find.text(api.loginError!), findsOneWidget);
  });

  testWidgets('requests an OTP for a valid mobile number', (tester) async {
    await showAuthScreen(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      '9876543210',
    );
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(api.requestedPhone, '9876543210');
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Verify code and create account'), findsOneWidget);
  });

  testWidgets('sends the phone, OTP, and optional new-account name to verify',
      (tester) async {
    api.verifyError = 'The verification code is incorrect.';
    await showAuthScreen(tester);
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(_otpInput(), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'Asha Kumar');
    await tester.tap(find.text('Verify code and create account'));
    await tester.pumpAndSettle();

    expect(api.verifiedPhone, '9876543210');
    expect(api.verifiedOtp, '123456');
    expect(api.verifiedName, 'Asha Kumar');
    expect(find.text(api.verifyError!), findsOneWidget);
    expect(find.text('Verify code and create account'), findsOneWidget);
  });

  testWidgets('existing users can verify a phone code without a name',
      (tester) async {
    api.verifyError = 'The verification code is incorrect.';
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(_otpInput(), '123456');
    await tester.tap(find.text('Verify code and sign in'));
    await tester.pumpAndSettle();

    expect(api.verifiedPhone, '9876543210');
    expect(api.verifiedOtp, '123456');
    expect(api.verifiedName, isNull);
    expect(find.text(api.verifyError!), findsOneWidget);
  });

  testWidgets('shows OTP delivery errors and keeps phone entry available',
      (tester) async {
    api.requestError = 'Mobile verification is not configured yet.';
    await showAuthScreen(tester);
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(find.text(api.requestError!), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
  });

  testWidgets('a new code waits 30 seconds after each code is sent',
      (tester) async {
    await showAuthScreen(tester);
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send verification code'));
    // A plain pump, not pumpAndSettle: settling would run the countdown out.
    await tester.pump();
    await tester.pump();

    expect(find.text('Send a new code in 30s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Send a new code in 20s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Send a new code'), findsOneWidget);
  });

  testWidgets('email sign-in with a password sends the normalized address',
      (tester) async {
    api.loginError = 'Incorrect email or password.';
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Asha@Example.com ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.tap(_button('Sign in'));
    await tester.pumpAndSettle();

    expect(api.loggedInCredential, 'asha@example.com');
    expect(api.loggedInPassword, 'Secret123');
    expect(find.text(api.loginError!), findsOneWidget);
  });

  testWidgets('forgot password opens the reset sheet', (tester) async {
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset instructions'), findsOneWidget);
  });

  testWidgets('email code sign-in requests a code and verifies it',
      (tester) async {
    api.emailVerifyError = ApiException('The code is incorrect.', 400);
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'asha@example.com');
    await tester.tap(_button('Send code'));
    await tester.pumpAndSettle();

    expect(api.requestedEmail, 'asha@example.com');
    expect(find.text('Verification code'), findsOneWidget);

    await tester.enterText(_otpInput(), '123456');
    await tester.pumpAndSettle();

    expect(api.verifiedEmail, 'asha@example.com');
    expect(api.verifiedEmailOtp, '123456');
    expect(find.text(api.emailVerifyError!.message), findsOneWidget);
  });

  testWidgets('email codes are hidden when the server does not have them',
      (tester) async {
    api.emailRequestError = ApiException('Not found', 404);
    await showAuthScreen(tester);
    await tester.tap(_tab('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'asha@example.com');
    await tester.tap(_button('Send code'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppController.emailCodesUnavailableMessage),
      findsOneWidget,
    );
    expect(find.text('Email me a code'), findsNothing);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('a weak password is refused before the account is created',
      (tester) async {
    await showAuthScreen(tester);
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Kumar');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(3), 'short');
    await tester.tap(_button('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a password that meets every rule below.'),
      findsOneWidget,
    );
    expect(api.signupCalls, 0);
  });

  testWidgets('an email sign-up that needs confirmation shows the inbox state',
      (tester) async {
    api.signupRequiresVerification = true;
    await showAuthScreen(tester);
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Kumar');
    await tester.enterText(
        find.byType(TextFormField).at(1), ' Asha@Example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(3), 'Secret123');
    await tester.tap(_button('Create account'));
    await tester.pumpAndSettle();

    expect(api.requestedEmail, 'asha@example.com');
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('an address that already has an account opens sign-in with it',
      (tester) async {
    api.signupError = ApiException('This email is already registered.', 409);
    await showAuthScreen(tester);
    await tester.tap(_chip('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Kumar');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(3), 'Secret123');
    await tester.tap(_button('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in instead'), findsOneWidget);
    await tester.tap(find.text('Sign in instead'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(_fieldText(tester, 0), 'asha@example.com');
  });

  testWidgets('a confirmation link opens email sign-in with the notice',
      (tester) async {
    controller.showEmailConfirmed();
    await showAuthScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(
      find.text('Your email is confirmed. Sign in to continue.'),
      findsOneWidget,
    );
    expect(controller.emailConfirmed, isFalse);
  });

  testWidgets('a confirmation link that arrives while the screen is open',
      (tester) async {
    await showAuthScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('Create your account.'), findsOneWidget);

    controller.showEmailConfirmed();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(
      find.text('Your email is confirmed. Sign in to continue.'),
      findsOneWidget,
    );
  });
}
