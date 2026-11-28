import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/screens/home/customer/active_order_widget.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the active booking above navigation', (tester) async {
    await tester.pumpWidget(_appWithBookings([_booking('en_route')]));
    await tester.pump();

    expect(find.text('UT-100'), findsOneWidget);
    expect(find.byTooltip('Expand active delivery'), findsOneWidget);
  });

  testWidgets('hides the widget when all bookings are finished', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithBookings([_booking('delivered')]));
    await tester.pump();

    expect(find.byType(ActiveOrderWidget), findsOneWidget);
    expect(find.text('UT-100'), findsNothing);
  });

  testWidgets('expanded tracking stays usable at 1.3 text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingsProvider.overrideWith(
            () => _BookingsTestNotifier([_booking('en_route')]),
          ),
          bookingTrackingProvider.overrideWith(
            (ref, id) async => TrackingSnapshot(
              orderId: id,
              status: 'en_route',
              trackingAvailable: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildNewUiLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActiveOrderWidget(),
                AppBottomNav(
                  items: [AppNavItem(label: 'Home', icon: Icons.home_outlined)],
                  selectedIndex: 0,
                  onSelected: _ignoreIndex,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand active delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Track live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreIndex(int _) {}

Widget _appWithBookings(List<Booking> bookings) => ProviderScope(
  overrides: [
    bookingsProvider.overrideWith(() => _BookingsTestNotifier(bookings)),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(),
      bottomNavigationBar: ActiveOrderWidget(),
    ),
  ),
);

Booking _booking(String status) => Booking(
  id: 'order-1',
  reference: 'UT-100',
  status: status,
  location: '12 River Road',
  capacity: '5000',
  deliveryDate: DateTime(2026, 8, 24, 14),
  createdAt: DateTime(2026, 8, 23),
);

class _BookingsTestNotifier extends BookingsNotifier {
  _BookingsTestNotifier(this.bookings);

  final List<Booking> bookings;

  @override
  Future<BookingsState> build() async => BookingsState(items: bookings);
}
