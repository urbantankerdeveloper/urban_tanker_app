import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('vendor filter recalculates revenue from matching report rows', () {
    final rows = [
      {
        'vendor_id': 'vendor-1',
        'quoted_amount_paise': 12500,
        'service_code': 'WATER',
      },
      {
        'vendor_id': 'vendor-2',
        'quoted_amount_paise': 25000,
        'service_code': 'WATER',
      },
      {
        'vendor_id': 'vendor-1',
        'quoted_amount_paise': 7500,
        'service_code': 'SEWAGE',
      },
    ];

    final filtered = AdminRevenueReport.filterRows(rows, vendorId: 'vendor-1');

    expect(filtered, hasLength(2));
    expect(AdminRevenueReport.total(filtered), 200);
  });

  test('all vendors keeps the complete report', () {
    final rows = [
      {'vendor_id': 'vendor-1', 'quoted_amount_paise': 12500},
      {'vendor_id': 'vendor-2', 'quoted_amount_paise': 25000},
    ];

    expect(AdminRevenueReport.filterRows(rows), hasLength(2));
    expect(AdminRevenueReport.total(rows), 375);
  });

  test('multi-service rows count as one order in the report summary', () {
    final rows = [
      {'id': 'fulfilment-1', 'quoted_amount_paise': 12500},
      {'id': 'fulfilment-1', 'quoted_amount_paise': 7500},
      {'quoted_amount_paise': 5000},
    ];

    expect(AdminRevenueReport.orderCount(rows), 2);
  });

  testWidgets('vendor filter applies to loaded sales rows', (tester) async {
    var reportCalls = 0;
    final reportRequests = <Map<String, dynamic>>[];
    final rows = <Map<String, dynamic>>[
      {
        'vendor_id': 'vendor-1',
        'quoted_amount_paise': 10000,
        'service_code': 'WATER',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'vendor_id': 'vendor-2',
        'quoted_amount_paise': 20000,
        'service_code': 'SEWAGE',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildNewUiLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AdminSalesReportPanel(
                vendors: const [
                  AccountRecord({
                    'id': 'vendor-1',
                    'business_name': 'Vendor A',
                  }),
                  AccountRecord({
                    'id': 'vendor-2',
                    'business_name': 'Vendor B',
                  }),
                ],
                loadReport: (body) async {
                  reportCalls++;
                  reportRequests.add(Map<String, dynamic>.from(body));
                  return {'rows': rows};
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('₹300.00'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(reportCalls, 1);
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    expect(reportRequests.single['from'], todayIso);
    expect(reportRequests.single['to'], todayIso);

    await tester.tap(find.text('All vendors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vendor A'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Vendor A'), findsOneWidget);
    expect(find.text('₹100.00'), findsNWidgets(2));
    expect(reportCalls, 2);
    expect(reportRequests.skip(1).map((request) => request['vendorId']), [
      'vendor-1',
    ]);
  });
}
