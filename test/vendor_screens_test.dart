import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/vendor/operations/vendor_operations_screen.dart';
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
