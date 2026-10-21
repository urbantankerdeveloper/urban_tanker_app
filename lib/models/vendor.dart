import 'booking.dart';

class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.reference,
    required this.serviceCode,
    required this.address,
    required this.status,
    required this.amountPaise,
    required this.createdAt,
    required this.scheduledFor,
    this.vehicleId,
    this.driverId,
  });

  final String id;
  final String reference;
  final String serviceCode;
  final String address;
  final String status;
  final int amountPaise;
  final DateTime? createdAt;
  final DateTime? scheduledFor;
  final String? vehicleId;
  final String? driverId;

  factory VendorOrder.fromJson(Map<String, dynamic> json) => VendorOrder(
        id: (json['id'] ?? '').toString(),
        reference: (json['reference'] ?? json['id'] ?? '').toString(),
        serviceCode: (json['service_code'] ?? '').toString(),
        address: (json['address_text'] ?? json['location'] ?? '').toString(),
        status: (json['status'] ?? 'pending_vendor').toString(),
        amountPaise: (json['quoted_amount_paise'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        scheduledFor:
            DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
        vehicleId: json['vehicle_id']?.toString(),
        driverId: json['driver_id']?.toString(),
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
      );
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
  });

  final String id;
  final int amountPaise;
  final String status;
  final String reference;
  final DateTime? createdAt;
  final DateTime? paidAt;

  factory VendorPayout.fromJson(Map<String, dynamic> json) => VendorPayout(
        id: (json['id'] ?? '').toString(),
        amountPaise: ((json['amount_paise'] ?? json['amount']) as num?)?.toInt() ?? 0,
        status: (json['status'] ?? 'pending').toString(),
        reference: (json['reference'] ?? json['booking_reference'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      );

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

  factory VendorDashboard.fromJson(Map<String, dynamic> json) => VendorDashboard(
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
    required this.status,
    required this.payload,
    required this.lastError,
  });

  final String id;
  final String type;
  final String entityType;
  final String status;
  final Map<String, dynamic> payload;
  final String? lastError;

  factory VendorOfflineMutation.fromJson(Map<String, dynamic> json) =>
      VendorOfflineMutation(
        id: (json['id'] ?? '').toString(),
        type: (json['mutation_type'] ?? '').toString(),
        entityType: (json['entity_type'] ?? '').toString(),
        status: (json['conflict_status'] ?? 'queued').toString(),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
        lastError: json['last_error']?.toString(),
      );
}
