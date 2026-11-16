import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/screens/invoice_detail_screen.dart';

void main() {
  testWidgets('renders invoice snapshot lines and paise totals',
      (tester) async {
    final invoice = AccountRecord({
      'id': 'invoice-1',
      'number': 'INV-UT-1001',
      'status': 'paid',
      'payment_status': 'paid',
      'subtotal_paise': 250000,
      'tax_paise': 45000,
      'tax_rate': 0.18,
      'discount_paise': 10000,
      'total_paise': 285000,
      'line_items': [
        {
          'description': 'Water tanker · 5000 litres',
          'quantity': 2,
          'subtotalPaise': 250000,
          'taxPaise': 45000,
          'taxRate': 0.18,
          'discountPaise': 10000,
          'totalPaise': 285000,
        },
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerInvoiceProvider('invoice-1')
              .overrideWith((ref) async => invoice),
        ],
        child: const MaterialApp(
          home: InvoiceDetailScreen(invoiceId: 'invoice-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invoice INV-UT-1001'), findsOneWidget);
    expect(find.text('Water tanker · 5000 litres'), findsOneWidget);
    expect(find.text('Quantity: 2'), findsOneWidget);
    expect(find.text('₹450.00'), findsOneWidget);
    expect(find.text('₹100.00'), findsOneWidget);
    expect(find.text('₹2850.00'), findsWidgets);
  });
}
