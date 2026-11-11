import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/models/payment.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/payment/online_payment_flow.dart';
import 'package:urban_tanker_app/services/payment/payment_checkout.dart';

class _FakeCheckout implements PaymentCheckout {
  _FakeCheckout(this.results);

  final List<CheckoutResult> results;
  final List<CheckoutOptions> opened = [];

  @override
  Future<CheckoutResult> open(CheckoutOptions options) async {
    opened.add(options);
    return results.removeAt(0);
  }
}

class _FakeApi extends ApiClient {
  _FakeApi({this.verifyError})
      : super(
          client: MockClient((_) async => http.Response('{}', 500)),
          baseUrl: 'https://example.test/api',
        );

  final Object? verifyError;
  final List<String> verified = [];
  bool orderFails = false;
  bool switchToOnlineFails = false;
  bool revertFails = false;
  final List<String> switches = [];

  @override
  Future<void> switchBookingToOnline(String bookingId) async {
    if (switchToOnlineFails) {
      throw ApiException('Booking has moved on', 409);
    }
    switches.add('online');
  }

  @override
  Future<void> switchBookingToCashOnDelivery(String bookingId) async {
    if (revertFails) throw ApiException('Server unavailable', 500);
    switches.add('cod');
  }

  @override
  Future<RazorpayOrder> createRazorpayOrder(String bookingId) async {
    if (orderFails) {
      throw ApiException('Booking not found', 404);
    }
    return RazorpayOrder(
      id: 'order_1',
      amountPaise: 50000,
      currency: 'INR',
      keyId: 'rzp_test_public',
    );
  }

  @override
  Future<String?> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    verified.add(paymentId);
    if (verifyError != null) throw verifyError!;
    return 'b1';
  }

  @override
  Future<PaymentReceipt?> getPaymentDetails(String bookingId) async => null;
}

const _success = CheckoutSuccess(
  orderId: 'order_1',
  paymentId: 'pay_1',
  signature: 'sig',
);

void main() {
  test('a successful checkout is verified and reported as paid', () async {
    final api = _FakeApi();
    final checkout = _FakeCheckout([_success]);
    final outcome = await OnlinePaymentFlow(api: api, checkout: checkout).pay(
      bookingId: 'b1',
      name: 'Urban Tanker',
      description: 'Booking UT-1',
    );

    expect(outcome.status, OnlinePaymentStatus.paid);
    expect(api.verified, ['pay_1']);
    expect(checkout.opened.single.orderId, 'order_1');
    expect(checkout.opened.single.amountPaise, 50000);
  });

  test('a cancelled checkout does not call verify', () async {
    final api = _FakeApi();
    final outcome = await OnlinePaymentFlow(
      api: api,
      checkout: _FakeCheckout([
        const CheckoutFailure(cancelled: true, message: 'Cancelled'),
      ]),
    ).pay(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.cancelled);
    expect(api.verified, isEmpty);
  });

  test('a failed checkout is reported as failed, not cancelled', () async {
    final outcome = await OnlinePaymentFlow(
      api: _FakeApi(),
      checkout: _FakeCheckout([
        const CheckoutFailure(cancelled: false, message: 'Card declined'),
      ]),
    ).pay(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.failed);
    expect(outcome.message, 'Card declined');
  });

  test('a verify failure keeps the payment ids so the user can retry',
      () async {
    final api = _FakeApi(verifyError: Exception('network down'));
    final flow = OnlinePaymentFlow(
      api: api,
      checkout: _FakeCheckout([_success]),
    );

    final outcome = await flow.pay(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.verificationPending);
    expect(outcome.pendingSuccess?.paymentId, 'pay_1');

    final retried = await flow.confirm(outcome.pendingSuccess!);
    expect(retried.status, OnlinePaymentStatus.verificationPending);
  });

  test('an order creation error fails before checkout opens', () async {
    final api = _FakeApi()..orderFails = true;
    final checkout = _FakeCheckout([]);
    final outcome = await OnlinePaymentFlow(api: api, checkout: checkout)
        .pay(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.failed);
    expect(outcome.message, 'Booking not found');
    expect(checkout.opened, isEmpty);
  });

  test('paying after a COD switch marks the booking online and pays', () async {
    final api = _FakeApi();
    final outcome = await OnlinePaymentFlow(
      api: api,
      checkout: _FakeCheckout([_success]),
    ).payAfterCodSwitch(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.paid);
    expect(api.switches, ['online']);
  });

  test('a cancelled post-switch payment restores cash on delivery', () async {
    final api = _FakeApi();
    final outcome = await OnlinePaymentFlow(
      api: api,
      checkout: _FakeCheckout([
        const CheckoutFailure(cancelled: true, message: 'Cancelled'),
      ]),
    ).payAfterCodSwitch(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.cancelled);
    expect(api.switches, ['online', 'cod']);
  });

  test('a rejected switch never opens checkout', () async {
    final api = _FakeApi()..switchToOnlineFails = true;
    final checkout = _FakeCheckout([]);
    final outcome = await OnlinePaymentFlow(api: api, checkout: checkout)
        .payAfterCodSwitch(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.failed);
    expect(outcome.message, 'Booking has moved on');
    expect(checkout.opened, isEmpty);
    expect(api.switches, isEmpty);
  });

  test('a failed revert tells the user to contact support', () async {
    final api = _FakeApi()..revertFails = true;
    final outcome = await OnlinePaymentFlow(
      api: api,
      checkout: _FakeCheckout([
        const CheckoutFailure(cancelled: false, message: 'Card declined'),
      ]),
    ).payAfterCodSwitch(bookingId: 'b1', name: 'n', description: 'd');

    expect(outcome.status, OnlinePaymentStatus.failed);
    expect(outcome.message, contains('Contact support'));
  });
}
