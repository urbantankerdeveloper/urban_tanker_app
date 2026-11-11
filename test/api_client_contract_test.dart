import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api_client.dart';

/// Skips secure storage so the tests run without platform channels.
class _SignedInApiClient extends ApiClient {
  _SignedInApiClient({required http.Client client})
      : super(client: client, baseUrl: 'https://example.test/api');

  @override
  Future<String?> readAccessToken() async => 'access-token';
}

Map<String, dynamic> _booking(String id) => {
      'id': id,
      'reference': 'UT-$id',
      'status': 'pending',
      'location': '12 Main Street',
      'capacity_litres': 5000,
      'created_at': '2026-10-21T09:00:00Z',
    };

void main() {
  test('bookings follows nextOffset until the server reports no more pages',
      () async {
    final offsets = <String?>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/customer/orders');
      offsets.add(request.url.queryParameters['offset']);
      expect(int.parse(request.url.queryParameters['pageSize']!),
          lessThanOrEqualTo(100));
      final offset = request.url.queryParameters['offset'];
      if (offset == '0') {
        return http.Response(
          jsonEncode({
            'rows': [_booking('a')],
            'nextOffset': 100,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'rows': [_booking('b')],
          'nextOffset': null,
        }),
        200,
      );
    });

    final bookings = await _SignedInApiClient(client: client).bookings();

    expect(bookings.map((booking) => booking.id), ['a', 'b']);
    expect(offsets, ['0', '100']);
  });

  test('a booking page without rows is rejected', () async {
    final client = MockClient((_) async => http.Response('[]', 200));

    await expectLater(
      _SignedInApiClient(client: client).bookingsPage(),
      throwsA(isA<FormatException>()),
    );
  });

  test('a non-JSON response gives a generic message', () async {
    final client =
        MockClient((_) async => http.Response('<html>oops</html>', 200));

    await expectLater(
      _SignedInApiClient(client: client).bookingsPage(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'The server sent an unexpected response.',
        ),
      ),
    );
  });

  test('logout sends the refresh token in the body for a mobile client',
      () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    await _SignedInApiClient(client: client).logout('refresh-token-value');

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/api/auth/logout');
    expect(captured?.headers['X-Client-Platform'], 'mobile');
    expect(jsonDecode(captured!.body), {'refreshToken': 'refresh-token-value'});
  });

  test('MPIN enrollment sends the PIN only to the authenticated API', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    await _SignedInApiClient(client: client).saveMpin('1234');

    expect(captured?.method, 'PUT');
    expect(captured?.url.path, '/api/auth/mpin');
    expect(captured?.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(captured!.body), {'pin': '1234'});
  });

  test('MPIN removal uses the authenticated API', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    await _SignedInApiClient(client: client).deleteMpin();

    expect(captured?.method, 'DELETE');
    expect(captured?.url.path, '/api/auth/mpin');
    expect(captured?.headers['authorization'], 'Bearer access-token');
  });

  test('registered booking email fallback never accepts a client email',
      () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'emailChallengeId': 'email-challenge'}),
        202,
      );
    });

    final challengeId = await _SignedInApiClient(client: client)
        .requestRegisteredBookingEmailOtp(phone: '+91 98765 43210');

    expect(challengeId, 'email-challenge');
    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/api/auth/booking/email-fallback');
    expect(captured?.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(captured!.body), {'phone': '9876543210'});
  });

  test('phone verification reads the backend booking policy', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode(
            {'phone': '9876543210', 'verified': true, 'required': false}),
        200));

    final state = await _SignedInApiClient(client: client).phoneVerification();

    expect(state.phone, '9876543210');
    expect(state.verified, isTrue);
    expect(state.required, isFalse);
  });

  test('coupon validation returns the details used by the booking UI',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/customer/coupons/validate');
      return http.Response(
        jsonEncode({
          'valid': true,
          'coupon': {
            'id': 'coupon-1',
            'code': 'SAVE10',
            'title': 'Ten percent off',
            'discountType': 'percentage',
            'discountValue': 10,
          },
        }),
        200,
      );
    });

    final coupon = await _SignedInApiClient(client: client).validateCoupon(
      code: 'SAVE10',
      serviceCode: 'water_tanker',
      amount: 0,
    );

    expect(coupon['code'], 'SAVE10');
    expect(coupon['title'], 'Ten percent off');
  });

  test('idempotency keys are random RFC 4122 version 4 UUIDs', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final keys = List.generate(50, (_) => newIdempotencyKey());

    expect(keys.every(pattern.hasMatch), isTrue);
    expect(keys.toSet(), hasLength(50));
  });

  test('booking requests carry the idempotency key', () {
    final body = buildBookingRequestBody(
      serviceId: 'water_tanker',
      capacity: '5000',
      location: '12 Main Street',
      deliveryDate: '2026-10-25',
      services: const [],
      paymentMethod: 'cod',
      idempotencyKey: '6f1c2b1e-3d4a-4b5c-8d6e-7f8091a2b3c4',
    );

    expect(body['idempotencyKey'], '6f1c2b1e-3d4a-4b5c-8d6e-7f8091a2b3c4');
  });
}
