import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/app/theme.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin/admin_pulse_screen.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';
import 'package:urban_tanker_app/screens/auth_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

/// Pumps [home] at [size] with 1.3x text and the given text direction. A small
/// phone is 360 dp wide, and a user may have raised the system text size.
Future<void> _pumpAt(
  WidgetTester tester, {
  required Size size,
  required Widget home,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
        ),
        child: Directionality(
          textDirection: direction,
          child: child!,
        ),
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(360, 640);
  const landscape = Size(640, 360);

  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = AppController(
      api: ApiClient(baseUrl: 'https://example.test/api'),
      preferences: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() => controller.dispose());

  testWidgets('sign-in fits a 360 dp phone at 1.3x text', (tester) async {
    await _pumpAt(
      tester,
      size: phone,
      home: AuthScreen(controller: controller),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in fits a right-to-left layout at 1.3x text',
      (tester) async {
    await _pumpAt(
      tester,
      size: phone,
      direction: TextDirection.rtl,
      home: AuthScreen(controller: controller),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in still fits when the phone is turned sideways',
      (tester) async {
    await _pumpAt(
      tester,
      size: landscape,
      home: AuthScreen(controller: controller),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform pulse fits a 360 dp phone at 1.3x text',
      (tester) async {
    await _pumpAt(
      tester,
      size: phone,
      home: ProviderScope(
        overrides: [
          adminHealthProvider.overrideWith(
            (ref) async => {
              'ok': false,
              'realtime': {'connected': false},
              'storage': {'configured': false},
              'configuration': {'sms': false},
              'migrations': [
                {'table': 'bookings', 'applied': false, 'error': 'missing'},
              ],
            },
          ),
        ],
        child: const Scaffold(body: AdminPulseScreen()),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform pulse fits a right-to-left layout', (tester) async {
    await _pumpAt(
      tester,
      size: phone,
      direction: TextDirection.rtl,
      home: ProviderScope(
        overrides: [
          adminHealthProvider.overrideWith(
            (ref) async => {
              'ok': true,
              'realtime': {'connected': true},
              'storage': {'configured': true},
              'configuration': {'sms': true},
              'migrations': [
                {'table': 'bookings', 'applied': true},
              ],
            },
          ),
        ],
        child: const Scaffold(body: AdminPulseScreen()),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports fit a 360 dp phone at 1.3x text', (tester) async {
    await _pumpAt(
      tester,
      size: phone,
      home: ProviderScope(
        overrides: [
          dispatcherVendorsProvider.overrideWith(
            (ref) async => const <AccountRecord>[],
          ),
        ],
        child: const Scaffold(body: AdminReportsScreen()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
