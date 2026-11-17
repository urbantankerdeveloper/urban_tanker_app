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
  bool bookingPhoneVerificationRequired = true;
  String accountPhone = '';
  bool accountPhoneVerified = false;
  String? fallbackPhone;
  String? requestedBookingEmail;
  String? verifiedEmail;
  String? verifiedChallengeId;
  String? verifiedChannel;
  String? sentPhoneChallengeId;
  String? verifiedEmailChallengeId;

  @override
  Future<PhoneVerificationState> phoneVerification() async =>
      PhoneVerificationState(
        phone: accountPhone,
        verified: accountPhoneVerified,
        required: bookingPhoneVerificationRequired,
      );

  @override
  Future<List<AccountRecord>> addresses() async => const [];

  @override
  Future<
      ({
        String? challengeId,
        String? emailChallengeId,
        bool phoneOtpSent,
        bool emailOtpSent,
        int resendAfterSeconds
      })> requestBookingOtp({required String phone, String? email}) async {
    requestedBookingEmail = email;
    if (mobileOtpUnavailable) {
      throw const ApiException(
        'Mobile verification is not configured yet.',
        503,
      );
    }
    return (
      challengeId: 'phone-challenge',
      emailChallengeId: email == null ? null : 'email-challenge',
      phoneOtpSent: true,
      emailOtpSent: email != null,
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
  Future<String> verifyPhoneOtp({
    required String phone,
    required String challengeId,
    required String otp,
    required String verificationChannel,
    String? email,
    String? phoneChallengeId,
    String? emailChallengeId,
  }) async {
    verifiedEmail = email;
    verifiedChallengeId = challengeId;
    verifiedChannel = verificationChannel;
    sentPhoneChallengeId = phoneChallengeId;
    verifiedEmailChallengeId = emailChallengeId;
    return emailChallengeId ?? challengeId;
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
  testWidgets('disabled booking verification uses the profile phone',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final api = _FakeApi()
      ..bookingPhoneVerificationRequired = false
      ..accountPhone = '9876543210'
      ..accountPhoneVerified = true;
    final controller = AppController(api: api, preferences: preferences!);
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

    expect(find.text('Using your account phone: 9876543210'), findsOneWidget);
    expect(find.text('Send OTP'), findsNothing);
  });

  testWidgets('home-selected service is preselected in the booking form',
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
            body: TextButton(
              onPressed: () => openBookingForm(
                context,
                controller: controller,
                serviceCatalog: const [_tanker],
                initialServiceId: _tanker.id,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      '9876543210',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 2 of 6: Services'), findsOneWidget);
    expect(find.byTooltip('Remove Water tanker'), findsOneWidget);
  });

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
    controller.featureFlags = {'booking_email_otp_enabled': false};
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
            widget is TextField &&
            widget.decoration?.labelText == '6-digit code',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == '6-digit code',
      ),
      '123456',
    );
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();
    expect(api.verifiedEmail, 'registered@example.com');
    expect(api.verifiedChallengeId, 'registered-email-challenge');
    expect(api.verifiedChannel, 'email');
    expect(find.text('Number verified'), findsOneWidget);
  });

  testWidgets('booking verifies with a code sent to the entered email',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final api = _FakeApi();
    final controller = AppController(api: api, preferences: preferences!);
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
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'booking@example.com',
    );
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(api.requestedBookingEmail, 'booking@example.com');
    expect(find.text('Code sent to'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == '6-digit code',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == '6-digit code',
      ),
      '123456',
    );
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    expect(api.verifiedEmail, 'booking@example.com');
    expect(api.verifiedChallengeId, 'email-challenge');
    expect(api.verifiedChannel, 'email');
    expect(api.sentPhoneChallengeId, 'phone-challenge');
    expect(api.verifiedEmailChallengeId, 'email-challenge');
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
