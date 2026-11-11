import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/vendor.dart';
import 'api_decode.dart';
import 'api_transport.dart';
import 'api_types.dart';

/// Vendor dashboard, fleet, orders, payouts, documents, attendance and the
/// offline mutation queue.
class VendorApi {
  VendorApi(this._api);

  final ApiTransport _api;

  Future<VendorDashboard> vendorDashboard() async {
    final response = await _api.request('GET', '/vendor/dashboard');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vendor dashboard response was invalid.');
    }
    return VendorDashboard.fromJson(decoded);
  }

  Future<List<VendorOrder>> vendorOrders() async {
    final response = await _api.request('GET', '/vendor/orders');
    return parseList(response, VendorOrder.fromJson, 'vendor orders');
  }

  Future<List<VendorVehicle>> vendorVehicles() async {
    final response = await _api.request('GET', '/vendor/vehicles');
    return parseList(response, VendorVehicle.fromJson, 'vendor vehicles');
  }

  Future<List<VendorDriver>> vendorDrivers() async {
    final response = await _api.request('GET', '/vendor/drivers');
    return parseList(response, VendorDriver.fromJson, 'vendor drivers');
  }

  Future<VendorVehicle> createVendorVehicle({
    required String registrationNumber,
    required int capacityLitres,
    bool isActive = true,
  }) async {
    final response = await _api.request('POST', '/vendor/vehicles', body: {
      'registrationNumber': registrationNumber,
      'capacityLitres': capacityLitres,
      'isActive': isActive,
    });
    final decoded = decodeBody(response);
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
    final response = await _api.request('PATCH', '/vendor/vehicles/$id', body: {
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
      if (capacityLitres != null) 'capacityLitres': capacityLitres,
      if (isActive != null) 'isActive': isActive,
    });
    final decoded = decodeBody(response);
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
    final response = await _api.request('POST', '/vendor/drivers', body: {
      'name': name,
      'mobileE164': mobile,
      'licenceNumber': licenceNumber,
      'isActive': isActive,
    });
    final decoded = decodeBody(response);
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
    final response = await _api.request('PATCH', '/vendor/drivers/$id', body: {
      if (name != null) 'name': name,
      if (mobile != null) 'mobileE164': mobile,
      if (licenceNumber != null) 'licenceNumber': licenceNumber,
      if (isActive != null) 'isActive': isActive,
    });
    final decoded = decodeBody(response);
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
    final response =
        await _api.request('POST', '/vendor/payouts/request', body: {
      'amount': amount,
      if (periodStart != null)
        'periodStart': periodStart.toIso8601String().split('T').first,
      if (periodEnd != null)
        'periodEnd': periodEnd.toIso8601String().split('T').first,
    });
    final decoded = decodeBody(response);
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
    final response = await _api.request(
      'POST',
      '/vendor/orders/$orderId/delivery/verify',
      body: {
        'otp': otp,
        if (proofPath != null && proofPath.trim().isNotEmpty)
          'proofPath': proofPath.trim(),
      },
    );
    final decoded = decodeBody(response);
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
    await _api.request('POST', '/vendor/location', body: {
      'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

  Future<List<VendorPayout>> vendorPayouts() async {
    final response = await _api.request('GET', '/vendor/payouts');
    return parseList(response, VendorPayout.fromJson, 'vendor payouts');
  }

  Future<List<Map<String, dynamic>>> vendorComplaints() async {
    final response = await _api.request('GET', '/vendor/complaints');
    return mapList(response, 'vendor complaints');
  }

  Future<Map<String, dynamic>> updateVendorComplaint({
    required String id,
    required String status,
    String? resolution,
  }) async {
    final response =
        await _api.request('PATCH', '/vendor/complaints/$id', body: {
      'status': status,
      if (resolution != null && resolution.trim().isNotEmpty)
        'resolution': resolution.trim(),
    });
    return mapResponse(response, 'vendor complaint update');
  }

  Future<Map<String, dynamic>> createVendorComplaint({
    required String bookingId,
    required String subject,
    required String message,
  }) async {
    final response = await _api.request('POST', '/vendor/complaints', body: {
      'bookingId': bookingId,
      'subject': subject,
      'message': message,
    });
    return mapResponse(response, 'vendor complaint');
  }

  Future<List<Map<String, dynamic>>> vendorDocuments() async {
    final response = await _api.request('GET', '/vendor/documents');
    return mapList(response, 'vendor documents');
  }

  Future<Map<String, dynamic>> createVendorDocument({
    required String documentType,
    required String objectKey,
    String? expiresOn,
  }) async {
    final response = await _api.request('POST', '/vendor/documents', body: {
      'documentType': documentType,
      'objectKey': objectKey,
      if (expiresOn != null && expiresOn.isNotEmpty) 'expiresOn': expiresOn,
    });
    return mapResponse(response, 'vendor document');
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

    return _uploadToDocumentBucket(
      path: 'vendor/${DateTime.now().millisecondsSinceEpoch}_$safeName',
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<String> _uploadToDocumentBucket({
    required String path,
    required String contentType,
    required List<int> bytes,
  }) async {
    final signedResponse = await _api.request(
      'POST',
      '/uploads/signed-url',
      body: {
        'path': path,
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
    final uploadResponse = await _api.sendRequest(
      upload,
      timeout: const Duration(seconds: 30),
    );
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
    final response =
        await _api.request('PATCH', '/vendor/documents/$id', body: {
      if (objectKey != null) 'objectKey': objectKey,
      if (documentType != null) 'documentType': documentType,
      if (expiresOn != null) 'expiresOn': expiresOn,
    });
    return mapResponse(response, 'vendor document update');
  }

  Future<Map<String, dynamic>> updateVendorAttendance({
    required String driverId,
    required String status,
    DateTime? date,
  }) async {
    final attendanceDate = date ?? DateTime.now();
    final response = await _api.request('POST', '/vendor/attendance', body: {
      'driverId': driverId,
      'status': status,
      'date': attendanceDate.toIso8601String().split('T').first,
    });
    return mapResponse(response, 'driver attendance');
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
    final response = await _api.request('GET', path);
    return mapList(response, 'vendor attendance');
  }

  Future<List<VendorService>> vendorServices() async {
    final response = await _api.request('GET', '/vendor/services');
    return parseList(response, VendorService.fromJson, 'vendor services');
  }

  Future<Map<String, dynamic>> updateVendorServiceAvailability({
    required String serviceCode,
    required bool enabled,
  }) async {
    final response = await _api.request(
      'PATCH',
      '/vendor/services/$serviceCode/availability',
      body: {'enabled': enabled},
    );
    _api.invalidateReadCache(path: '/vendor/services');
    return mapResponse(response, 'service availability');
  }

  Future<VendorOrder> transitionVendorOrder(
    String orderId, {
    required String action,
    String? status,
    String? reason,
    String? vehicleId,
    String? driverId,
  }) async {
    if (action == 'reject' &&
        ((reason?.trim().length ?? 0) < 2 ||
            (reason?.trim().length ?? 0) > 500)) {
      throw const FormatException(
        'Enter a cancellation reason between 2 and 500 characters.',
      );
    }
    final response = await _api.request(
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
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vendor order update was invalid.');
    }
    return VendorOrder.fromJson(decoded);
  }

  Future<List<VendorOfflineMutation>> vendorOfflineMutations() async {
    final response = await _api.request('GET', '/vendor/offline-mutations');
    return parseList(
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
    final response =
        await _api.request('POST', '/vendor/offline-mutations', body: {
      'mutationType': mutationType,
      'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
      'payload': payload,
    });
    final decoded = decodeBody(response);
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
    final response = await _api.request(
      'POST',
      '/vendor/offline-mutations/$id/retry',
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The mutation retry response was invalid.');
    }
    return VendorOfflineMutation.fromJson(decoded);
  }

  Future<void> discardVendorMutation(String id) async {
    await _api.request('DELETE', '/vendor/offline-mutations/$id');
  }
}
