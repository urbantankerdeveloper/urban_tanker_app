import 'booking.dart';

class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.reference,
    required this.serviceCode,
    required this.address,
    required this.status,
    required this.amountPaise,
    this.serviceDetails = const [],
    required this.createdAt,
    required this.scheduledFor,
    this.vehicleId,
    this.driverId,
    this.vehicle,
    this.driver,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String reference;
  final String serviceCode;
  final String address;
  final String status;
  final int amountPaise;
  final List<VendorOrderServiceDetail> serviceDetails;
  final DateTime? createdAt;
  final DateTime? scheduledFor;
  final String? vehicleId;
  final String? driverId;
  final String? vehicle;
  final String? driver;
  final double? latitude;
  final double? longitude;

  factory VendorOrder.fromJson(Map<String, dynamic> json) => VendorOrder(
        id: (json['id'] ?? '').toString(),
        reference: (json['reference'] ?? json['id'] ?? '').toString(),
        serviceCode: (json['service_code'] ?? json['service'] ?? '').toString(),
        address: (json['address_text'] ?? json['location'] ?? '').toString(),
        status: _normalizeVendorOrderStatus(json['status']),
        amountPaise: _vendorAmountPaise(json),
        serviceDetails: _records(
          json['serviceDetails'] ?? json['service_details'],
          VendorOrderServiceDetail.fromJson,
        ),
        createdAt: DateTime.tryParse(
            (json['created_at'] ?? json['createdAt'] ?? '').toString()),
        scheduledFor: DateTime.tryParse(
            (json['scheduled_for'] ?? json['scheduledFor'] ?? '').toString()),
        vehicleId: (json['vehicle_id'] ?? json['vehicleId'])?.toString(),
        driverId: (json['driver_id'] ?? json['driverId'])?.toString(),
        vehicle:
            (json['vehicle'] ?? json['vehicleName'] ?? json['assignedVehicle'])
                ?.toString(),
        driver: (json['driver'] ?? json['driverName'] ?? json['assignedDriver'])
            ?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  double get amountRupees => amountPaise / 100;

  Booking toBooking() => Booking(
        id: id,
        reference: reference,
        status: status,
        location: address,
        capacity: '',
        deliveryDate: scheduledFor,
        createdAt: createdAt,
        quotedAmount: amountPaise.toString(),
        latitude: latitude,
        longitude: longitude,
      );
}

class VendorOrderServiceDetail {
  const VendorOrderServiceDetail({
    required this.service,
    required this.capacity,
    required this.details,
    this.waterType,
    this.tankerCount,
  });

  final String service;
  final String capacity;
  final String details;
  final String? waterType;
  final String? tankerCount;

  factory VendorOrderServiceDetail.fromJson(Map<String, dynamic> json) =>
      VendorOrderServiceDetail(
        service: (json['service'] ?? json['serviceId'] ?? '').toString(),
        capacity: (json['capacity'] ?? '').toString(),
        details: (json['details'] ?? '').toString(),
        waterType: json['waterType']?.toString(),
        tankerCount: json['tankerCount']?.toString(),
      );
}

String _normalizeVendorOrderStatus(Object? value) {
  final status = (value ?? 'pending_vendor').toString().trim().toLowerCase();
  return switch (status) {
    'available' => 'pending_vendor',
    'assigned' => 'vendor_assigned',
    'en route' => 'en_route',
    'rejected' => 'cancelled',
    _ => status.replaceAll(' ', '_'),
  };
}

int _vendorAmountPaise(Map<String, dynamic> json) {
  final paise = json['quoted_amount_paise'];
  if (paise is num) return paise.toInt();
  final amount = json['amount'];
  if (amount is num) return (amount * 100).round();
  if (amount is String) {
    final parsed = double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), ''));
    if (parsed != null) return (parsed * 100).round();
  }
  return 0;
}

class VendorVehicle {
  const VendorVehicle({
    required this.id,
    required this.registrationNumber,
    required this.capacityLitres,
    required this.active,
    required this.verification,
  });

