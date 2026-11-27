import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/screens/partner_application_screen.dart';
import 'package:urban_tanker_app/services/api/partner_api.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _PartnerApiClient extends ApiClient {
  _PartnerApiClient({required this.otpRequired})
    : super(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'https://example.test/api',
      );

  final bool otpRequired;

  @override
  Future<bool> partnerApplicationOtpRequired() async => otpRequired;

  @override
  Future<String> requestPartnerApplicationOtp(String phone) async =>
      'challenge-1';

  @override
  Future<void> verifyPartnerApplicationOtp({
    required String phone,
    required String challengeId,
    required String otp,
  }) async {}

  @override
  Future<PartnerApplicationReceipt> submitPartnerApplication({
    required Map<String, dynamic> application,
  }) async => const PartnerApplicationReceipt(
    reference: 'PA-ABC12345',
    status: 'submitted',
    message: 'Your partnership request was received for review.',
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders application details in both themes at 1.3x text scale', (
    tester,
  ) async {
    final api = _PartnerApiClient(otpRequired: false);
    for (final theme in [buildNewUiLightTheme(), buildNewUiDarkTheme()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: PartnerApplicationScreen(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Become a partner'), findsOneWidget);
      expect(find.text('Business details'), findsOneWidget);
      expect(find.text('Send verification code'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('requires phone verification only when the backend flag is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNewUiLightTheme(),
        home: PartnerApplicationScreen(
          api: _PartnerApiClient(otpRequired: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send verification code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
