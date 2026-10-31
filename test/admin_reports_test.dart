import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/admin_workspace.dart';

void main() {
  testWidgets('registered vendors expand to show vendor details',
      (tester) async {
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
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatcherVendorsProvider.overrideWith((ref) async => vendors),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdminReportsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registered vendors (2)'), findsOneWidget);
    await tester.tap(find.text('Registered vendors (2)'));
    await tester.pumpAndSettle();

    expect(find.text('North Tankers'), findsOneWidget);
    expect(find.text('north@example.com • verified'), findsOneWidget);
    expect(find.text('South Water'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });
}
