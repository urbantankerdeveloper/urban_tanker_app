import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin/admin_reports_screen.dart';

void main() {
  testWidgets('registered vendors expand to show vendor details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vendors = [
      const AccountRecord({
        'id': 'vendor-1',
        'business_name': 'North Tankers',
        'email': 'north@example.com',
        'status': 'verified',
      }),
      const AccountRecord({
        'id': 'vendor-2',
        'companyName': 'South Water',
        'phone': '9876543210',
      }),
      const AccountRecord({'id': 'vendor-secret'}),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatcherVendorsProvider.overrideWith((ref) async => vendors),
        ],
        child: MaterialApp(
          home: Scaffold(body: AdminReportsScreen(loadReport: (_) async => {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Registered vendors (3)'), findsOneWidget);
    await tester.tap(find.text('Registered vendors (3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('North Tankers'), findsOneWidget);
    expect(find.text('north@example.com • verified'), findsOneWidget);
    expect(find.text('South Water'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Unnamed vendor'), findsOneWidget);
    expect(find.text('vendor-secret'), findsNothing);
  });
}
