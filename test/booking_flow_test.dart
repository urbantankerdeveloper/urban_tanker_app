import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/service.dart';
import 'package:urban_tanker_app/screens/home/booking/booking_form_sheet.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://example.test/api');

  @override
  Future<PhoneVerificationState> phoneVerification() async =>
      const PhoneVerificationState(phone: '', verified: false);

  @override
  Future<List<AccountRecord>> addresses() async => const [];
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
