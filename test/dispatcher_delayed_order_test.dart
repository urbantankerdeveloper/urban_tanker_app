import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/core/design_system/widgets/surfaces.dart';
import 'package:urban_tanker_app/screens/dispatcher/delayed_order_screen.dart';
import 'package:urban_tanker_app/screens/dispatcher/dispatch_order_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('delayed dispatch card opens the action-focused order screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildNewUiLightTheme(),
          home: Scaffold(
            body: DispatchOrderCard(
              raw: {
                'id': 'order-1',
                'reference': 'UT-ORDER-1',
                'status': 'en_route',
                'service_code': 'water_tanker',
                'address_text': '12 Market Road',
                'quoted_amount_paise': 125000,
                'scheduled_for': DateTime.now()
                    .subtract(const Duration(hours: 1))
                    .toIso8601String(),
                'driver_id': 'driver-1',
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SurfaceCard));
    await tester.pumpAndSettle();

    expect(find.byType(DelayedOrderScreen), findsOneWidget);
    expect(find.text('UT-ORDER-1'), findsOneWidget);
    expect(find.text('12 Market Road'), findsOneWidget);
    expect(find.text('Call driver'), findsOneWidget);
    expect(find.text('Notify customer'), findsOneWidget);
    expect(find.text('Reassign order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
