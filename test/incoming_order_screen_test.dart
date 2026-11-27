import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/vendor/operations/incoming_order_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('auto-declines an unanswered order after the response window', (
    tester,
  ) async {
    var timedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => IncomingOrderScreen(
                  order: _order,
                  onAccept: () async {},
                  onDecline: () async {},
                  onTimeout: () async {
                    timedOut = true;
                  },
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('00:45'), findsOneWidget);
    await tester.pump(IncomingOrderScreen.responseWindow);
    await tester.pump();

    expect(timedOut, isTrue);
    expect(find.text('00:45'), findsNothing);
  });

  testWidgets('fits narrow screens at 1.3 text scaling in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [buildNewUiLightTheme(), buildNewUiDarkTheme()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: IncomingOrderScreen(
            order: _order,
            onAccept: () async {},
            onDecline: () async {},
            onTimeout: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}

const _order = VendorOrder(
  id: 'order-1',
  reference: 'UT-100',
  serviceCode: 'WATER',
  address: '12 River Road',
  status: 'pending_vendor',
  amountPaise: 250000,
  createdAt: null,
  scheduledFor: null,
);
