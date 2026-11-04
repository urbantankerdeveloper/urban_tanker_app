import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/service.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/screens/home/booking/booking_form_sheet.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://example.test/api');

  bool mobileOtpUnavailable = false;
  String? fallbackPhone;
  String? verifiedEmail;

  @override
  Future<PhoneVerificationState> phoneVerification() async =>
      const PhoneVerificationState(phone: '', verified: false);

  @override
  Future<List<AccountRecord>> addresses() async => const [];

  @override
  Future<
      ({
        String? challengeId,
        String? emailChallengeId,
        int resendAfterSeconds
      })> requestBookingOtp({required String phone, String? email}) async {
    if (mobileOtpUnavailable) {
      throw const ApiException(
        'Mobile verification is not configured yet.',
        503,
      );
    }
    return (
      challengeId: 'phone-challenge',
      emailChallengeId: null,
      resendAfterSeconds: 30,
    );
  }

  @override
  Future<String> requestRegisteredBookingEmailOtp({
    required String phone,
  }) async {
    fallbackPhone = phone;
    return 'registered-email-challenge';
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    String? challengeId,
    String? otp,
    String? email,
    String? emailChallengeId,
    String? emailOtp,
  }) async {
    verifiedEmail = email;
  }
}

const _tanker = TankerService(
  id: 'water_tanker',
  name: 'Water tanker',
  description: 'Bulk water delivery',
  category: 'Water',
  capacityOptions: ['5000 litres'],
  waterTypeOptions: ['Potable'],
  tankerCountOptions: ['1 tanker'],
);

void main() {
  testWidgets('booking falls back to the registered email when SMS is off',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final api = _FakeApi()..mobileOtpUnavailable = true;
    final controller = AppController(api: api, preferences: preferences!);
    controller.user = const SessionUser(
      id: 'user-1',
      name: 'Registered User',
      username: 'registered',
      role: WorkspaceRole.customer,
      email: 'registered@example.com',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openBookingForm(
                context,
                controller: controller,
                serviceCatalog: const [_tanker],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(api.fallbackPhone, '9876543210');
    expect(
      find.text(
          'SMS is unavailable. A verification code was sent to your registered email.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Email code',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();
    expect(api.verifiedEmail, 'registered@example.com');
    expect(find.text('Number verified'), findsOneWidget);
  });

  testWidgets('the booking flow moves step by step and validates each step',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: _FakeApi(),
      preferences: preferences!,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openBookingForm(
                  context,
                  controller: controller,
                  serviceCatalog: const [_tanker],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 1 of 6: Contact'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Book a delivery')).dy,
      inInclusiveRange(1600 * 0.30, 1600 * 0.40),
    );

    // An empty phone number cannot move past the first step.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    expect(find.textContaining('Step 1 of 6'), findsOneWidget);

    // A valid number moves on to the services step.
    await tester.enterText(
      find.byType(TextFormField).first,
      '9876543210',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 2 of 6: Services'), findsOneWidget);

    // Services need at least one selection before the next step.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Select at least one service.'), findsOneWidget);
    expect(find.textContaining('Step 2 of 6'), findsOneWidget);

    // Back returns to the contact step, and the phone number is kept.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 6'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });
}
