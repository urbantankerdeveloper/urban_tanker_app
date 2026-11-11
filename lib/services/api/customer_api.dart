import 'package:http/http.dart' as http;

import '../../models/account.dart';
import '../../models/booking.dart';
import '../../models/booking_service_details.dart';
import '../../models/service.dart';
import 'api_decode.dart';
import 'api_transport.dart';
import 'api_types.dart';

/// Customer booking, tracking, profile, addresses, billing and membership.
class CustomerApi {
  CustomerApi(this._api);

  final ApiTransport _api;

  Future<List<TankerService>> services() async {
    final response = await _api.request('GET', '/customer/services');
    final decoded = await decodeBodyAsync(response);
    if (decoded is! List) {
      throw const FormatException('The services response was invalid.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((service) => service['is_active'] != false)
        .map(TankerService.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> createBooking({
    required String serviceId,
    required String capacity,
    required String location,
    required String deliveryDate,
    List<BookingServiceDetails>? services,
    String? notes,
    String paymentMethod = 'cod',
    String? couponCode,
    String? phone,
    String? phoneVerificationChallengeId,
    double? latitude,
    double? longitude,
    String? idempotencyKey,
  }) async {
    final response = await _api.request(
      'POST',
      '/customer/orders/quote',
      body: buildBookingRequestBody(
        serviceId: serviceId,
        capacity: capacity,
        location: location,
        deliveryDate: deliveryDate,
        services: services ??
            [
              BookingServiceDetails(
                serviceId: serviceId,
                quantity: capacity,
                details: notes ?? '',
              ),
            ],
        notes: notes,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        phone: phone,
        phoneVerificationChallengeId: phoneVerificationChallengeId,
        latitude: latitude,
        longitude: longitude,
        idempotencyKey: idempotencyKey,
      ),
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The booking response was invalid.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> previewBookingQuote({
    required String serviceId,
    required String capacity,
    required String location,
    required String deliveryDate,
    List<BookingServiceDetails>? services,
    String? notes,
    String paymentMethod = 'cod',
    String? couponCode,
    String? phone,
    String? phoneVerificationChallengeId,
    double? latitude,
    double? longitude,
  }) async {
    final response =
        await _api.request('POST', '/customer/orders/quote-preview', body: {
      ...buildBookingRequestBody(
        serviceId: serviceId,
        capacity: capacity,
        location: location,
        deliveryDate: deliveryDate,
        services: services ??
            [
              BookingServiceDetails(
                serviceId: serviceId,
                quantity: capacity,
                details: notes ?? '',
              ),
            ],
        notes: notes,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        phone: phone,
        phoneVerificationChallengeId: phoneVerificationChallengeId,
        latitude: latitude,
        longitude: longitude,
      ),
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The booking quote response was invalid.');
    }
    return decoded;
  }

  /// Loads every booking by following `nextOffset` from the server.
  Future<List<Booking>> bookings() async {
    final all = <Booking>[];
    var offset = 0;
    for (var pages = 0; pages < 50; pages++) {
      final page = await bookingsPage(offset: offset);
      all.addAll(page.rows);
      final next = page.nextOffset;
      if (next == null || next <= offset) break;
      offset = next;
    }
    return all;
  }

  Future<BookingPage> bookingsPage({int offset = 0, int pageSize = 100}) async {
    final response = await _api.request(
      'GET',
      '/customer/orders?offset=$offset&pageSize=${pageSize.clamp(1, 100)}',
    );
    final decoded = await decodeBodyAsync(response);
    if (decoded is! Map<String, dynamic> || decoded['rows'] is! List) {
      throw const FormatException('The bookings response was invalid.');
    }
    final next = decoded['nextOffset'];
    return BookingPage(
      rows: (decoded['rows'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList(),
      nextOffset: next is num ? next.toInt() : null,
    );
  }

  Future<TrackingSnapshot> bookingTracking(String bookingId) async {
    final response = await _api.request(
      'GET',
      '/customer/orders/$bookingId/tracking',
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The tracking response was invalid.');
    }
    return TrackingSnapshot.fromJson(decoded);
  }

  Future<PublicTrackingSnapshot> publicTracking(String token) async {
    final response = await _api.request(
        'GET', '/public/tracking/${Uri.encodeComponent(token)}',
        retry: false);
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The public tracking response was invalid.');
    }
    return PublicTrackingSnapshot.fromJson(decoded);
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final response = await _api.request(
      'PATCH',
      '/customer/orders/$bookingId/status',
      body: {'status': 'cancelled'},
    );
    return _bookingFromResponse(response, 'cancelled booking');
  }

  Future<Booking> rescheduleBooking(
    String bookingId,
    DateTime scheduledFor,
  ) async {
    final response = await _api.request(
      'PATCH',
      '/customer/orders/$bookingId/reschedule',
      body: {'scheduledFor': scheduledFor.toUtc().toIso8601String()},
    );
    return _bookingFromResponse(response, 'rescheduled booking');
  }

  Future<DateTime> requestDeliveryOtp(String bookingId) async {
    final response = await _api.request(
      'POST',
      '/customer/orders/$bookingId/delivery-otp',
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['expiresAt'] is! String) {
      throw const FormatException('The delivery OTP response was invalid.');
    }
    final expiresAt = DateTime.tryParse(decoded['expiresAt'] as String);
    if (expiresAt == null) {
      throw const FormatException('The delivery OTP expiry was invalid.');
    }
    return expiresAt;
  }

  Future<void> rateBooking(
    String bookingId, {
    required int rating,
    String? review,
  }) async {
    await _api.request(
      'POST',
      '/customer/orders/$bookingId/rating',
      body: {'rating': rating, 'review': review},
    );
  }

  Booking _bookingFromResponse(http.Response response, String label) {
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('The $label response was invalid.');
    }
    return Booking.fromJson(decoded);
  }

  Future<CustomerProfile> profile() async {
    final response = await _api.request('GET', '/customer/profile');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The profile response was invalid.');
    }
    return CustomerProfile.fromJson(decoded);
  }

  Future<CustomerProfile> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    final response = await _api.request(
      'PATCH',
      '/customer/profile',
      body: {
        'name': name,
        'email': email,
        if (phone != null && phone.trim().isNotEmpty)
          'phone': normalizeIndianPhone(phone),
      },
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The updated profile response was invalid.');
    }
    return CustomerProfile.fromJson(decoded);
  }

  Future<List<AccountRecord>> addresses() =>
      _records('/customer/addresses', 'addresses');

  Future<List<AccountRecord>> wallet() =>
      _records('/customer/wallet', 'wallet');

  Future<List<AccountRecord>> invoices() =>
      _records('/customer/invoices', 'invoices');

  Future<List<AccountRecord>> subscriptions() =>
      _records('/customer/subscriptions', 'subscriptions');

  Future<List<AccountRecord>> supportRequests() =>
      _records('/support/requests', 'support requests');

  Future<List<AccountRecord>> offers() =>
      _records('/customer/offers', 'offers');

  Future<List<AccountRecord>> membershipPlans() =>
      _records('/customer/membership-plans', 'membership plans');

  Future<List<AccountRecord>> contracts() =>
      _records('/customer/contracts', 'contracts');

  Future<List<AccountRecord>> _records(String path, String label) =>
      recordList(_api, path, label);

  Future<AccountRecord> createAddress({
    required String label,
    required String address,
    required String city,
    required String pincode,
    bool isDefault = false,
  }) async {
    final response = await _api.request('POST', '/customer/addresses', body: {
      'label': label,
      'address': address,
      'city': city,
      'pincode': pincode,
      'isDefault': isDefault,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The address response was invalid.');
    }

    return AccountRecord(decoded);
  }

  Future<AccountRecord> updateAddress(
    String id, {
    String? label,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
  }) async {
    final response =
        await _api.request('PATCH', '/customer/addresses/$id', body: {
      if (label != null) 'label': label,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
      if (isDefault != null) 'isDefault': isDefault,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The address update response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<void> deleteAddress(String id) async {
    await _api.request('DELETE', '/customer/addresses/$id');
  }

  Future<AccountRecord> createSupportRequest({
    required String subject,
    required String message,
  }) async {
    final response = await _api.request('POST', '/support/requests', body: {
      'subject': subject,
      'message': message,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The support response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> supportRequest(String id) async {
    final response = await _api.request('GET', '/support/requests/$id');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The support request response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> updateSubscription(
    String id,
    String status,
  ) async {
    final response = await _api.request(
      'PATCH',
      '/customer/subscriptions/$id/status',
      body: {'status': status},
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The subscription response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> invoice(String id) async {
    final response =
        await _api.request('GET', '/customer/invoices/$id/download');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The invoice response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> createContract({
    required String propertyType,
    required String address,
    required double estimate,
  }) async {
    final response = await _api.request('POST', '/customer/contracts', body: {
      'propertyType': propertyType,
      'servicePlan': <String, dynamic>{},
      'address': address,
      'estimate': estimate,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The contract response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<CustomerUsage> usage() async {
    final response = await _api.request('GET', '/customer/usage');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The usage response was invalid.');
    }
    return CustomerUsage.fromJson(decoded);
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String serviceCode,
    required double amount,
  }) async {
    final response =
        await _api.request('POST', '/customer/coupons/validate', body: {
      'code': code,
      'serviceCode': serviceCode,
      'amount': amount,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The coupon response was invalid.');
    }
    final coupon = decoded['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw const FormatException('The coupon details were invalid.');
    }
    return coupon;
  }

  Future<AccountRecord?> membership() async {
    final response = await _api.request('GET', '/customer/membership');
    final decoded = decodeBody(response);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> updateMembership(String status) async {
    final response = await _api.request(
      'PATCH',
      '/customer/membership',
      body: {'status': status},
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership update was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> requestMembership(String planId) async {
    final response = await _api.request(
      'POST',
      '/customer/membership',
      body: {'planId': planId},
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership request was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<void> uploadCustomerSelfie({required List<int> bytes}) async {
    if (bytes.isEmpty) {
      throw const FormatException(
          'The selfie could not be read. Please retake it.');
    }
    if (bytes.length > 3 * 1024 * 1024) {
      throw const FormatException(
          'The photo is larger than 3 MB. Choose a smaller photo.');
    }
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    if (!isJpeg) {
      throw const FormatException('Choose a JPEG photo.');
    }
    await _api.request(
      'POST',
      '/customer/profile/selfie',
      bodyBytes: bytes,
      contentType: 'image/jpeg',
    );
  }
}
