import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/screens/public_tracking_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _TrackingApi extends ApiClient {
  _TrackingApi(this.snapshot) : super(baseUrl: 'https://example.test/api');

  PublicTrackingSnapshot snapshot;

  @override
  Future<PublicTrackingSnapshot> publicTracking(String token) async => snapshot;
}

Widget _screen(ApiClient api) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PublicTrackingScreen(
          token: 'tracking-token',
          api: api,
        ),
      ),
    );

PublicTrackingSnapshot _snapshot({
  TrackingLocation? location,
  bool trackingAvailable = true,
}) =>
    PublicTrackingSnapshot(
      bookingReference: 'UT-1001',
      status: 'en_route',
      expectedDelivery: null,
      vehicle: 'TN-01-AB-1234',
      driver: 'Driver',
      lastLocation: location,
      events: const [],
      trackingAvailable: trackingAvailable,
    );

void main() {
  testWidgets('map pauses following after a pan and recenters on request',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        _TrackingApi(
          _snapshot(
            location: const TrackingLocation(
              latitude: 13.0827,
              longitude: 80.2707,
              accuracy: 18,
              recordedAt: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byTooltip('Center on vehicle'), findsNothing);

    await tester.drag(find.byType(FlutterMap), const Offset(-100, 0));
    await tester.pump();
    expect(find.byTooltip('Center on vehicle'), findsOneWidget);

    await tester.tap(find.byTooltip('Center on vehicle'));
    await tester.pump();
    expect(find.byTooltip('Center on vehicle'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invalid vehicle coordinates show the waiting placeholder',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        _TrackingApi(
          _snapshot(
            location: const TrackingLocation(
              latitude: 95,
              longitude: 80.2707,
              accuracy: 18,
              recordedAt: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Waiting for vehicle location'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map can appear when a vehicle location arrives later',
      (tester) async {
    final api = _TrackingApi(_snapshot(trackingAvailable: false));
    await tester.pumpWidget(_screen(api));
    await tester.pump();
    expect(find.byType(FlutterMap), findsNothing);

    api.snapshot = _snapshot(
      location: const TrackingLocation(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracy: 18,
        recordedAt: null,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
