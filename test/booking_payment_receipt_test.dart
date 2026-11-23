import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/payment.dart';
import 'package:urban_tanker_app/screens/booking_details_screen.dart';

Widget _host(PaymentReceipt? receipt, {bool canPayOnline = true}) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(
      body: PaymentReceiptSection(
        future: Future.value(receipt),
        showCheckAction: true,
        canPayOnline: canPayOnline,
        isPayingOnline: false,
        onCheck: () {},
        onPayOnline: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('a successful status check displays receipt and payment details',
      (tester) async {
    await tester.pumpWidget(
      _host(
        PaymentReceipt(
          status: 'paid',
          amountPaise: 185000,
          currency: 'INR',
          method: 'upi',
          vpa: 'customer@bank',
          capturedAt: DateTime(2026, 11, 23, 9, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amount paid'), findsOneWidget);
    expect(find.text('₹1850.00'), findsOneWidget);
    expect(find.text('UPI (customer@bank)'), findsOneWidget);
    expect(find.text('Paid at'), findsOneWidget);
    expect(find.text('Pay online now'), findsNothing);
    expect(find.text('Check payment status'), findsNothing);
  });

  testWidgets('an unsuccessful check offers online payment', (tester) async {
    await tester.pumpWidget(
      _host(
        const PaymentReceipt(
          status: 'failed',
          amountPaise: 185000,
          currency: 'INR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check payment status'), findsOneWidget);
    expect(find.text('Pay online now'), findsOneWidget);
  });

  testWidgets('a pending payment asks the customer to check again first',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const PaymentReceipt(
          status: 'pending',
          amountPaise: 185000,
          currency: 'INR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment confirmation is pending'), findsOneWidget);
    expect(find.text('Check payment status'), findsOneWidget);
    expect(find.text('Pay online now'), findsNothing);
  });
}
