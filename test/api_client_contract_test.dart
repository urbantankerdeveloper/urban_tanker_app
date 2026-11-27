import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api_client.dart';

/// Skips secure storage so the tests run without platform channels.
class _SignedInApiClient extends ApiClient {
  _SignedInApiClient({required http.Client client})
      : super(client: client, baseUrl: 'https://example.test/api');

  String? savedAccessToken;
  String? savedRefreshToken;

  @override
  Future<String?> readAccessToken() async => 'access-token';

  @override
  Future<void> saveAccessToken(String token) async {
    savedAccessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    savedRefreshToken = token;
  }
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
  test('booking tracking link uses the customer endpoint and returns its URL',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(
            {'trackingUrl': 'https://urban-tanker.test/track/${'a' * 43}'}),
        200,
      );
    });

    final trackingUrl = await _SignedInApiClient(client: client)
        .bookingTrackingLink('booking-1');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/customer/orders/booking-1/tracking-link');
    expect(
        trackingUrl.toString(), 'https://urban-tanker.test/track/${'a' * 43}');
  });

  test('phone OTP sign-in accepts the existing-account response', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'accessToken': 'phone-access-token',
          'refreshToken': 'phone-refresh-token',
          'user': {
            'id': 'existing-customer',
            'email': 'customer@example.com',
            'username': 'customer-one',
            'name': 'Existing Customer',
            'role': 'customer',
            'phone': '9876543210',
            'phoneVerified': true,
            'themeMode': 'dark',
            'selfieRequired': false,
          },
        }),
        200,
      );
    });
    final api = _SignedInApiClient(client: client);

    final result = await api.verifyPhoneAuthOtp(
      phone: '9876543210',
      challengeId: 'challenge-id',
      otp: '123456',
    );

    expect(captured.url.path, '/api/auth/phone/verify-otp');
    expect(jsonDecode(captured.body), {
      'phone': '9876543210',
      'challengeId': 'challenge-id',
      'otp': '123456',
    });
    expect(result.user.id, 'existing-customer');
    expect(result.user.username, 'customer-one');
    expect(result.user.phoneVerified, isTrue);
    expect(api.savedAccessToken, 'phone-access-token');
    expect(api.savedRefreshToken, 'phone-refresh-token');
  });

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

  test('admin enquiries reads the authenticated paginated endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/admin/enquiries');
      expect(request.url.queryParameters, {'page': '2', 'pageSize': '25'});
      expect(request.headers['authorization'], 'Bearer access-token');
      return http.Response(
        jsonEncode({
          'rows': [
            {
              'id': 'enquiry-1',
              'subject': 'Borewell service',
              'message': 'Proposed depth: 120 ft',
              'status': 'new',
            },
          ],
          'page': 2,
          'pageSize': 25,
          'total': 55,
        }),
        200,
      );
    });

    final page = await _SignedInApiClient(client: client).adminEnquiries(
      page: 2,
      pageSize: 25,
    );

    expect(page.rows.single.title, 'Borewell service');
    expect(page.rows.single.detail, 'Proposed depth: 120 ft');
    expect(page.page, 2);
    expect(page.pageSize, 25);
    expect(page.total, 55);
    expect(page.hasNextPage, isTrue);
  });

  test('admin enquiry status changes use the authenticated admin endpoint',
      () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'enquiry-1',
          'subject': 'Borewell service',
          'message': 'Proposed depth: 120 ft',
          'status': 'in_progress',
          'response': 'Reviewing the site requirements.',
        }),
        200,
      );
    });

    final updated = await _SignedInApiClient(client: client).updateAdminEnquiry(
      'enquiry-1',
      status: 'in_progress',
      responseNote: 'Reviewing the site requirements.',
    );

    expect(captured?.method, 'PATCH');
    expect(captured?.url.path, '/api/admin/enquiries/enquiry-1');
    expect(captured?.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(captured!.body), {
      'status': 'in_progress',
      'response': 'Reviewing the site requirements.',
    });
    expect(updated.status, 'in_progress');
  });

  test('admin enquiry history uses the authenticated history endpoint',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/admin/enquiries/enquiry-1/history');
      expect(request.headers['authorization'], 'Bearer access-token');
      return http.Response(
        jsonEncode([
          {
            'id': 'history-1',
            'enquiry_id': 'enquiry-1',
            'action': 'submitted',
            'actor_type': 'public',
            'new_status': 'new',
            'created_at': '2026-11-18T03:00:00.000Z',
          },
        ]),
        200,
      );
    });

    final history = await _SignedInApiClient(client: client)
        .adminEnquiryHistory('enquiry-1');

    expect(history.single.data['action'], 'submitted');
    expect(history.single.data['new_status'], 'new');
  });

  test('partner review supports requesting additional information', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'partner-1',
          'status': 'additional_info_required',
          'review_note': 'Upload vehicle insurance.',
        }),
        200,
      );
    });

    final updated =
        await _SignedInApiClient(client: client).reviewPartnerApplication(
      'partner-1',
      status: 'additional_info_required',
      reviewNote: 'Upload vehicle insurance.',
    );

    expect(captured?.method, 'PATCH');
    expect(captured?.url.path, '/api/admin/partner-applications/partner-1');
    expect(captured?.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(captured!.body), {
      'status': 'additional_info_required',
      'reviewNote': 'Upload vehicle insurance.',
    });
    expect(updated.status, 'additional_info_required');
  });

  test('partner application history uses the authenticated admin endpoint',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/admin/partner-applications/partner-1/history',
      );
      expect(request.headers['authorization'], 'Bearer access-token');
      return http.Response(
        jsonEncode([
          {
            'id': 'history-1',
            'action': 'reviewed',
            'old_status': 'submitted',
            'new_status': 'additional_info_required',
            'review_note': 'Upload vehicle insurance.',
          },
        ]),
        200,
      );
    });

    final history = await _SignedInApiClient(client: client)
        .partnerApplicationHistory('partner-1');

    expect(history.single.data['new_status'], 'additional_info_required');
    expect(history.single.data['review_note'], 'Upload vehicle insurance.');
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

  test('admin-access review uses the shared pending and decision endpoints',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 'request-1',
              'name': 'Jordan Smith',
              'email': 'jordan@example.com',
              'phone_e164': '+919876543210',
              'reason': 'Manage regional operations.',
              'status': 'pending',
              'requested_at': '2026-02-01T10:00:00.000Z',
            },
          ]),
          200,
        );
      }
      return http.Response(
          jsonEncode({'id': 'request-1', 'status': 'approved'}), 200);
    });
    final api = _SignedInApiClient(client: client);

    final rows = await api.adminUsers();
    await api.reviewAdminAccessRequest('request-1', decision: 'approved');
    await api.reviewAdminAccessRequest('request-2', decision: 'rejected');
    await api.setAdminUserActive('admin-1', isActive: false);

    expect(rows.single['email'], 'jordan@example.com');
    expect(requests.map((request) => request.url.path), [
      '/api/admin-access/admins',
      '/api/admin-access/requests/request-1',
      '/api/admin-access/requests/request-2',
      '/api/admin-access/admins/admin-1/status',
    ]);
    expect(requests.map((request) => request.method),
        ['GET', 'PATCH', 'PATCH', 'PATCH']);
    expect(jsonDecode(requests[1].body), {'decision': 'approved'});
    expect(jsonDecode(requests[2].body), {'decision': 'rejected'});
    expect(jsonDecode(requests[3].body), {'isActive': false});
    expect(
      requests.every((request) =>
          request.headers['authorization'] == 'Bearer access-token'),
      isTrue,
    );
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
