import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/screens/auth/phone_verify_dialog.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _VerificationApi extends ApiClient {
  _VerificationApi() : super(baseUrl: 'https://example.test/api');

  PhoneOtpChannel channel = PhoneOtpChannel.whatsapp;
  String? requestedPhone;
  String? verifiedPhone;
  String? verifiedCode;
  String? verificationError;
  int? requestErrorStatus;
  bool profileVerified = false;
  int profileFetches = 0;

  @override
  Future<PhoneVerificationChallenge> requestAccountPhoneVerification(
    String phone,
  ) async {
    requestedPhone = phone;
    if (requestErrorStatus != null) {
      throw ApiException(
        'Please wait before requesting another code.',
        requestErrorStatus!,
        retryAfterSeconds: 12,
      );
    }
    return PhoneVerificationChallenge(
      challengeId: 'challenge-1',
      channel: channel,
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
    );
  }

  @override
  Future<PhoneVerificationResult> confirmAccountPhoneVerification({
    required String phone,
    required String code,
  }) async {
    verifiedPhone = phone;
    verifiedCode = code;
    if (verificationError != null) {
      throw ApiException(verificationError!, 400);
    }
    return PhoneVerificationResult(
      phone: phone,
      challengeId: 'challenge-1',
      verified: true,
    );
  }

  @override
  Future<SessionUser> currentUserProfile() async {
    profileFetches++;
    return SessionUser(
      id: 'user-1',
      name: 'Test User',
      username: 'test',
      role: WorkspaceRole.customer,
      phone: '9876543210',
      phoneVerified: profileVerified,
      phoneVerificationRequired: true,
    );
  }

  @override
  Future<void> saveSessionUser(Map<String, dynamic> user) async {}
}

void main() {
  test('session profile reads account verification requirement', () {
    final required = SessionUser.fromJson({
      'id': 'user-1',
      'name': 'Test User',
      'username': 'test',
      'role': 'customer',
      'phoneVerified': false,
      'phoneVerificationRequired': true,
    });
    final optional = SessionUser.fromJson({
      'id': 'user-2',
      'name': 'Optional User',
      'username': 'optional',
      'role': 'vendor',
      'phoneVerified': false,
      'phoneVerificationRequired': false,
    });

    expect(required.phoneVerificationRequired, isTrue);
    expect(optional.phoneVerificationRequired, isFalse);
  });

  testWidgets('WhatsApp code supports whole-code paste and confirmation',
      (tester) async {
    final api = _VerificationApi();
    PhoneVerificationResult? result;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': '123456'} : null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<PhoneVerificationResult>(
                context: context,
                builder: (_) => PhoneVerifyDialog(
                  api: api,
                  initialPhone: '+91 9876543210',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(api.requestedPhone, '9876543210');
    expect(find.text('We sent a code via WhatsApp to +91 9876543210.'),
        findsOneWidget);

    await tester.tap(find.text('Paste code'));
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.verifiedPhone, '9876543210');
    expect(api.verifiedCode, '123456');
    expect(result?.verified, isTrue);
  });

  testWidgets('SMS response uses SMS delivery copy', (tester) async {
    final api = _VerificationApi()..channel = PhoneOtpChannel.sms;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PhoneVerifyDialog(
                api: api,
                initialPhone: '9876543210',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(api.requestedPhone, '9876543210');
    expect(
        find.text('We sent a code via SMS to +91 9876543210.'), findsOneWidget);
  });

  testWidgets('wrong code error is shown inline', (tester) async {
    final api = _VerificationApi()..verificationError = 'Invalid code.';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PhoneVerifyDialog(
                api: api,
                initialPhone: '9876543210',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Send code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Invalid code.'), findsOneWidget);
  });

  testWidgets('optional verification can be skipped and barrier dismissed',
      (tester) async {
    final api = _VerificationApi();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (_) => PhoneVerifyDialog(api: api, allowSkip: true),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneVerifyDialog), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneVerifyDialog), findsNothing);
  });

  testWidgets('required verification cannot be skipped or barrier dismissed',
      (tester) async {
    final api = _VerificationApi();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => PhoneVerifyDialog(api: api, allowSkip: false),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Skip for now'), findsNothing);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneVerifyDialog), findsOneWidget);
  });

  testWidgets('server retry-after lockout is displayed', (tester) async {
    final api = _VerificationApi()..requestErrorStatus = 429;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PhoneVerifyDialog(
                api: api,
                initialPhone: '9876543210',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Please wait before requesting another code.'),
        findsOneWidget);
    expect(find.text('Please wait 12 seconds before trying again.'),
        findsOneWidget);
    final sendCodeButton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send code'));
    expect(sendCodeButton.onPressed, isNull);
  });

  testWidgets('account code expires after five minutes', (tester) async {
    final api = _VerificationApi();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PhoneVerifyDialog(
                api: api,
                initialPhone: '9876543210',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Verify'))
            .onPressed,
        isNotNull);

    await tester.pump(const Duration(minutes: 5));

    expect(find.text('Code expired. Request a new one.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Verify'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('PHONE_NOT_VERIFIED verifies, refreshes, and retries once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _VerificationApi()..profileVerified = true;
    final controller = AppController(api: api, preferences: preferences)
      ..user = const SessionUser(
        id: 'user-1',
        name: 'Test User',
        username: 'test',
        role: WorkspaceRole.customer,
        phone: '9876543210',
        phoneVerified: false,
        phoneVerificationRequired: true,
      );
    addTearDown(controller.dispose);
    var attempts = 0;
    String? actionResult;
    Object? actionError;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              try {
                actionResult = await runWithPhoneVerificationRetry(
                  context,
                  controller: controller,
                  enabled: true,
                  action: () async {
                    attempts += 1;
                    if (attempts == 1) {
                      throw const ApiException(
                        'Verify your phone first.',
                        403,
                        code: 'PHONE_NOT_VERIFIED',
                      );
                    }
                    return 'retried';
                  },
                );
              } catch (error) {
                actionError = error;
              }
            },
            child: const Text('Run action'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Run action'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(api.verifiedCode, '123456');
    expect(api.profileFetches, 1);
    expect(find.byType(PhoneVerifyDialog), findsNothing);
    expect(controller.user?.phoneVerified, isTrue);
    expect(actionError, isNull);
    expect(actionResult, 'retried');
    expect(attempts, 2);
    expect(find.byType(PhoneVerifyDialog), findsNothing);
  });
}
