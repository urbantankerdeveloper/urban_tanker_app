import '../../models/account.dart';
import '../../models/dispatcher.dart';
import '../../models/vendor.dart';
import 'api_decode.dart';
import 'api_transport.dart';
import 'api_types.dart';

/// Admin and dispatcher endpoints: vendors, customers, orders, alerts, fleet,
/// services, promos, payouts, reports and audit logs.
class AdminApi {
  AdminApi(this._api);

  final ApiTransport _api;

  Future<List<AccountRecord>> adminVendors() =>
      _records('/admin/vendors', 'admin vendors');

  Future<List<AccountRecord>> adminCustomers() =>
      _records('/admin/customers', 'admin customers');

  Future<List<AccountRecord>> adminCoupons() =>
      _records('/admin/coupons', 'admin coupons');

  Future<List<AdminFleetVehicle>> adminVehicles() async {
    final response = await _api.request('GET', '/admin/vehicles');
    return parseList(response, AdminFleetVehicle.fromJson, 'admin vehicles');
  }

  Future<List<AdminFleetDriver>> adminDrivers() async {
    final response = await _api.request('GET', '/admin/drivers');
    return parseList(response, AdminFleetDriver.fromJson, 'admin drivers');
  }

  Future<AdminFleetVehicle> createAdminVehicle({
    required String vendorId,
    required String registrationNumber,
    required int capacityLitres,
    List<String> supportedServices = const [],
  }) async {
    final response = await _api.request('POST', '/admin/vehicles', body: {
      'vendorId': vendorId,
      'registrationNumber': registrationNumber,
      'capacityLitres': capacityLitres,
      'supportedServices': supportedServices,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The vehicle response was invalid.');
    }
    return AdminFleetVehicle.fromJson(decoded);
  }

  Future<AdminFleetDriver> createAdminDriver({
    required String vendorId,
    required String name,
    required String mobile,
    required String licenceNumber,
  }) async {
    final response = await _api.request('POST', '/admin/drivers', body: {
      'vendorId': vendorId,
      'name': name,
      'mobileE164': normalizeIndianPhone(mobile),
      'licenceNumber': licenceNumber,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The driver response was invalid.');
    }
    return AdminFleetDriver.fromJson(decoded);
  }

  Future<void> updateAdminVehicleStatus(
    String id, {
    required String verification,
    required bool isActive,
  }) async {
    await _api.request('PATCH', '/admin/vehicles/$id/status', body: {
      'verification': verification,
      'isActive': isActive,
    });
  }

  Future<void> updateAdminDriverStatus(
    String id, {
    required String verification,
    required bool isActive,
  }) async {
    await _api.request('PATCH', '/admin/drivers/$id/status', body: {
      'verification': verification,
      'isActive': isActive,
    });
  }

  Future<Map<String, dynamic>> adminHealth() async {
    final response = await _api.request('GET', '/admin/system/health');
    return mapResponse(response, 'admin health');
  }

  Future<void> updateVendorVerification(String id, String status) async {
    await _api.request(
      'PATCH',
      '/admin/vendors/$id/status',
      body: {'status': status},
    );
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
    final response = await _api.request(
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
    return mapResponse(response, 'admin orders');
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
    final response = await _api.request(
      'PATCH',
      '/admin/alerts/$id',
      body: {'status': status},
    );
    return AccountRecord(await mapResponse(response, 'dispatcher alert'));
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
        await _api.request('PATCH', '/admin/orders/$id/assignment', body: {
      if (vendorId != null) 'vendorId': vendorId,
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (driverId != null) 'driverId': driverId,
    });
    return AccountRecord(await mapResponse(response, 'admin assignment'));
  }

  Future<AccountRecord> updateAdminOrderStatus(String id, String status) async {
    final response = await _api.request(
      'PATCH',
      '/admin/orders/$id/status',
      body: {'status': status},
    );
    return AccountRecord(await mapResponse(response, 'admin order status'));
  }

  Future<AccountRecord> cancelAdminOrder(String id, String reason) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 2 || normalizedReason.length > 500) {
      throw const FormatException(
        'Enter a cancellation reason between 2 and 500 characters.',
      );
    }
    final response = await _api.request(
      'POST',
      '/admin/orders/$id/cancel',
      body: {'reason': normalizedReason},
    );
    return AccountRecord(
        await mapResponse(response, 'admin order cancellation'));
  }

  Future<AccountRecord> adminVendor(String id) async =>
      AccountRecord(await _adminMap('/vendors/$id', 'admin vendor'));

  Future<AccountRecord> createAdminVendor(Map<String, dynamic> body) async {
    final response = await _api.request('POST', '/admin/vendors', body: body);
    return AccountRecord(await mapResponse(response, 'admin vendor'));
  }

  Future<AccountRecord> updateAdminVendor(
      String id, Map<String, dynamic> body) async {
    final response =
        await _api.request('PATCH', '/admin/vendors/$id', body: body);
    return AccountRecord(await mapResponse(response, 'admin vendor update'));
  }

  Future<void> deleteAdminVendor(String id) async {
    await _api.request('DELETE', '/admin/vendors/$id');
  }

  Future<AccountRecord> adminCustomer(String id) async =>
      AccountRecord(await _adminMap('/customers/$id', 'admin customer'));

  Future<AccountRecord> createAdminCustomer(Map<String, dynamic> body) async {
    final response = await _api.request('POST', '/admin/customers', body: body);
    return AccountRecord(await mapResponse(response, 'admin customer'));
  }

  Future<AccountRecord> updateAdminCustomer(
      String id, Map<String, dynamic> body) async {
    final response =
        await _api.request('PATCH', '/admin/customers/$id', body: body);
    return AccountRecord(await mapResponse(response, 'admin customer update'));
  }

  Future<void> deleteAdminCustomer(String id) async {
    await _api.request('DELETE', '/admin/customers/$id');
  }

  Future<AccountRecord> createAdminCoupon(Map<String, dynamic> body) async {
    final response = await _api.request('POST', '/admin/coupons', body: body);
    return AccountRecord(await mapResponse(response, 'admin coupon'));
  }

  Future<AccountRecord> updateAdminCoupon(
      String id, Map<String, dynamic> body) async {
    final response =
        await _api.request('PATCH', '/admin/coupons/$id', body: body);
    return AccountRecord(await mapResponse(response, 'admin coupon update'));
  }

  Future<void> deleteAdminCoupon(String id) async {
    await _api.request('DELETE', '/admin/coupons/$id');
  }

  Future<List<AccountRecord>> adminServices() async =>
      _records('/admin/services', 'admin services');

  Future<AccountRecord> createAdminService(Map<String, dynamic> body) async {
    final response = await _api.request('POST', '/admin/services', body: body);
    return AccountRecord(await mapResponse(response, 'admin service'));
  }

  Future<AccountRecord> updateAdminService(
      String id, Map<String, dynamic> body) async {
    final response =
        await _api.request('PATCH', '/admin/services/$id', body: body);
    return AccountRecord(await mapResponse(response, 'admin service update'));
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
    final response = await _api.request(
        'PATCH', '/admin/partner-applications/$id', body: {
      'status': status,
      if (reviewNote != null) 'reviewNote': reviewNote
    });
    return AccountRecord(await mapResponse(response, 'partner review'));
  }

  Future<Map<String, dynamic>> adminReport(Map<String, dynamic> body) async {
    final response = await _api.request('POST', '/admin/reports', body: body);
    return mapResponse(response, 'admin report');
  }

  Future<void> adminStorageCleanup() async {
    await _api.request('POST', '/admin/storage/cleanup');
  }

  Future<void> sendAdminNotification(Map<String, dynamic> body) async {
    await _api.request('POST', '/admin/notifications', body: body);
  }

  Future<Map<String, dynamic>> adminPayoutPage({int page = 1}) async {
    final response =
        await _api.request('GET', _adminPath('/payouts', {'page': '$page'}));
    return mapResponse(response, 'admin payouts');
  }

  Future<AccountRecord> updateAdminPayout(String id, String status) async {
    final response = await _api.request(
      'PATCH',
      '/admin/payouts/$id/status',
      body: {'status': status},
    );
    return AccountRecord(await mapResponse(response, 'admin payout update'));
  }

  Future<Map<String, dynamic>> adminAuditLogs({
    int page = 1,
    String? actorId,
    String? action,
    String? entityType,
  }) async {
    final response = await _api.request(
      'GET',
      _adminPath('/audit-logs', {
        'page': '$page',
        if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
        if (action != null && action.isNotEmpty) 'action': action,
        if (entityType != null && entityType.isNotEmpty)
          'entityType': entityType,
      }),
    );
    return mapResponse(response, 'admin audit logs');
  }

  Future<List<AccountRecord>> _records(String path, String label) =>
      recordList(_api, path, label);

  String _adminPath(String path, Map<String, String> query) {
    final uri =
        Uri(path: '/admin$path', queryParameters: query.isEmpty ? null : query);
    return uri.toString();
  }

  Future<Map<String, dynamic>> _adminMap(String path, String label) async {
    final response = await _api.request('GET', '/admin$path');
    return mapResponse(response, label);
  }
}
