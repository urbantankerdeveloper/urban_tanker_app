import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class CheckoutOptions {
  const CheckoutOptions({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.name,
    required this.description,
    this.contact,
    this.email,
  });

  final String keyId;
  final String orderId;
  final int amountPaise;
  final String currency;
  final String name;
  final String description;
  final String? contact;
  final String? email;
}

sealed class CheckoutResult {
  const CheckoutResult();
}

class CheckoutSuccess extends CheckoutResult {
  const CheckoutSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

class CheckoutFailure extends CheckoutResult {
  const CheckoutFailure({required this.cancelled, required this.message});

  final bool cancelled;
  final String message;
}

abstract class PaymentCheckout {
  Future<CheckoutResult> open(CheckoutOptions options);
}

/// Wraps the Razorpay Flutter SDK. Card, UPI and bank entry happen inside
/// Razorpay's own widget; this class only receives the order/payment ids and
/// signature back. Nothing from the SDK response is logged or persisted here.
class RazorpayPaymentCheckout implements PaymentCheckout {
  static const int _cancelledCode = 2;

  @override
  Future<CheckoutResult> open(CheckoutOptions options) {
    final razorpay = Razorpay();
    final completer = Completer<CheckoutResult>();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic response) {
      if (completer.isCompleted) return;
      final r = response as PaymentSuccessResponse;
      final orderId = r.orderId;
      final paymentId = r.paymentId;
      final signature = r.signature;
      if (orderId == null || paymentId == null || signature == null) {
        completer.complete(const CheckoutFailure(
          cancelled: false,
          message: 'Payment response was incomplete. Please try again.',
        ));
        return;
      }
      completer.complete(CheckoutSuccess(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      ));
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (dynamic response) {
      if (completer.isCompleted) return;
      final r = response as PaymentFailureResponse;
      completer.complete(CheckoutFailure(
        cancelled: r.code == _cancelledCode,
        message: r.message ?? 'Payment could not be completed.',
      ));
    });

    // External wallet events are ignored: Razorpay follows them with a
    // success or error event, which the handlers above cover.

    final prefill = <String, String>{
      if (options.contact != null) 'contact': options.contact!,
      if (options.email != null) 'email': options.email!,
    };

    try {
      razorpay.open({
        'key': options.keyId,
        'amount': options.amountPaise,
        'currency': options.currency,
        'name': options.name,
        'description': options.description,
        'order_id': options.orderId,
        if (prefill.isNotEmpty) 'prefill': prefill,
      });
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(const CheckoutFailure(
          cancelled: false,
          message: 'Could not open the payment screen. Please try again.',
        ));
      }
    }

    return completer.future.whenComplete(razorpay.clear);
  }
}
