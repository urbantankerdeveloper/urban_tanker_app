import '../../models/payment.dart';
import '../api_client.dart';
import 'payment_checkout.dart';

enum OnlinePaymentStatus { paid, cancelled, failed, verificationPending }

class OnlinePaymentOutcome {
  const OnlinePaymentOutcome(
    this.status, {
    this.message,
    this.pendingSuccess,
    this.bookingId,
  });

  final OnlinePaymentStatus status;
  final String? message;

  /// Set only when the checkout succeeded but server verification did not.
  /// Keep it in memory so the user can retry confirmation without paying again.
  final CheckoutSuccess? pendingSuccess;

  /// The booking created by a verified checkout, or the booking that was paid.
  final String? bookingId;
}

/// Drives one online payment for an existing booking: create the Razorpay
/// order, open checkout, then verify the signature with the backend.
class OnlinePaymentFlow {
OnlinePaymentFlow({required ApiClient api, required PaymentCheckout checkout})
    : _api = api,
      _checkout = checkout;

final ApiClient _api;
final PaymentCheckout _checkout;

  Future<OnlinePaymentOutcome> pay({
  required String bookingId,
    required String name,
    required String description,
    String? contact,
    String? email,
  }) async {
    final RazorpayOrder order;
    try {
    order = await _api.createRazorpayOrder(bookingId);
    } on ApiException catch (error) {
      return OnlinePaymentOutcome(
        OnlinePaymentStatus.failed,
        message: error.message,
      );
    }

    final result = await _checkout.open(CheckoutOptions(
      keyId: order.keyId,
      orderId: order.id,
      amountPaise: order.amountPaise,
      currency: order.currency,
      name: name,
      description: description,
      contact: contact,
      email: email,
    ));

    return switch (result) {
      CheckoutFailure(:final cancelled, :final message) =>
        OnlinePaymentOutcome(
          cancelled ? OnlinePaymentStatus.cancelled : OnlinePaymentStatus.failed,
          message: message,
        ),
      CheckoutSuccess() => confirm(result),
    };
  }

  Future<OnlinePaymentOutcome> confirm(CheckoutSuccess success) async {
    try {
      final bookingId = await _api.verifyRazorpayPayment(
        orderId: success.orderId,
        paymentId: success.paymentId,
        signature: success.signature,
      );
      return OnlinePaymentOutcome(OnlinePaymentStatus.paid, bookingId: bookingId);
    } on Object {
      return OnlinePaymentOutcome(
        OnlinePaymentStatus.verificationPending,
        message:
            'Payment received, but we could not confirm it yet. Retry confirmation or check the payment status later.',
        pendingSuccess: success,
      );
    }
  }

  /// Pays for a cash-on-delivery booking online. The booking is switched to
  /// online first so the vendor and driver stop expecting cash. If checkout is
  /// cancelled or fails, the booking goes back to cash on delivery.
  Future<OnlinePaymentOutcome> payAfterCodSwitch({
    required String bookingId,
    required String name,
    required String description,
    String? contact,
    String? email,
  }) async {
    try {
      await _api.switchBookingToOnline(bookingId);
    } on ApiException catch (error) {
      return OnlinePaymentOutcome(
        OnlinePaymentStatus.failed,
        message: error.message,
      );
    }

    final outcome = await pay(
      bookingId: bookingId,
      name: name,
      description: description,
      contact: contact,
      email: email,
    );
    if (outcome.status == OnlinePaymentStatus.paid ||
        outcome.status == OnlinePaymentStatus.verificationPending) {
      return outcome;
    }

    try {
      await _api.switchBookingToCashOnDelivery(bookingId);
      return outcome;
    } on Object {
      return OnlinePaymentOutcome(
        outcome.status,
        message:
            'Payment was not completed, and we could not restore cash on delivery. Contact support before the driver arrives.',
      );
    }
  }

  Future<PaymentReceipt?> receipt(String bookingId) =>
      _api.getPaymentDetails(bookingId);
}
