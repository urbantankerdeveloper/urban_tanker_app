import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/notification.dart';
import '../models/booking.dart';
import '../models/account.dart';
import '../models/service.dart';
import '../models/session.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
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
                  defaultValue: 'http://10.0.2.2:3000/api',
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

  Future<AuthResult> signup({
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
    if (decoded['accessToken'] == null &&
        decoded['requiresEmailVerification'] == true) {
      throw const ApiException(
        'Account created. Check your email to verify the account, then sign in.',
        202,
      );
    }
    return _saveAuthResult(decoded);
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
    String? notes,
    String paymentMethod = 'cod',
    String? couponCode,
  }) async {
    final response = await request(
      'POST',
      '/customer/orders/quote',
      body: {
        'serviceId': serviceId,
        'capacity': capacity,
        'location': location,
        'deliveryDate': deliveryDate,
        'notes': notes,
        'paymentMethod': paymentMethod,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'couponCode': couponCode.trim().toUpperCase(),
      },
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The booking response was invalid.');
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
    if (decoded is! Map<String, dynamic> ||
        decoded['expiresAt'] is! String) {
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
    required String phone,
  }) async {
    final response = await request(
      'PATCH',
      '/customer/profile',
      body: {'name': name, 'email': email, 'phone': phone},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The updated profile response was invalid.');
    }
    return CustomerProfile.fromJson(decoded);
  }

  Future<List<AccountRecord>> addresses() =>
      _records('/customer/addresses', 'addresses');

  Future<List<AccountRecord>> wallet() => _records('/customer/wallet', 'wallet');

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
  }) async {
    final response = await request('POST', '/customer/addresses', body: {
      'label': label,
      'address': address,
      'city': city,
      'pincode': pincode,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The address response was invalid.');
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
        if (decoded is Map<String, dynamic> && decoded['error'] is String) {
          message = decoded['error'] as String;
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

  Future<void> markNotificationRead(String role, String id) async {
    final prefix = role == 'vendor' ? '/vendor' : '/customer';
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
