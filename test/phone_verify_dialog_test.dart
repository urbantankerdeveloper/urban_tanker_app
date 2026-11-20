import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/screens/auth/phone_verify_dialog.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _VerificationApi extends ApiClient {
  _VerificationApi() : super(baseUrl: 'https://example.test/api');

  PhoneOtpChannel channel = PhoneOtpChannel.whatsapp;
  String? requestedPhone;
  String? verifiedPhone;
  String? verifiedCode;
  String? verificationError;

  @override
  Future<PhoneVerificationChallenge> requestAccountPhoneVerification(
    String phone,
  ) async {
    requestedPhone = phone;
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
}

void main() {
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
}
