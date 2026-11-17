import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/screens/home/booking/booking_fields.dart';

void main() {
  testWidgets('delivery location has a visible choose-on-map action',
      (tester) async {
    final fields = BookingServiceFields(quantity: '1000');
    addTearDown(fields.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              child: DeliveryLocationField(
                fields: fields,
                addressGeocodingEnabled: false,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.byTooltip('Use current location'), findsOneWidget);
  });
}
