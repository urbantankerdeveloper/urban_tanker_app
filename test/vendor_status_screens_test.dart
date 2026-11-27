import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/vendor/operations/order_accepted_screen.dart';
import 'package:urban_tanker_app/screens/vendor/operations/vendor_status_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'renders approval, rejection, and offline states in both themes',
    (tester) async {
      final states = [
        (
          verification: 'pending',
          isOnline: false,
          title: 'Your application is under review',
        ),
        (
          verification: 'rejected',
          isOnline: false,
          title: 'Application not approved',
        ),
        (verification: 'approved', isOnline: false, title: 'You are offline'),
      ];

      for (final theme in [buildNewUiLightTheme(), buildNewUiDarkTheme()]) {
        for (final state in states) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: VendorStatusScreen(
                profile: VendorBusinessProfile(
                  id: 'vendor-1',
                  businessName: 'North Tankers',
                  serviceZone: 'North district',
                  verification: state.verification,
                  isOnline: state.isOnline,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(state.title), findsOneWidget);
          expect(find.text('North Tankers'), findsOneWidget);
          expect(find.text('Back to operations'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'accepted order confirmation uses the order data in both themes',
    (tester) async {
      final order = VendorOrder(
        id: 'order-1',
        reference: 'UT-100',
        serviceCode: 'water_tanker',
        address: '12 River Road',
        status: 'accepted',
        amountPaise: 250000,
        createdAt: null,
        scheduledFor: DateTime(2026, 11, 28, 9),
      );

      for (final theme in [buildNewUiLightTheme(), buildNewUiDarkTheme()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: VendorOrderAcceptedScreen(order: order),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Order accepted'), findsNWidgets(2));
        expect(find.textContaining('UT-100'), findsOneWidget);
        expect(find.text('12 River Road'), findsOneWidget);
        expect(find.text('₹2500.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
