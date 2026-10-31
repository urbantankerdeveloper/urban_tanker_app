import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
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
    return const AuthResult(
      user: SessionUser(
        id: null,
        name: 'Asha Kumar',
        username: 'asha',
        role: WorkspaceRole.customer,
      ),
      accessToken: 'test-access-token',
    );
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

  testWidgets('registration offers an existing-user login option',
      (tester) async {
    await showAuthScreen(tester);

    expect(find.text('Create your account.'), findsOneWidget);
    expect(find.text('Already a user? Log in'), findsOneWidget);
    expect(find.text('10-digit mobile number'), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('existing users can sign in with username and password',
      (tester) async {
    api.loginError = 'Invalid credentials';
    await showAuthScreen(tester);
    await tester.tap(find.text('Already a user? Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Username'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'asha.kumar',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
    await tester.tap(find.text('Sign in'));
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
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.enterText(find.byType(TextFormField).at(2), 'Asha Kumar');
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
    await tester.tap(find.text('Already a user? Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
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
}
