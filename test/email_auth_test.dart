import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/auth_feature_flags.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/screens/auth/password_rules.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/email_rules.dart';

import 'support/memory_secure_storage.dart';

const _authPayload = {
  'accessToken': 'access-token',
  'refreshToken': 'refresh-token',
  'user': {
    'id': 'user-1',
    'name': 'Asha Kumar',
    'username': 'asha',
    'role': 'customer',
    'email': 'asha@example.com',
  },
};

ApiClient _apiFor(http.Client client, MemorySecureStorage storage) => ApiClient(
      client: client,
      storage: storage,
      baseUrl: 'https://example.test/api',
    );

void main() {
  group('email rules', () {
    test('an address is trimmed and lowercased before it is used', () {
      expect(normalizeEmail('  Asha.Kumar@Example.COM '),
          'asha.kumar@example.com');
    });

    test('typos that cannot be an address are rejected', () {
      expect(isValidEmail('asha@example.com'), isTrue);
      expect(isValidEmail('asha.kumar+tank@mail.example.in'), isTrue);
      expect(isValidEmail('asha@example'), isFalse);
      expect(isValidEmail('asha example@x.com'), isFalse);
      expect(isValidEmail('asha@@example.com'), isFalse);
      expect(isValidEmail('@example.com'), isFalse);
      expect(isValidEmail(''), isFalse);
    });

    test('an address over 254 characters is rejected', () {
      final long = '${'a' * 250}@example.com';
      expect(isValidEmail(long), isFalse);
    });
  });

  group('password rules', () {
    test('a password needs 8 characters, upper case, lower case and a number',
        () {
      expect(isStrongPassword('Secret123'), isTrue);
      expect(isStrongPassword('Secret1'), isFalse,
          reason: 'under 8 characters');
      expect(isStrongPassword('secret123'), isFalse, reason: 'no upper case');
      expect(isStrongPassword('SECRET123'), isFalse, reason: 'no lower case');
      expect(isStrongPassword('Secretabc'), isFalse, reason: 'no number');
    });

    test('each check reports on its own', () {
      final checks = passwordChecks('secret');
      expect(checks.map((check) => check.met), [false, false, true, false]);
    });
  });

  group('email sign-in and sign-up requests', () {
    test('password sign-in sends the email and password', () async {
      final storage = MemorySecureStorage();
      late Map<String, dynamic> body;
      final api = _apiFor(
        MockClient((request) async {
          expect(request.url.path, '/api/auth/login');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_authPayload), 200);
        }),
        storage,
      );

      await api.login('asha@example.com', 'Secret123');

      expect(body, {'email': 'asha@example.com', 'password': 'Secret123'});
      expect(storage.values['urban_tanker_access_token'], 'access-token');
    });

    test('a username sign-in still sends the username', () async {
      late Map<String, dynamic> body;
      final api = _apiFor(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_authPayload), 200);
        }),
        MemorySecureStorage(),
      );

      await api.login('asha.kumar', 'Secret123');

      expect(body, {'username': 'asha.kumar', 'password': 'Secret123'});
    });

    test('signup returns a challenge when the server asks for an email code',
        () async {
      final api = _apiFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'requiresEmailVerification': true,
              'emailSent': true,
              'challengeId': 'challenge-1',
              'resendAfterSeconds': 45,
            }),
            201,
          ),
        ),
        MemorySecureStorage(),
      );

      final result = await api.signup(
        email: 'asha@example.com',
        password: 'Secret123',
        name: 'Asha Kumar',
        phone: '9876543210',
      );

      expect(result.authResult, isNull);
      expect(result.challengeId, 'challenge-1');
      expect(result.resendAfterSeconds, 45);
    });

    test('signup stores the session when the server signs the user in',
        () async {
      final storage = MemorySecureStorage();
      final api = _apiFor(
        MockClient((_) async => http.Response(jsonEncode(_authPayload), 201)),
        storage,
      );

      final result = await api.signup(
        email: 'asha@example.com',
        password: 'Secret123',
        name: 'Asha Kumar',
        phone: '9876543210',
      );

      expect(result.challengeId, isNull);
      expect(result.authResult?.user.name, 'Asha Kumar');
      expect(storage.values['urban_tanker_refresh_token'], 'refresh-token');
    });

    test('a taken email surfaces as a 409 ApiException', () async {
      final api = _apiFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'This email is already registered.'}),
            409,
          ),
        ),
        MemorySecureStorage(),
      );

      await expectLater(
        api.signup(
          email: 'asha@example.com',
          password: 'Secret123',
          name: 'Asha Kumar',
          phone: '9876543210',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 409),
        ),
      );
    });
  });

  group('email one-time codes', () {
    test('a code is requested for the normalized address', () async {
      late Map<String, dynamic> body;
      final api = _apiFor(
        MockClient((request) async {
          expect(request.url.path, '/api/auth/email/request-otp');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'challengeId': 'challenge-1'}), 200);
        }),
        MemorySecureStorage(),
      );

      final challengeId = await api.requestEmailAuthOtp('  Asha@Example.com ');

      expect(body, {'email': 'asha@example.com'});
      expect(challengeId, 'challenge-1');
    });

    test('an invalid address is refused without a request', () async {
      var calls = 0;
      final api = _apiFor(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        MemorySecureStorage(),
      );

      await expectLater(
        api.requestEmailAuthOtp('not-an-email'),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });

    test('a missing endpoint is a 404 the controller can act on', () async {
      final api = _apiFor(
        MockClient((_) async => http.Response('not found', 404)),
        MemorySecureStorage(),
      );

      await expectLater(
        api.requestEmailAuthOtp('asha@example.com'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('verifying a code stores the session and sends name and phone',
        () async {
      final storage = MemorySecureStorage();
      late Map<String, dynamic> body;
      final api = _apiFor(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_authPayload), 200);
        }),
        storage,
      );

      final result = await api.verifyEmailAuthOtp(
        email: 'Asha@Example.com',
        challengeId: 'challenge-1',
        otp: ' 123456 ',
        name: ' Asha Kumar ',
        phone: '+91 98765 43210',
      );

      expect(body, {
        'email': 'asha@example.com',
        'challengeId': 'challenge-1',
        'otp': '123456',
        'name': 'Asha Kumar',
        'phone': '9876543210',
      });
      expect(result.user.name, 'Asha Kumar');
      expect(storage.values['urban_tanker_access_token'], 'access-token');
    });

    test('a code that is not six digits is refused without a request',
        () async {
      var calls = 0;
      final api = _apiFor(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        MemorySecureStorage(),
      );

      await expectLater(
        api.verifyEmailAuthOtp(
          email: 'asha@example.com',
          challengeId: 'challenge-1',
          otp: '12345',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });
  });

  group('AppController email sign-in', () {
    late _FakeAuthApi api;
    late AppController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = _FakeAuthApi();
      controller = AppController(
        api: api,
        preferences: await SharedPreferences.getInstance(),
      );
    });

    tearDown(() => controller.dispose());

    test('a 404 turns email codes off for the rest of the run', () async {
      api.requestError = ApiException('Not found', 404);

      await controller.requestEmailAuthOtp('asha@example.com');
      await controller.requestEmailAuthOtp('asha@example.com');

      expect(controller.emailOtpAvailable, isFalse);
      expect(
          controller.errorMessage, AppController.emailCodesUnavailableMessage);
      expect(api.requestCalls, 1,
          reason: 'the second try never reaches the server');
    }, skip: !AuthFeatureFlags.emailOtp);

    test('a 501 also turns email codes off', () async {
      api.requestError = ApiException('Not implemented', 501);

      await controller.requestEmailAuthOtp('asha@example.com');

      expect(controller.emailOtpAvailable, isFalse);
    }, skip: !AuthFeatureFlags.emailOtp);

    test('other failures keep codes available and show the server message',
        () async {
      api.requestError = ApiException('Too many requests.', 429);

      await controller.requestEmailAuthOtp('asha@example.com');

      expect(controller.emailOtpAvailable, isTrue);
      expect(controller.errorMessage, 'Too many requests.');
      expect(controller.errorStatusCode, 429);
    }, skip: !AuthFeatureFlags.emailOtp);

    test('a sign-up that needs confirmation records the address and challenge',
        () async {
      api.signupRequiresVerification = true;

      await controller.signUp(
        email: ' Asha@Example.com ',
        password: 'Secret123',
        name: 'Asha Kumar',
        phone: '9876543210',
      );

      expect(controller.pendingEmailVerification, 'asha@example.com');
      expect(controller.emailOtpChallengeId, 'challenge-1');
      expect(controller.isSignedIn, isFalse);
    });

    test('the correct code completes a sign-up and clears the pending state',
        () async {
      api.signupRequiresVerification = true;
      await controller.signUp(
        email: 'asha@example.com',
        password: 'Secret123',
        name: 'Asha Kumar',
        phone: '9876543210',
      );

      await controller.signInWithEmailAuthOtp(
        email: 'asha@example.com',
        otp: '123456',
      );

      expect(api.verifyCalls, 1);
      expect(controller.pendingEmailVerification, isNull);
      expect(controller.emailOtpChallengeId, isNull);
      expect(controller.isSignedIn, isTrue);
    });

    test('a taken email records the 409 so the screen can offer sign-in',
        () async {
      api.signupError = ApiException('This email is already registered.', 409);

      await controller.signUp(
        email: 'asha@example.com',
        password: 'Secret123',
        name: 'Asha Kumar',
        phone: '9876543210',
      );

      expect(controller.errorStatusCode, 409);
      expect(controller.pendingEmailVerification, isNull);
    });

    test('a code is refused when none was requested', () async {
      await controller.signInWithEmailAuthOtp(
        email: 'asha@example.com',
        otp: '123456',
      );

      expect(
        controller.errorMessage,
        'Request a verification code before signing in.',
      );
    });

    test('the last sign-in method is remembered', () {
      expect(controller.lastAuthMethod, isNull);

      controller.rememberAuthMethod('email');

      expect(controller.lastAuthMethod, 'email');
    });
  });
}

