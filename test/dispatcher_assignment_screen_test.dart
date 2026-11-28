import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/screens/dispatcher/dispatch_assignment_screen.dart';
import 'package:urban_tanker_app/models/account.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('assignment lists only approved vendors for the order', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatcherVendorsProvider.overrideWith(
            (ref) async => [
              AccountRecord({
                'id': 'vendor-approved',
                'business_name': 'Approved Water Co.',
                'status': 'approved',
              }),
              AccountRecord({
                'id': 'vendor-pending',
                'business_name': 'Pending Water Co.',
                'status': 'pending',
              }),
            ],
          ),
          dispatcherVendorDetailsProvider.overrideWith(
            (ref, vendorId) async =>
                AccountRecord({'id': vendorId, 'vehicles': [], 'drivers': []}),
          ),
        ],
        child: MaterialApp(
          theme: buildNewUiLightTheme(),
          home: DispatchAssignmentScreen(
            rawOrder: {
              'id': 'order-1',
              'reference': 'UT-ORDER-1',
              'status': 'pending_vendor',
              'address_text': '12 Market Road',
              'quoted_amount_paise': 125000,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UT-ORDER-1'), findsOneWidget);
    expect(find.text('Approved Water Co.'), findsNWidgets(2));
    expect(find.text('Pending Water Co.'), findsNothing);
    expect(find.text('Assign vehicle and driver'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
