import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/notification.dart';
import '../models/booking.dart';
import '../models/account.dart';
import '../models/dispatcher.dart';
import '../models/service.dart';
import '../models/session.dart';
import '../models/vendor.dart';
import '../models/booking_service_details.dart';

Map<String, dynamic> buildBookingRequestBody({
  required String serviceId,
  required String capacity,
  required String location,
  required String deliveryDate,
  required List<BookingServiceDetails> services,
  String? notes,
  String paymentMethod = 'cod',
  String? couponCode,
}) {
  final normalizedServices =
      services.map((service) => service.toJson()).toList(growable: false);
  return {
    'serviceId': serviceId,
    'capacity': capacity,
    'services': normalizedServices,
    'location': location,
    'deliveryDate': deliveryDate,
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

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class PhoneVerificationState {
  const PhoneVerificationState({required this.phone, required this.verified});

  final String phone;
  final bool verified;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'https://urban-tanker-backend.onrender.com/api',
                ))
            .replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;
  Future<String?>? _refreshOperation;

  Future<void> saveAccessToken(String token) => _storage.write(
        key: 'urban_tanker_access_token',
        value: token,
      );

  Future<void> saveRefreshToken(String token) => _storage.write(
        key: 'urban_tanker_refresh_token',
        value: token,
      );

  Future<void> clearTokens() async {
    await _storage.delete(key: 'urban_tanker_access_token');
    await _storage.delete(key: 'urban_tanker_refresh_token');
  }

  Future<String?> readAccessToken() =>
      _storage.read(key: 'urban_tanker_access_token');

  Future<String?> readRefreshToken() =>
      _storage.read(key: 'urban_tanker_refresh_token');

  Future<AuthResult> login(String credential, String password) async {
    final body = credential.contains('@')
        ? {'email': credential, 'password': password}
        : {'username': credential, 'password': password};
    return _authRequest('/auth/login', body);
  }

  Future<AuthResult?> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final response = await request('POST', '/auth/signup', body: {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': 'customer',
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The registration response was invalid.');
    }
    if (decoded['requiresEmailVerification'] == true) {
      if (decoded['emailSent'] != true) {
        throw const FormatException(
          'The server did not confirm that the verification email was sent.',
        );
      }
      return null;
    }
    return _saveAuthResult(decoded);
  }

  Future<void> requestPasswordReset(String email) async {
    final response = await request(
      'POST',
      '/auth/password-reset',
      body: {'email': email.trim()},
      retry: false,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['accepted'] != true) {
      throw const FormatException(
        'The password reset response was invalid.',
      );
    }
  }

  Future<PhoneVerificationState> phoneVerification() async {
    final response = await request('GET', '/customer/phone-verification');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'The phone verification response was invalid.');
    }
    return PhoneVerificationState(
      phone: normalizeIndianPhone((decoded['phone'] ?? '').toString()),
      verified: decoded['verified'] == true,
    );
  }

  Future<String> requestPhoneOtp(String phone) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    final response = await request(
      'POST',
      '/auth/guest/request-otp',
      body: {'phone': normalized},
      retry: false,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['challengeId'] is! String) {
      throw const FormatException('The phone OTP response was invalid.');
    }
    return decoded['challengeId'] as String;
  }

  Future<void> verifyPhoneOtp({
    required String challengeId,
    required String phone,
    required String otp,
  }) async {
    final response = await request(
      'POST',
      '/auth/guest/verify-phone',
      body: {
        'challengeId': challengeId,
        'phone': normalizeIndianPhone(phone),
        'otp': otp.trim(),
      },
      retry: false,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['verified'] != true) {
      throw const FormatException('Phone verification was not confirmed.');
    }
  }

  Future<List<TankerService>> services() async {
    final response = await request('GET', '/customer/services');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The services response was invalid.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
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
  }) async {
    final response = await request(
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
      ),
    );
    final decoded = jsonDecode(response.body);
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
  }) async {
    final response =
        await request('POST', '/customer/orders/quote-preview', body: {
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
      ),
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The booking quote response was invalid.');
    }
    return decoded;
  }

  Future<List<Booking>> bookings() async {
    final response = await request('GET', '/customer/orders');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The bookings response was invalid.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();
  }

  Future<TrackingSnapshot> bookingTracking(String bookingId) async {
    final response = await request(
      'GET',
      '/customer/orders/$bookingId/tracking',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The tracking response was invalid.');
    }
    return TrackingSnapshot.fromJson(decoded);
  }

  Future<PublicTrackingSnapshot> publicTracking(String token) async {
    final response = await request(
        'GET', '/public/tracking/${Uri.encodeComponent(token)}',
        retry: false);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The public tracking response was invalid.');
    }
    return PublicTrackingSnapshot.fromJson(decoded);
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final response = await request(
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
    final response = await request(
      'PATCH',
      '/customer/orders/$bookingId/reschedule',
      body: {'scheduledFor': scheduledFor.toUtc().toIso8601String()},
    );
    return _bookingFromResponse(response, 'rescheduled booking');
  }

  Future<DateTime> requestDeliveryOtp(String bookingId) async {
    final response = await request(
      'POST',
      '/customer/orders/$bookingId/delivery-otp',
    );
    final decoded = jsonDecode(response.body);
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
    await request(
      'POST',
      '/customer/orders/$bookingId/rating',
      body: {'rating': rating, 'review': review},
    );
  }

  Booking _bookingFromResponse(http.Response response, String label) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('The $label response was invalid.');
    }
    return Booking.fromJson(decoded);
  }

  Future<CustomerProfile> profile() async {
    final response = await request('GET', '/customer/profile');
    final decoded = jsonDecode(response.body);
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
    final response = await request(
      'PATCH',
      '/customer/profile',
      body: {
        'name': name,
        'email': email,
        if (phone != null && phone.trim().isNotEmpty)
          'phone': normalizeIndianPhone(phone),
      },
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The updated profile response was invalid.');
    }
    return CustomerProfile.fromJson(decoded);
  }

  Future<List<AccountRecord>> addresses() =>
      _records('/customer/addresses', 'addresses');

  Future<List<AccountRecord>> adminVendors() =>
      _records('/admin/vendors', 'admin vendors');

  Future<List<AccountRecord>> adminCustomers() =>
      _records('/admin/customers', 'admin customers');

  Future<List<AccountRecord>> adminCoupons() =>
      _records('/admin/coupons', 'admin coupons');

  Future<Map<String, dynamic>> adminHealth() async {
    final response = await request('GET', '/admin/system/health');
    return _mapResponse(response, 'admin health');
  }

  Future<void> updateVendorVerification(String id, String status) async {
    await request(
      'PATCH',
      '/admin/vendors/$id/status',
      body: {'status': status},
    );
  }

  Future<List<AccountRecord>> wallet() =>
      _records('/customer/wallet', 'wallet');

  Future<List<AccountRecord>> invoices() =>
      _records('/customer/invoices', 'invoices');

  Future<List<AccountRecord>> subscriptions() =>
      _records('/customer/subscriptions', 'subscriptions');

  Future<List<AccountRecord>> supportRequests() =>
      _records('/support/requests', 'support requests');

  Future<CustomerUsage> usage() async {
    final response = await request('GET', '/customer/usage');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The usage response was invalid.');
    }
    return CustomerUsage.fromJson(decoded);
  }

  Future<List<AccountRecord>> offers() =>
      _records('/customer/offers', 'offers');

  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String serviceCode,
    required double amount,
  }) async {
    final response = await request('POST', '/customer/coupons/validate', body: {
      'code': code,
      'serviceCode': serviceCode,
      'amount': amount,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The coupon response was invalid.');
    }
    final coupon = decoded['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw const FormatException('The coupon details were invalid.');
    }
    return coupon;
  }

  Future<List<AccountRecord>> membershipPlans() =>
      _records('/customer/membership-plans', 'membership plans');

  Future<AccountRecord?> membership() async {
    final response = await request('GET', '/customer/membership');
    final decoded = jsonDecode(response.body);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> updateMembership(String status) async {
    final response = await request(
      'PATCH',
      '/customer/membership',
      body: {'status': status},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership update was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> requestMembership(String planId) async {
    final response = await request(
      'POST',
      '/customer/membership',
      body: {'planId': planId},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The membership request was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<List<AccountRecord>> contracts() =>
      _records('/customer/contracts', 'contracts');

  Future<AccountRecord> createContract({
    required String propertyType,
    required String address,
    required double estimate,
  }) async {
    final response = await request('POST', '/customer/contracts', body: {
      'propertyType': propertyType,
      'servicePlan': <String, dynamic>{},
      'address': address,
      'estimate': estimate,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The contract response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> createAddress({
    required String label,
    required String address,
    required String city,
    required String pincode,
    bool isDefault = false,
  }) async {
    final response = await request('POST', '/customer/addresses', body: {
      'label': label,
      'address': address,
      'city': city,
      'pincode': pincode,
      'isDefault': isDefault,
    });
    final decoded = jsonDecode(response.body);
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
    final response = await request('PATCH', '/customer/addresses/$id', body: {
      if (label != null) 'label': label,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
      if (isDefault != null) 'isDefault': isDefault,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The address update response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<void> deleteAddress(String id) async {
    await request('DELETE', '/customer/addresses/$id');
  }

  Future<AccountRecord> createSupportRequest({
    required String subject,
    required String message,
  }) async {
    final response = await request('POST', '/support/requests', body: {
      'subject': subject,
      'message': message,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The support response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> supportRequest(String id) async {
    final response = await request('GET', '/support/requests/$id');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The support request response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> updateSubscription(
    String id,
    String status,
  ) async {
    final response = await request(
      'PATCH',
      '/customer/subscriptions/$id/status',
      body: {'status': status},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The subscription response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<AccountRecord> invoice(String id) async {
    final response = await request('GET', '/customer/invoices/$id/download');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The invoice response was invalid.');
    }
    return AccountRecord(decoded);
  }

  Future<List<AccountRecord>> _records(String path, String label) async {
    final response = await request('GET', path);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('The $label response was invalid.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AccountRecord.new)
        .toList();
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final token = await readAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Client-Platform': 'mobile',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final httpRequest = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers)
      ..body = body == null ? '' : jsonEncode(body);
    final response = await _client
        .send(httpRequest)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401 && retry && path != '/auth/mobile-refresh') {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        return request(method, path, body: body, retry: false);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Request failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['error'] is String) {
            message = decoded['error'] as String;
          }
          final details = decoded['details'];
          if (details is Map<String, dynamic>) {
            final fieldErrors = details['fieldErrors'];
            if (fieldErrors is Map<String, dynamic>) {
              final messages = <String>[];
              for (final entry in fieldErrors.entries) {
                if (entry.value is List) {
                  messages.addAll(
                    (entry.value as List)
                        .whereType<String>()
                        .map((detail) => '${entry.key}: $detail'),
                  );
                }
              }
              if (messages.isNotEmpty) {
                message = '$message: ${messages.join('; ')}';
              }
            }
          }
        }
      } on FormatException {
        // The status code remains the useful error when the body is not JSON.
      }
      throw ApiException(message, response.statusCode);
    }
    return response;
  }

  Future<String?> _refreshAccessToken() {
    final active = _refreshOperation;
    if (active != null) return active;
    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() => _refreshOperation = null);
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final response = await request(
        'POST',
        '/auth/mobile-refresh',
        body: {'refreshToken': refreshToken},
        retry: false,
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final accessToken = decoded['accessToken'] as String?;
      final rotatedRefreshToken = decoded['refreshToken'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          rotatedRefreshToken == null ||
          rotatedRefreshToken.isEmpty) {
        return null;
      }
      await saveAccessToken(accessToken);
      await saveRefreshToken(rotatedRefreshToken);
      return accessToken;
    } on Object catch (error) {
      debugPrint('Token refresh failed: $error');
      await clearTokens();
      return null;
    }
  }

  Future<List<NotificationItem>> notifications(String role) async {
    final path = switch (role) {
      'vendor' => '/vendor/notifications',
      'admin' => '/admin/notifications',
      'dispatcher' => '/admin/notifications',
      'customer' => '/customer/notifications',
      _ => throw UnsupportedError(
          'Notifications are not available for the $role workspace yet.',
        ),
    };
    final response = await request('GET', path);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The notifications response was invalid.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await request(
      'POST',
      '/devices/register',
      body: {
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<void> unregisterDevice(String token) async {
    await request(
      'DELETE',
      '/devices/register',
      body: {'token': token},
    );
  }

  Future<VendorDashboard> vendorDashboard() async {
    final response = await request('GET', '/vendor/dashboard');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vendor dashboard response was invalid.');
    }
    return VendorDashboard.fromJson(decoded);
  }

  Future<List<VendorOrder>> vendorOrders() async {
    final response = await request('GET', '/vendor/orders');
    return _vendorList(response, VendorOrder.fromJson, 'vendor orders');
  }

  Future<List<VendorVehicle>> vendorVehicles() async {
    final response = await request('GET', '/vendor/vehicles');
    return _vendorList(response, VendorVehicle.fromJson, 'vendor vehicles');
  }

  Future<List<VendorDriver>> vendorDrivers() async {
    final response = await request('GET', '/vendor/drivers');
    return _vendorList(response, VendorDriver.fromJson, 'vendor drivers');
  }

  Future<VendorVehicle> createVendorVehicle({
    required String registrationNumber,
    required int capacityLitres,
    bool isActive = true,
  }) async {
    final response = await request('POST', '/vendor/vehicles', body: {
      'registrationNumber': registrationNumber,
      'capacityLitres': capacityLitres,
      'isActive': isActive,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vehicle response was invalid.');
    }
    return VendorVehicle.fromJson(decoded);
  }

  Future<VendorVehicle> updateVendorVehicle(
    String id, {
    String? registrationNumber,
    int? capacityLitres,
    bool? isActive,
  }) async {
    final response = await request('PATCH', '/vendor/vehicles/$id', body: {
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
      if (capacityLitres != null) 'capacityLitres': capacityLitres,
      if (isActive != null) 'isActive': isActive,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vehicle update was invalid.');
    }
    return VendorVehicle.fromJson(decoded);
  }

  Future<VendorDriver> createVendorDriver({
    required String name,
    required String mobile,
    required String licenceNumber,
    bool isActive = true,
  }) async {
    final response = await request('POST', '/vendor/drivers', body: {
      'name': name,
      'mobileE164': mobile,
      'licenceNumber': licenceNumber,
      'isActive': isActive,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The driver response was invalid.');
    }
    return VendorDriver.fromJson(decoded);
  }

  Future<VendorDriver> updateVendorDriver(
    String id, {
    String? name,
    String? mobile,
    String? licenceNumber,
    bool? isActive,
  }) async {
    final response = await request('PATCH', '/vendor/drivers/$id', body: {
      if (name != null) 'name': name,
      if (mobile != null) 'mobileE164': mobile,
      if (licenceNumber != null) 'licenceNumber': licenceNumber,
      if (isActive != null) 'isActive': isActive,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The driver update was invalid.');
    }
    return VendorDriver.fromJson(decoded);
  }

  Future<VendorPayout> requestVendorPayout({
    required double amount,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final response = await request('POST', '/vendor/payouts/request', body: {
      'amount': amount,
      if (periodStart != null)
        'periodStart': periodStart.toIso8601String().split('T').first,
      if (periodEnd != null)
        'periodEnd': periodEnd.toIso8601String().split('T').first,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The payout request response was invalid.');
    }
    return VendorPayout.fromJson(decoded);
  }

  Future<VendorOrder> verifyVendorDelivery({
    required String orderId,
    required String otp,
    String? proofPath,
  }) async {
    final response = await request(
      'POST',
      '/vendor/orders/$orderId/delivery/verify',
      body: {
        'otp': otp,
        if (proofPath != null && proofPath.trim().isNotEmpty)
          'proofPath': proofPath.trim(),
      },
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'The delivery verification response was invalid.');
    }
    return VendorOrder.fromJson(decoded);
  }

  Future<void> updateVendorLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    await request('POST', '/vendor/location', body: {
      'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

  Future<List<VendorPayout>> vendorPayouts() async {
    final response = await request('GET', '/vendor/payouts');
    return _vendorList(response, VendorPayout.fromJson, 'vendor payouts');
  }

  Future<List<Map<String, dynamic>>> vendorComplaints() async {
    final response = await request('GET', '/vendor/complaints');
    return _mapList(response, 'vendor complaints');
  }

  Future<Map<String, dynamic>> updateVendorComplaint({
    required String id,
    required String status,
    String? resolution,
  }) async {
    final response = await request('PATCH', '/vendor/complaints/$id', body: {
      'status': status,
      if (resolution != null && resolution.trim().isNotEmpty)
        'resolution': resolution.trim(),
    });
    return _mapResponse(response, 'vendor complaint update');
  }

  Future<Map<String, dynamic>> createVendorComplaint({
    required String bookingId,
    required String subject,
    required String message,
  }) async {
    final response = await request('POST', '/vendor/complaints', body: {
      'bookingId': bookingId,
      'subject': subject,
      'message': message,
    });
    return _mapResponse(response, 'vendor complaint');
  }

  Future<List<Map<String, dynamic>>> vendorDocuments() async {
    final response = await request('GET', '/vendor/documents');
    return _mapList(response, 'vendor documents');
  }

  Future<Map<String, dynamic>> createVendorDocument({
    required String documentType,
    required String objectKey,
    String? expiresOn,
  }) async {
    final response = await request('POST', '/vendor/documents', body: {
      'documentType': documentType,
      'objectKey': objectKey,
      if (expiresOn != null && expiresOn.isNotEmpty) 'expiresOn': expiresOn,
    });
    return _mapResponse(response, 'vendor document');
  }

  Future<String> uploadVendorFile({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Choose a file no larger than 10 MB.');
    }
    const allowedTypes = {
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    if (!allowedTypes.contains(contentType)) {
      throw const FormatException('This file type is not supported.');
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw const FormatException('The selected file name is invalid.');
    }

    final signedResponse = await request(
      'POST',
      '/uploads/signed-url',
      body: {
        'path': 'vendor/${DateTime.now().millisecondsSinceEpoch}_$safeName',
        'bucket': 'urban-tanker-documents',
        'contentType': contentType,
        'size': bytes.length,
      },
    );
    final decoded = jsonDecode(signedResponse.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['signedUrl'] is! String ||
        decoded['path'] is! String) {
      throw const FormatException('The document upload link was invalid.');
    }
    final signedUri = Uri.tryParse(decoded['signedUrl'] as String);
    if (signedUri == null || signedUri.scheme != 'https') {
      throw const FormatException('The document upload link was not secure.');
    }

    final upload = http.Request('PUT', signedUri)
      ..headers['Content-Type'] = contentType
      ..bodyBytes = bytes;
    final uploadResponse = await _client
        .send(upload)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 30));
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw ApiException(
        'File upload failed (${uploadResponse.statusCode}).',
        uploadResponse.statusCode,
      );
    }
    return decoded['path'] as String;
  }

  Future<Map<String, dynamic>> updateVendorDocument({
    required String id,
    String? objectKey,
    String? documentType,
    String? expiresOn,
  }) async {
    final response = await request('PATCH', '/vendor/documents/$id', body: {
      if (objectKey != null) 'objectKey': objectKey,
      if (documentType != null) 'documentType': documentType,
      if (expiresOn != null) 'expiresOn': expiresOn,
    });
    return _mapResponse(response, 'vendor document update');
  }

  Future<Map<String, dynamic>> updateVendorAttendance({
    required String driverId,
    required String status,
    DateTime? date,
  }) async {
    final attendanceDate = date ?? DateTime.now();
    final response = await request('POST', '/vendor/attendance', body: {
      'driverId': driverId,
      'status': status,
      'date': attendanceDate.toIso8601String().split('T').first,
    });
    return _mapResponse(response, 'driver attendance');
  }

  Future<List<Map<String, dynamic>>> vendorAttendance({
    String? driverId,
    DateTime? date,
  }) async {
    final query = <String, String>{
      if (driverId != null) 'driverId': driverId,
      if (date != null) 'date': date.toIso8601String().split('T').first,
    };
    final path = Uri(
      path: '/vendor/attendance',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    final response = await request('GET', path);
    return _mapList(response, 'vendor attendance');
  }

  Future<List<VendorService>> vendorServices() async {
    final response = await request('GET', '/vendor/services');
    return _vendorList(response, VendorService.fromJson, 'vendor services');
  }

  Future<Map<String, dynamic>> updateVendorServiceAvailability({
    required String serviceCode,
    required bool enabled,
  }) async {
    final response = await request(
      'PATCH',
      '/vendor/services/$serviceCode/availability',
      body: {'enabled': enabled},
    );
    return _mapResponse(response, 'service availability');
  }

  Future<VendorOrder> transitionVendorOrder(
    String orderId, {
    required String action,
    String? status,
    String? reason,
    String? vehicleId,
    String? driverId,
  }) async {
    final response = await request(
      'PATCH',
      '/vendor/orders/$orderId/transition',
      body: {
        'action': action,
        if (status != null) 'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (driverId != null) 'driverId': driverId,
      },
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vendor order update was invalid.');
    }
    return VendorOrder.fromJson(decoded);
  }

  Future<List<VendorOfflineMutation>> vendorOfflineMutations() async {
    final response = await request('GET', '/vendor/offline-mutations');
    return _vendorList(
      response,
      VendorOfflineMutation.fromJson,
      'offline mutations',
    );
  }

  Future<VendorOfflineMutation> queueVendorMutation({
    required String mutationType,
    required String entityType,
    String? entityId,
    required Map<String, dynamic> payload,
  }) async {
    final duplicate = await _findDuplicateOfflineMutation(
      mutationType: mutationType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    if (duplicate != null) return duplicate;
    final response = await request('POST', '/vendor/offline-mutations', body: {
      'mutationType': mutationType,
      'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
      'payload': payload,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The offline mutation response was invalid.');
    }
    return VendorOfflineMutation.fromJson(decoded);
  }

  Future<VendorOfflineMutation?> _findDuplicateOfflineMutation({
    required String mutationType,
    required String entityType,
    String? entityId,
    required Map<String, dynamic> payload,
  }) async {
    final pending = await vendorOfflineMutations();
    for (final item in pending) {
      if (item.status == 'discarded' ||
          item.status == 'completed' ||
          item.type != mutationType ||
          item.entityType != entityType ||
          item.payload['status'] != payload['status'] ||
          item.payload['vehicleId'] != payload['vehicleId'] ||
          item.payload['driverId'] != payload['driverId']) {
        continue;
      }
      if (entityId == null || item.entityId == entityId) {
        return item;
      }
    }
    return null;
  }

  Future<VendorOfflineMutation> retryVendorMutation(String id) async {
    final response = await request(
      'POST',
      '/vendor/offline-mutations/$id/retry',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The mutation retry response was invalid.');
    }
    return VendorOfflineMutation.fromJson(decoded);
  }

  Future<void> discardVendorMutation(String id) async {
    await request('DELETE', '/vendor/offline-mutations/$id');
  }

  Future<Map<String, dynamic>> adminOrders({
    int page = 1,
    String? status,
    String? service,
    String? vendorId,
    String? from,
    String? to,
    bool? assigned,
    int pageSize = 25,
  }) async {
    final response = await request(
      'GET',
      _adminPath('/orders', {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null && status.isNotEmpty) 'status': status,
        if (service != null && service.isNotEmpty) 'service': service,
        if (vendorId != null && vendorId.isNotEmpty) 'vendorId': vendorId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (assigned != null) 'assigned': '$assigned',
      }),
    );
    return _mapResponse(response, 'admin orders');
  }

  Future<List<DispatcherOrder>> dispatcherOrderRows({
    int page = 1,
    String? status,
    String? service,
    String? vendorId,
    String? from,
    String? to,
    bool? assigned,
  }) async {
    final pageData = await adminOrders(
      page: page,
      status: status,
      service: service,
      vendorId: vendorId,
      from: from,
      to: to,
      assigned: assigned,
    );
    return (pageData['rows'] as List?)
            ?.whereType<Map>()
            .map((row) => DispatcherOrder.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList() ??
        const [];
  }

  Future<List<AccountRecord>> adminAlerts({String? status}) => _records(
        _adminPath('/alerts', {if (status != null) 'status': status}),
        'admin alerts',
      );

  Future<AccountRecord> updateDispatcherAlert(
    String id,
    String status,
  ) async {
    final response = await request(
      'PATCH',
      '/admin/alerts/$id',
      body: {'status': status},
    );
    return AccountRecord(await _mapResponse(response, 'dispatcher alert'));
  }

  Future<List<DispatcherAlert>> dispatcherAlertRows() async {
    final items = await adminAlerts();
    return items.map((item) => DispatcherAlert.fromJson(item.data)).toList();
  }

  Future<List<AccountRecord>> dispatcherVendors() => adminVendors();

  Future<AccountRecord> dispatcherAssignOrder(
    String orderId, {
    String? vendorId,
    String? vehicleId,
    String? driverId,
  }) =>
      assignAdminOrder(
        orderId,
        vendorId: vendorId,
        vehicleId: vehicleId,
        driverId: driverId,
      );

  Future<AccountRecord> dispatcherUpdateStatus(
    String orderId,
    String status,
  ) =>
      updateAdminOrderStatus(orderId, status);

  Future<AccountRecord> dispatcherCancelOrder(
    String orderId,
    String reason,
  ) =>
      cancelAdminOrder(orderId, reason);

  Future<AccountRecord> assignAdminOrder(
    String id, {
    String? vendorId,
    String? vehicleId,
    String? driverId,
  }) async {
    final response =
        await request('PATCH', '/admin/orders/$id/assignment', body: {
      if (vendorId != null) 'vendorId': vendorId,
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (driverId != null) 'driverId': driverId,
    });
    return AccountRecord(await _mapResponse(response, 'admin assignment'));
  }

  Future<AccountRecord> updateAdminOrderStatus(String id, String status) async {
    final response = await request(
      'PATCH',
      '/admin/orders/$id/status',
      body: {'status': status},
    );
    return AccountRecord(await _mapResponse(response, 'admin order status'));
  }

  Future<AccountRecord> cancelAdminOrder(String id, String reason) async {
    final response = await request(
      'POST',
      '/admin/orders/$id/cancel',
      body: {'reason': reason},
    );
    return AccountRecord(
        await _mapResponse(response, 'admin order cancellation'));
  }

  Future<AccountRecord> adminVendor(String id) async =>
      AccountRecord(await _adminMap('/vendors/$id', 'admin vendor'));

  Future<AccountRecord> createAdminVendor(Map<String, dynamic> body) async {
    final response = await request('POST', '/admin/vendors', body: body);
    return AccountRecord(await _mapResponse(response, 'admin vendor'));
  }

  Future<AccountRecord> updateAdminVendor(
      String id, Map<String, dynamic> body) async {
    final response = await request('PATCH', '/admin/vendors/$id', body: body);
    return AccountRecord(await _mapResponse(response, 'admin vendor update'));
  }

  Future<void> deleteAdminVendor(String id) async {
    await request('DELETE', '/admin/vendors/$id');
  }

  Future<AccountRecord> adminCustomer(String id) async =>
      AccountRecord(await _adminMap('/customers/$id', 'admin customer'));

  Future<AccountRecord> createAdminCustomer(Map<String, dynamic> body) async {
    final response = await request('POST', '/admin/customers', body: body);
    return AccountRecord(await _mapResponse(response, 'admin customer'));
  }

  Future<AccountRecord> updateAdminCustomer(
      String id, Map<String, dynamic> body) async {
    final response = await request('PATCH', '/admin/customers/$id', body: body);
    return AccountRecord(await _mapResponse(response, 'admin customer update'));
  }

  Future<void> deleteAdminCustomer(String id) async {
    await request('DELETE', '/admin/customers/$id');
  }

  Future<AccountRecord> createAdminCoupon(Map<String, dynamic> body) async {
    final response = await request('POST', '/admin/coupons', body: body);
    return AccountRecord(await _mapResponse(response, 'admin coupon'));
  }

  Future<AccountRecord> updateAdminCoupon(
      String id, Map<String, dynamic> body) async {
    final response = await request('PATCH', '/admin/coupons/$id', body: body);
    return AccountRecord(await _mapResponse(response, 'admin coupon update'));
  }

  Future<void> deleteAdminCoupon(String id) async {
    await request('DELETE', '/admin/coupons/$id');
  }

  Future<List<AccountRecord>> adminServices() async =>
      _records('/admin/services', 'admin services');

  Future<AccountRecord> createAdminService(Map<String, dynamic> body) async {
    final response = await request('POST', '/admin/services', body: body);
    return AccountRecord(await _mapResponse(response, 'admin service'));
  }

  Future<AccountRecord> updateAdminService(
      String id, Map<String, dynamic> body) async {
    final response = await request('PATCH', '/admin/services/$id', body: body);
    return AccountRecord(await _mapResponse(response, 'admin service update'));
  }

  Future<List<AccountRecord>> adminPayouts() async {
    final page = await adminPayoutPage();
    final rows = page['rows'];
    if (rows is! List) {
      throw const FormatException('The admin payouts response was invalid.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AccountRecord.new)
        .toList();
  }

  Future<List<AccountRecord>> adminPartnerApplications({String? status}) async {
    final path = _adminPath('/partner-applications', {
      if (status != null) 'status': status,
    });
    return _records(path, 'partner applications');
  }

  Future<AccountRecord> reviewPartnerApplication(
    String id, {
    required String status,
    String? reviewNote,
  }) async {
    final response = await request('PATCH', '/admin/partner-applications/$id',
        body: {
          'status': status,
          if (reviewNote != null) 'reviewNote': reviewNote
        });
    return AccountRecord(await _mapResponse(response, 'partner review'));
  }

  Future<Map<String, dynamic>> adminReport(Map<String, dynamic> body) async {
    final response = await request('POST', '/admin/reports', body: body);
    return _mapResponse(response, 'admin report');
  }

  Future<void> adminStorageCleanup() async {
    await request('POST', '/admin/storage/cleanup');
  }

  Future<void> sendAdminNotification(Map<String, dynamic> body) async {
    await request('POST', '/admin/notifications', body: body);
  }

  Future<List<NotificationItem>> adminNotifications() async =>
      notifications('admin');

  Future<void> markAdminNotificationRead(String id) async {
    await request('PATCH', '/admin/notifications/$id/read');
  }

  Future<Map<String, dynamic>> adminPayoutPage({int page = 1}) async {
    final response =
        await request('GET', _adminPath('/payouts', {'page': '$page'}));
    return _mapResponse(response, 'admin payouts');
  }

  Future<AccountRecord> updateAdminPayout(String id, String status) async {
    final response = await request(
      'PATCH',
      '/admin/payouts/$id/status',
      body: {'status': status},
    );
    return AccountRecord(await _mapResponse(response, 'admin payout update'));
  }

  Future<Map<String, dynamic>> adminAuditLogs({
    int page = 1,
    String? actorId,
    String? action,
    String? entityType,
  }) async {
    final response = await request(
      'GET',
      _adminPath('/audit-logs', {
        'page': '$page',
        if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
        if (action != null && action.isNotEmpty) 'action': action,
        if (entityType != null && entityType.isNotEmpty)
          'entityType': entityType,
      }),
    );
    return _mapResponse(response, 'admin audit logs');
  }

  String _adminPath(String path, Map<String, String> query) {
    final uri =
        Uri(path: '/admin$path', queryParameters: query.isEmpty ? null : query);
    return uri.toString();
  }

  Future<Map<String, dynamic>> _adminMap(String path, String label) async {
    final response = await request('GET', '/admin$path');
    return _mapResponse(response, label);
  }

  Future<List<T>> _vendorList<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parse,
    String label,
  ) async {
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('The $label response was invalid.');
    }

    return decoded.whereType<Map<String, dynamic>>().map(parse).toList();
  }

  Future<Map<String, dynamic>> _mapResponse(
    http.Response response,
    String label,
  ) async {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('The $label response was invalid.');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _mapList(
    http.Response response,
    String label,
  ) async {
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('The $label response was invalid.');
    }
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> markNotificationRead(String role, String id) async {
    final prefix = role == 'vendor'
        ? '/vendor'
        : role == 'dispatcher' || role == 'admin'
            ? '/admin'
            : '/customer';
    await request('PATCH', '$prefix/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead(String role) async {
    if (role != 'customer') {
      throw UnsupportedError(
        'Mark all as read is not available for the $role workspace.',
      );
    }
    await request('PATCH', '/customer/notifications/read-all');
  }

  Future<AuthResult> _authRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await request('POST', path, body: body, retry: false);
    return _saveAuthResult(jsonDecode(response.body));
  }

  Future<AuthResult> _saveAuthResult(dynamic body) async {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('The authentication response was invalid.');
    }
    final result = AuthResult.fromJson(body);
    await saveAccessToken(result.accessToken);
    if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
      await saveRefreshToken(result.refreshToken!);
    }
    return result;
  }
}
