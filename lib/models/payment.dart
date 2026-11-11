/// The Razorpay order the backend creates for an online-payment booking.
class RazorpayOrder {
  const RazorpayOrder({
    required this.id,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amount = json['amount'];
    final currency = json['currency'];
    final keyId = json['keyId'];
    if (id is! String ||
        amount is! num ||
        currency is! String ||
        keyId is! String) {
      throw const FormatException('The payment order response was invalid.');
    }
    return RazorpayOrder(
      id: id,
      amountPaise: amount.toInt(),
      currency: currency,
      keyId: keyId,
    );
  }

  final String id;
  final int amountPaise;
  final String currency;
  final String keyId;
}

/// Receipt-friendly payment details for a booking. Never carries provider
/// identifiers.
class PaymentReceipt {
  const PaymentReceipt({
    required this.status,
    required this.amountPaise,
    required this.currency,
    this.method,
    this.cardNetwork,
    this.cardLast4,
    this.bank,
    this.wallet,
    this.vpa,
    this.capturedAt,
    this.feePaise,
    this.taxPaise,
    this.refundedPaise = 0,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final amount = json['amountPaise'];
    final currency = json['currency'];
    if (status is! String || amount is! num || currency is! String) {
      throw const FormatException('The payment response was invalid.');
    }
    return PaymentReceipt(
      status: status,
      amountPaise: amount.toInt(),
      currency: currency,
      method: json['method'] as String?,
      cardNetwork: json['cardNetwork'] as String?,
      cardLast4: json['cardLast4'] as String?,
      bank: json['bank'] as String?,
      wallet: json['wallet'] as String?,
      vpa: json['vpa'] as String?,
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? ''),
      feePaise: (json['feePaise'] as num?)?.toInt(),
      taxPaise: (json['taxPaise'] as num?)?.toInt(),
      refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
    );
  }

  final String status;
  final int amountPaise;
  final String currency;
  final String? method;
  final String? cardNetwork;
  final String? cardLast4;
  final String? bank;
  final String? wallet;
  final String? vpa;
  final DateTime? capturedAt;
  final int? feePaise;
  final int? taxPaise;
  final int refundedPaise;

  bool get isPaid => status == 'paid';

  /// Human-readable payment method, such as "Visa •••• 4242" or "UPI (name@bank)".
  String get methodLabel {
    switch (method) {
      case 'card':
        final network = cardNetwork ?? 'Card';
        return cardLast4 == null ? network : '$network •••• $cardLast4';
      case 'upi':
        return vpa == null ? 'UPI' : 'UPI ($vpa)';
      case 'netbanking':
        return bank == null ? 'Net banking' : 'Net banking ($bank)';
      case 'wallet':
        return wallet == null ? 'Wallet' : 'Wallet ($wallet)';
      case null:
        return 'Online payment';
      default:
        return method!;
    }
  }
}
