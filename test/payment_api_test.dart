import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _SignedInApiClient extends ApiClient {
  _SignedInApiClient({required http.Client client})
      : super(client: client, baseUrl: 'https://example.test/api');

  @override
  Future<String?> readAccessToken() async => 'access-token';
}

void main() {
  test('createRazorpayOrder posts the booking and parses the order', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/payment/razorpay/order');
      expect(jsonDecode(request.body), {'bookingId': 'b1'});
      return http.Response(
        jsonEncode({
          'id': 'order_1',
          'amount': 50000,
          'currency': 'INR',
          'keyId': 'rzp_test_public',
        }),
        201,
      );
    });

    final order =
        await _SignedInApiClient(client: client).createRazorpayOrder('b1');

    expect(order.id, 'order_1');
    expect(order.amountPaise, 50000);
    expect(order.keyId, 'rzp_test_public');
  });

  test('verifyRazorpayPayment treats an already-processed 409 as success',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/payment/razorpay/verify');
      return http.Response(
        jsonEncode({'error': 'This payment has already been processed.'}),
        409,
      );
    });

    await _SignedInApiClient(client: client).verifyRazorpayPayment(
      orderId: 'order_1',
      paymentId: 'pay_1',
      signature: 'sig',
    );
  });

  test('verifyRazorpayPayment surfaces an amount mismatch as an error',
      () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'error':
                'Payment amount does not match this booking. Contact support.',
          }),
          409,
        ));

    await expectLater(
      _SignedInApiClient(client: client).verifyRazorpayPayment(
        orderId: 'order_1',
        paymentId: 'pay_1',
        signature: 'sig',
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('getPaymentDetails returns null when no payment exists yet', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/customer/payments/b1');
      return http.Response(jsonEncode({'error': 'Not found'}), 404);
    });

    final receipt =
        await _SignedInApiClient(client: client).getPaymentDetails('b1');

    expect(receipt, isNull);
  });

  test('getPaymentDetails parses the receipt shape', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'status': 'paid',
            'amountPaise': 50000,
            'currency': 'INR',
            'method': 'card',
            'cardNetwork': 'Visa',
            'cardLast4': '4242',
            'capturedAt': '2026-10-21T09:05:00.000Z',
            'refundedPaise': 0,
          }),
          200,
        ));

    final receipt =
        await _SignedInApiClient(client: client).getPaymentDetails('b1');

    expect(receipt!.isPaid, isTrue);
    expect(receipt.amountPaise, 50000);
    expect(receipt.methodLabel, contains('4242'));
  });

  test('switchBookingToCashOnDelivery posts the cod method', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/customer/orders/b1/payment-method');
      expect(jsonDecode(request.body), {'paymentMethod': 'cod'});
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await _SignedInApiClient(client: client).switchBookingToCashOnDelivery('b1');
  });

  test('switchBookingToOnline posts to the online switch route', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/customer/orders/b1/payment-method/online');
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await _SignedInApiClient(client: client).switchBookingToOnline('b1');
  });
}
