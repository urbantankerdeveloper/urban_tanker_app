import 'dart:math';

import '../../models/booking.dart';
import '../../models/booking_service_details.dart';
import '../../models/session.dart';

/// A random RFC 4122 version 4 UUID for idempotent booking submits.
String newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, dynamic> buildBookingRequestBody({
  required String serviceId,
  required String capacity,
  required String location,
  required String deliveryDate,
  required List<BookingServiceDetails> services,
  double? latitude,
  double? longitude,
  String? notes,
  required String paymentMethod,
  String? couponCode,
  String? phone,
  String? phoneVerificationChallengeId,
  String? idempotencyKey,
}) {
  final normalizedServices =
      services.map((service) => service.toJson()).toList(growable: false);
  return {
    'serviceId': serviceId,
    'capacity': capacity,
    'services': normalizedServices,
    'location': location,
    'deliveryDate': deliveryDate,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (phone != null && phone.trim().isNotEmpty)
      'phone': normalizeIndianPhone(phone),
    if (phoneVerificationChallengeId != null &&
        phoneVerificationChallengeId.trim().isNotEmpty)
      'phoneVerificationChallengeId': phoneVerificationChallengeId,
    if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    'paymentMethod': paymentMethod,
    if (couponCode != null && couponCode.trim().isNotEmpty)
      'couponCode': couponCode.trim().toUpperCase(),
  };
}

String normalizeIndianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  /// Used when the server sent no readable error message.
  static String genericFailureMessage(int statusCode) =>
      'Request failed ($statusCode).';

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Result of sign-up. Exactly one of [authResult] or [challengeId] is set:
/// [challengeId] means the account needs an email code before it can sign in.
typedef SignUpOutcome = ({
  AuthResult? authResult,
  String? challengeId,
  int resendAfterSeconds,
});

class PhoneVerificationState {
  const PhoneVerificationState({
    required this.phone,
    required this.verified,
    this.required = true,
  });

  final String phone;
  final bool verified;
  final bool required;
}

class BookingPage {
  const BookingPage({required this.rows, this.nextOffset});

  final List<Booking> rows;
  final int? nextOffset;
}