  final String id;
  final String registrationNumber;
  final int capacityLitres;
  final bool active;
  final String verification;

  factory VendorVehicle.fromJson(Map<String, dynamic> json) => VendorVehicle(
        id: (json['id'] ?? '').toString(),
        registrationNumber: (json['registration_number'] ?? '').toString(),
        capacityLitres: (json['capacity_litres'] as num?)?.toInt() ?? 0,
        active: json['is_active'] == true,
        verification: (json['verification'] ?? 'pending').toString(),
      );

  bool get assignable => active && verification.toLowerCase() == 'approved';
}

class VendorDriver {
  const VendorDriver({
    required this.id,
    required this.name,
    required this.mobile,
    required this.active,
    required this.verification,
  });

  final String id;
  final String name;
  final String mobile;
  final bool active;
  final String verification;

  factory VendorDriver.fromJson(Map<String, dynamic> json) => VendorDriver(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        mobile: (json['mobile_e164'] ?? json['mobile'] ?? '').toString(),
        active: json['is_active'] == true,
        verification: (json['verification'] ?? 'pending').toString(),
      );

  bool get assignable => active && verification.toLowerCase() == 'approved';
}

class VendorPayout {
  const VendorPayout({
    required this.id,
    required this.amountPaise,
    required this.status,
    required this.reference,
    required this.createdAt,
    this.paidAt,
    this.periodStart,
    this.periodEnd,
  });

  final String id;
  final int amountPaise;
  final String status;
  final String reference;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory VendorPayout.fromJson(Map<String, dynamic> json) {
    final amountPaise = json['amount_paise'];
    final amount = json['amount'];
    return VendorPayout(
      id: (json['id'] ?? '').toString(),
      amountPaise: amountPaise is num
          ? amountPaise.toInt()
          : amount is num
              ? (amount * 100).round()
              : 0,
      status: (json['status'] ?? 'pending').toString(),
      reference:
          (json['reference'] ?? json['booking_reference'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      periodStart: DateTime.tryParse((json['period_start'] ?? '').toString()),
      periodEnd: DateTime.tryParse((json['period_end'] ?? '').toString()),
    );
  }

  double get amountRupees => amountPaise / 100;
}

class VendorDashboard {
  const VendorDashboard({
    required this.orders,
    required this.vehicles,
    required this.drivers,
  });

  final List<VendorOrder> orders;
  final List<VendorVehicle> vehicles;
  final List<VendorDriver> drivers;

  factory VendorDashboard.fromJson(Map<String, dynamic> json) =>
      VendorDashboard(
        orders: _records(json['orders'], VendorOrder.fromJson),
        vehicles: _records(json['vehicles'], VendorVehicle.fromJson),
        drivers: _records(json['drivers'], VendorDriver.fromJson),
      );
}

List<T> _records<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parse,
) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(parse).toList();
}

class VendorOfflineMutation {
  const VendorOfflineMutation({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.status,
    required this.payload,
    required this.lastError,
  });

  final String id;
  final String type;
  final String entityType;
  final String? entityId;
  final String status;
  final Map<String, dynamic> payload;
  final String? lastError;

  factory VendorOfflineMutation.fromJson(Map<String, dynamic> json) =>
      VendorOfflineMutation(
        id: (json['id'] ?? '').toString(),
        type: (json['mutation_type'] ?? '').toString(),
        entityType: (json['entity_type'] ?? '').toString(),
        entityId: json['entity_id']?.toString(),
        status: (json['conflict_status'] ?? 'queued').toString(),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
        lastError: json['last_error']?.toString(),
      );
}

class VendorService {
  const VendorService({
    required this.code,
    required this.name,
    required this.description,
    required this.enabled,
  });

  final String code;
  final String name;
  final String description;
  final bool enabled;

  factory VendorService.fromJson(Map<String, dynamic> json) => VendorService(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? json['code'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        enabled: json['vendor_enabled'] != false,
      );
}