/// Records calls and returns canned results for the email sign-in paths.
class _FakeAuthApi extends ApiClient {
  _FakeAuthApi() : super(baseUrl: 'https://example.test/api');

  ApiException? requestError;
  ApiException? signupError;
  bool signupRequiresVerification = false;
  int verifyCalls = 0;
  AuthResult signedInResult = const AuthResult(
    user: SessionUser(
      id: null,
      name: 'Asha Kumar',
      username: 'asha',
      role: WorkspaceRole.customer,
    ),
    accessToken: 'test-access-token',
  );
  int requestCalls = 0;

  @override
  Future<String> requestEmailAuthOtp(String email) async {
    requestCalls++;
    if (requestError != null) throw requestError!;
    return 'challenge-1';
  }

  @override
  Future<AuthResult> verifyEmailAuthOtp({
    required String email,
    required String challengeId,
    required String otp,
    String? name,
    String? phone,
  }) async {
    verifyCalls++;
    return signedInResult;
  }

  @override
  Future<SignUpOutcome> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? themeMode,
    String role = 'customer',
    String? businessName,
    String? serviceZone,
    double? latitude,
    double? longitude,
    String? selfieJpegBase64,
  }) async {
    if (signupError != null) throw signupError!;
    if (signupRequiresVerification) {
      return (
        authResult: null,
        challengeId: 'challenge-1',
        resendAfterSeconds: 30,
      );
    }
    return (
      authResult: signedInResult,
      challengeId: null,
      resendAfterSeconds: 0,
    );
  }
}
