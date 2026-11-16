import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin/admin_pulse_screen.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';
import 'package:urban_tanker_app/screens/admin/operations/admin_common.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = AppController(
      api: ApiClient(baseUrl: 'https://example.test/api'),
      preferences: await SharedPreferences.getInstance(),
    );
  });

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
          appControllerProvider.overrideWith((ref) => controller),
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
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      AppPageInsets.standard,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard flag shows live operational and area summaries',
      (tester) async {
    controller.featureFlags = {
      'admin_dashboard_v2_enabled': true,
      'area_availability_enabled': true,
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          adminHealthProvider.overrideWith((ref) async => {
                'ok': true,
                'realtime': {'connected': true},
                'storage': {'configured': true},
                'configuration': {'sms': true},
                'migrations': [],
              }),
          adminDashboardSummaryProvider.overrideWith((ref) async => {
                'activeOrdersByStatus': {
                  'pending_vendor': 2,
                  'vendor_assigned': 1,
                  'accepted': 0,
                  'en_route': 1,
                  'arrived': 0,
                },
                'todayRevenuePaise': 12500,
                'pendingPartnerApplications': 3,
                'onlineVendors': 4,
                'activeDrivers': 5,
                'openOrderAlerts': 1,
                'failedPayments': 2,
                'stuckOrders': 1,
                'generatedAt': '2026-11-16T05:00:00.000Z',
              }),
          adminAvailabilityByAreaProvider.overrideWith((ref) async => [
                {
                  'area': 'Chennai North',
                  'onlineVendors': 2,
                  'activeVehicles': 3,
                  'activeDrivers': 4,
                },
              ]),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: AdminPulseScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations dashboard'), findsOneWidget);
    expect(find.text('₹125.00'), findsOneWidget);
    expect(find.text('Active orders by status'), findsOneWidget);
    expect(find.text('Availability by service area'), findsOneWidget);
    expect(find.text('Chennai North'), findsOneWidget);
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
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      AppPageInsets.standard,
    );
  });
}
