import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:urban_tanker_app/services/google_reverse_geocoding_service.dart';

void main() {
  group('GoogleReverseGeocodingService', () {
    test('returns the formatted street address for a successful lookup',
        () async {
      final service = GoogleReverseGeocodingService(
        apiKey: 'test-key',
        request: (uri) async {
          expect(uri.host, 'maps.googleapis.com');
          expect(uri.queryParameters['latlng'], '13.08,80.27');
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {'formatted_address': '12 Test Street, Chennai, Tamil Nadu'}
              ],
            }),
            200,
          );
        },
      );

      expect(
        await service.reverseGeocode(latitude: 13.08, longitude: 80.27),
        '12 Test Street, Chennai, Tamil Nadu',
      );
    });

    test('surfaces denied API access without returning an empty address',
        () async {
      final service = GoogleReverseGeocodingService(
        apiKey: 'test-key',
        request: (_) async => http.Response(
          jsonEncode({'status': 'REQUEST_DENIED', 'results': []}),
          200,
        ),
      );

      await expectLater(
        service.reverseGeocode(latitude: 13.08, longitude: 80.27),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Address lookup is unavailable'),
          ),
        ),
      );
    });
  });
}
