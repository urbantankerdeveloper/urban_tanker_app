import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin/admin_pulse_screen.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';
import 'package:urban_tanker_app/screens/admin/operations/admin_common.dart';

void main() {
  test('only labels that mention a password hide their text', () {
    expect(isPasswordLabel('Password'), isTrue);
    expect(isPasswordLabel('Confirm password'), isTrue);
    expect(isPasswordLabel('Email'), isFalse);
  });

  testWidgets('pulse shows each health area as a tile', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminHealthProvider.overrideWith(
            (ref) async => {
              'ok': true,
              'realtime': {'connected': false},
              'storage': {'configured': true},
              'configuration': {'sms': true, 'payments': false},
              'migrations': [
                {'table': 'bookings', 'applied': true},
              ],
            },
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: AdminPulseScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Configured'), findsOneWidget);
    expect(find.text('1 to review'), findsOneWidget);
    expect(find.text('bookings'), findsOneWidget);
    expect(find.text('Configuration warnings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports offer the three ranges and start on today',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatcherVendorsProvider.overrideWith(
            (ref) async => const <AccountRecord>[],
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: AdminReportsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('Run report'), findsOneWidget);
    expect(find.text('Registered vendors (0)'), findsOneWidget);
  });
}
