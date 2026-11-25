import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/admin/admin_pulse_screen.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';
import 'package:urban_tanker_app/screens/admin/operations/admin_common.dart';
import 'package:urban_tanker_app/screens/admin/operations/people_section.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _ApprovalApiClient extends ApiClient {
  @override
  Future<List<AccountRecord>> adminVendors() async => [
        const AccountRecord({
          'id': 'vendor-waiting',
          'business_name': 'Waiting Vendor',
          'verification': 'pending',
        }),
        const AccountRecord({
          'id': 'vendor-approved',
          'business_name': 'Approved Vendor',
          'verification': 'approved',
          'full_name': 'Asha Kumar',
          'mobile_e164': '+919876543210',
          'is_active': true,
          'from': 'Chennai',
        }),
      ];

  @override
  Future<List<AccountRecord>> adminCustomers() async => [];

  @override
  Future<List<AdminFleetVehicle>> adminVehicles() async => [
        const AdminFleetVehicle(
          id: 'vehicle-waiting',
          vendorId: 'vendor-1',
          registrationNumber: 'WAIT 1',
          capacityLitres: 10000,
          active: false,
          verification: 'pending',
        ),
        const AdminFleetVehicle(
          id: 'vehicle-approved',
          vendorId: 'vendor-1',
          registrationNumber: 'APPROVED 1',
          capacityLitres: 10000,
          active: true,
          verification: 'approved',
          data: {
            'registration_number': 'APPROVED 1',
            'chassis_number': 'CH-123',
          },
        ),
      ];

  @override
  Future<List<AdminFleetDriver>> adminDrivers() async => [
        const AdminFleetDriver(
          id: 'driver-waiting',
          vendorId: 'vendor-1',
          name: 'Waiting Driver',
          mobile: '+919876543210',
          active: false,
          verification: 'pending',
        ),
        const AdminFleetDriver(
          id: 'driver-approved',
          vendorId: 'vendor-1',
          name: 'Approved Driver',
          mobile: '+919876543211',
          active: true,
          verification: 'approved',
          data: {
            'name': 'Approved Driver',
            'mobile_e164': '+919876543211',
            'licence_number': 'DL-1234567',
          },
        ),
      ];
}

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
              'realtime': {'configured': true, 'connected': 0},
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
    expect(find.text('Available'), findsNWidgets(2));
    expect(find.text('Not configured'), findsNothing);
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

  testWidgets('admin vendor and fleet lists split waiting and approved rows',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: _ApprovalApiClient(),
      preferences: preferences!,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: AdminPeopleSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting Vendor'), findsOneWidget);
    expect(find.text('Approved Vendor'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);

    Future<void> selectStatus(String label) async {
      final tabs = find.byType(SegmentedTabs).last;
      await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await selectStatus('Approved');
    expect(find.text('Waiting Vendor'), findsNothing);
    expect(find.text('Approved Vendor'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Suspend'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved Vendor'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Name: Asha Kumar'), findsOneWidget);
    expect(find.textContaining('Phone: +919876543210'), findsOneWidget);
    expect(find.textContaining('Active: Yes'), findsOneWidget);
    expect(find.textContaining('From: Chennai'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs).first,
        matching: find.text('Vehicles'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WAIT 1'), findsOneWidget);
    expect(find.text('APPROVED 1'), findsNothing);
    expect(find.byType(PopupMenuButton<(String, bool)>), findsOneWidget);

    await selectStatus('Approved');
    expect(find.text('WAIT 1'), findsNothing);
    expect(find.text('APPROVED 1'), findsOneWidget);
    expect(find.byType(PopupMenuButton<(String, bool)>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<(String, bool)>));
    await tester.pumpAndSettle();
    expect(find.text('Approve and activate'), findsNothing);
    expect(find.text('Suspend and deactivate'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPROVED 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chassis number: CH-123'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs).first,
        matching: find.text('Drivers'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting Driver'), findsOneWidget);
    expect(find.text('Approved Driver'), findsNothing);
    expect(find.byType(PopupMenuButton<(String, bool)>), findsOneWidget);

    await selectStatus('Approved');
    expect(find.text('Waiting Driver'), findsNothing);
    expect(find.text('Approved Driver'), findsOneWidget);
    expect(find.byType(PopupMenuButton<(String, bool)>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<(String, bool)>));
    await tester.pumpAndSettle();
    expect(find.text('Approve and activate'), findsNothing);
    expect(find.text('Suspend and deactivate'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved Driver'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Licence number: DL-1234567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
