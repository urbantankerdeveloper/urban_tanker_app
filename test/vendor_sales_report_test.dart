import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/screens/vendor/vendor_sales_report.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders report data from its repository', (tester) async {
    final repository = _FakeVendorSalesReportRepository();
    await tester.pumpWidget(_app(repository));
    await tester.tap(find.text('View report'));
    await tester.pumpAndSettle();

    expect(repository.requestedPeriod, VendorSalesPeriod.day);
    expect(find.text('₹154.00'), findsNWidgets(2));
    expect(find.text('Up 100.0% vs previous period.'), findsOneWidget);
    expect(find.text('WATER'), findsOneWidget);
  });

  testWidgets('renders report data returned by the backend repository', (
    tester,
  ) async {
    String? requestedPeriod;
    final repository = ApiVendorSalesReportRepository((period) async {
      requestedPeriod = period;
      return {
        'totalPaise': 15400,
        'previousTotalPaise': 7700,
        'orderCount': 2,
        'dailyTotalsPaise': [1000, 14400],
        'breakdown': [
          {'service': 'WATER', 'orders': 2, 'amountPaise': 15400},
        ],
      };
    });
    await tester.pumpWidget(_app(repository));
    await tester.tap(find.text('View report'));
    await tester.pumpAndSettle();

    expect(requestedPeriod, 'day');
    expect(find.text('₹154.00'), findsNWidgets(2));
    expect(find.text('WATER'), findsOneWidget);
  });

  test('rejects malformed report responses', () async {
    final repository = ApiVendorSalesReportRepository(
      (_) async => {'totalPaise': 0},
    );

    await expectLater(
      repository.load(VendorSalesPeriod.day),
      throwsA(isA<FormatException>()),
    );
  });
}

Widget _app(VendorSalesReportRepository repository) => ProviderScope(
  overrides: [
    vendorSalesReportRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: buildNewUiLightTheme(),
    home: const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: VendorSalesReportCard(),
      ),
    ),
  ),
);

class _FakeVendorSalesReportRepository implements VendorSalesReportRepository {
  VendorSalesPeriod? requestedPeriod;

  @override
  Future<VendorSalesReport> load(VendorSalesPeriod period) async {
    requestedPeriod = period;
    return const VendorSalesReport(
      totalPaise: 15400,
      previousTotalPaise: 7700,
      orderCount: 2,
      dailyTotalsPaise: [1000, 14400],
      breakdown: [
        VendorSalesBreakdown(service: 'WATER', orders: 2, amountPaise: 15400),
      ],
    );
  }
}
