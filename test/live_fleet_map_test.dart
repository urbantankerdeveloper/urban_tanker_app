import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide LatLngTween;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urban_tanker_app/screens/common/live_fleet_map.dart';
import 'package:urban_tanker_app/screens/common/map_coordinates.dart';
import 'package:urban_tanker_app/screens/common/map_provider_resolver.dart';

void main() {
  group('MapProviderResolver', () {
    test('uses Google Maps only when a key and supported platform are present',
        () {
      final configured = MapProviderResolver(
        apiKey: 'configured-key',
        platformSupported: true,
      );
      final missing = MapProviderResolver(
        apiKey: '',
        platformSupported: true,
      );
      addTearDown(configured.dispose);
      addTearDown(missing.dispose);

      expect(configured.useGoogleMaps, isTrue);
      expect(missing.useGoogleMaps, isFalse);
    });

    test('keeps Google Maps disabled after it is marked unavailable', () {
      final resolver = MapProviderResolver(
        apiKey: 'configured-key',
        platformSupported: true,
      );
      addTearDown(resolver.dispose);

      resolver.markUnavailable();
      resolver.markUnavailable();

      expect(resolver.useGoogleMaps, isFalse);
    });
  });

  test('vehicle marker tween reaches its target', () {
    const start = LatLng(13, 80);
    const finish = LatLng(14, 81);
    final tween = LatLngTween(begin: start, end: finish);

    expect(tween.transform(0.5), const LatLng(13.5, 80.5));
    expect(tween.transform(1), finish);
  });

  test('bearing is north for a northbound coordinate pair', () {
    expect(
      bearingBetween(const LatLng(0, 0), const LatLng(1, 0)),
      closeTo(0, 0.0001),
    );
    expect(
      bearingBetween(const LatLng(0, 0), const LatLng(0, 1)),
      closeTo(90, 0.0001),
    );
  });

  testWidgets('renders OSM when no Google Maps key is configured',
      (tester) async {
    final resolver = MapProviderResolver(
      apiKey: '',
      platformSupported: true,
    );
    addTearDown(resolver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 320,
          child: LiveFleetMap(
            vehicle: const LatLng(13.0827, 80.2707),
            destination: null,
            timeline: const [],
            lastUpdated: null,
            resolver: resolver,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
