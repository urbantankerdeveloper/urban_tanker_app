import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/customer_account_screen.dart';
import 'package:urban_tanker_app/screens/vendor/operations/vendor_operations_screen.dart';
import 'package:urban_tanker_app/screens/vendor/fleet/vendor_fleet_screen.dart';
import 'package:urban_tanker_app/screens/vendor/vendor_earnings_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

VendorPayout _payout(String id, int paise, DateTime createdAt) =>
    VendorPayout.fromJson({
      'id': id,
      'amount_paise': paise,
      'status': 'paid',
      'reference': 'PO-$id',
      'created_at': createdAt.toIso8601String(),
    });

VendorOrder _order(String id, String status) =>
    VendorOrder.fromJson({'id': id, 'status': status});

/// The value shown in the stat card labelled [label].
String _statValue(WidgetTester tester, String label) {
  final card = find
      .ancestor(
        of: find.text(label),
        matching: find.byType(StatCard),
      )
      .first;
  return tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((text) => text.data)
      .firstWhere((text) => text != label, orElse: () => '')!;
}

void main() {
  testWidgets('customer account starts its independent sections together',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences!,
    );
    final started = <String>{};

    Future<T> pending<T>(String name, Completer<T> completer) {
      started.add(name);
      return completer.future;
    }

    final profile = Completer<CustomerProfile>();
    final usage = Completer<CustomerUsage>();
    final membership = Completer<AccountRecord?>();
    final offers = Completer<List<AccountRecord>>();
    final wallet = Completer<List<AccountRecord>>();
    final invoices = Completer<List<AccountRecord>>();
    final subscriptions = Completer<List<AccountRecord>>();
    final contracts = Completer<List<AccountRecord>>();
    final addresses = Completer<List<AccountRecord>>();
    final support = Completer<List<AccountRecord>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          customerProfileProvider
              .overrideWith((ref) => pending('profile', profile)),
          customerUsageProvider.overrideWith((ref) => pending('usage', usage)),
          customerMembershipProvider
              .overrideWith((ref) => pending('membership', membership)),
          customerOffersProvider
              .overrideWith((ref) => pending('offers', offers)),
          customerWalletProvider
              .overrideWith((ref) => pending('wallet', wallet)),
          customerInvoicesProvider
              .overrideWith((ref) => pending('invoices', invoices)),
          customerSubscriptionsProvider
              .overrideWith((ref) => pending('subscriptions', subscriptions)),
          customerContractsProvider
              .overrideWith((ref) => pending('contracts', contracts)),
          customerAddressesProvider
              .overrideWith((ref) => pending('addresses', addresses)),
          customerSupportProvider
              .overrideWith((ref) => pending('support', support)),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: CustomerAccountScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(
      started,
      containsAll({
        'profile',
        'usage',
        'membership',
        'offers',
        'wallet',
        'invoices',
        'subscriptions',
        'contracts',
        'addresses',
        'support',
      }),
    );
    expect(find.byType(SkeletonBox), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('operations starts saved updates while orders are loading',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences!,
    );
    final orders = Completer<List<VendorOrder>>();
    final updates = Completer<List<VendorOfflineMutation>>();
    var ordersStarted = false;
    var updatesStarted = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          vendorOrdersProvider.overrideWith((ref) {
            ordersStarted = true;
            return orders.future;
          }),
          vendorOfflineMutationsProvider.overrideWith((ref) {
            updatesStarted = true;
            return updates.future;
          }),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: VendorOperationsScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(ordersStarted, isTrue);
    expect(updatesStarted, isTrue);
    expect(find.text('Loading your orders...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('fleet starts independent requests while dashboard is loading',
      (tester) async {
    final dashboard = Completer<VendorDashboard>();
    final services = Completer<List<VendorService>>();
    final attendance = Completer<List<Map<String, dynamic>>>();
    final complaints = Completer<List<Map<String, dynamic>>>();
    final documents = Completer<List<Map<String, dynamic>>>();
    var dashboardStarted = false;
    var servicesStarted = false;
    var attendanceStarted = false;
    var complaintsStarted = false;
    var documentsStarted = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorDashboardProvider.overrideWith((ref) {
            dashboardStarted = true;
            return dashboard.future;
          }),
          vendorServicesProvider.overrideWith((ref) {
            servicesStarted = true;
            return services.future;
          }),
          vendorAttendanceProvider.overrideWith((ref, date) {
            attendanceStarted = true;
            return attendance.future;
          }),
          vendorComplaintsProvider.overrideWith((ref) {
            complaintsStarted = true;
            return complaints.future;
          }),
          vendorDocumentsProvider.overrideWith((ref) {
            documentsStarted = true;
            return documents.future;
          }),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: VendorFleetScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(dashboardStarted, isTrue);
    expect(servicesStarted, isTrue);
    expect(attendanceStarted, isTrue);
    expect(complaintsStarted, isTrue);
    expect(documentsStarted, isTrue);
    expect(find.text('Loading your fleet...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('earnings total follows the period filter', (tester) async {
    final now = DateTime.now();
    final payouts = [
      _payout('new', 100000, now),
      _payout('old', 50000, now.subtract(const Duration(days: 60))),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vendorPayoutsProvider.overrideWith((ref) async => payouts)],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: VendorEarningsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹1500.00'), findsOneWidget);

    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    expect(find.text('₹1000.00'), findsWidgets);
    expect(find.text('₹1500.00'), findsNothing);
    expect(find.text('₹500.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operations summary counts orders in each group', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences!,
    );
    final orders = [
      _order('1', 'pending_vendor'),
      _order('2', 'vendor_assigned'),
      _order('3', 'en_route'),
      _order('4', 'delivered'),
      _order('5', 'delivered'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          vendorOrdersProvider.overrideWith((ref) async => orders),
          vendorOfflineMutationsProvider
              .overrideWith((ref) async => <VendorOfflineMutation>[]),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: VendorOperationsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_statValue(tester, 'Needs action'), '2');
    expect(_statValue(tester, 'In progress'), '1');
    expect(_statValue(tester, 'Completed'), '2');
    expect(find.text('5 of 5 orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
