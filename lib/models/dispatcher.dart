class DispatcherOrder {
  const DispatcherOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.serviceCode,
    required this.address,
    required this.amountPaise,
    required this.scheduledFor,
    this.vendorId,
    this.vehicleId,
    this.driverId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String reference;
  final String status;
  final String serviceCode;
  final String address;
  final int amountPaise;
  final DateTime? scheduledFor;
  final String? vendorId;
  final String? vehicleId;
  final String? driverId;
  final double? latitude;
  final double? longitude;

  factory DispatcherOrder.fromJson(Map<String, dynamic> json) =>
      DispatcherOrder(
        id: (json['id'] ?? '').toString(),
        reference: (json['reference'] ?? json['id'] ?? '').toString(),
        status: (json['status'] ?? 'pending_vendor').toString(),
        serviceCode: (json['service_code'] ?? '').toString(),
        address: (json['address_text'] ?? '').toString(),
        amountPaise: (json['quoted_amount_paise'] as num?)?.toInt() ?? 0,
        scheduledFor:
            DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
        vendorId: json['vendor_id']?.toString(),
        vehicleId: json['vehicle_id']?.toString(),
        driverId: json['driver_id']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  bool get isAssigned => vendorId != null && vendorId!.isNotEmpty;
  double get amountRupees => amountPaise / 100;

  List<String> get allowedNextStatuses => switch (status) {
        'pending_vendor' => const ['vendor_assigned', 'accepted'],
        'vendor_assigned' => const ['accepted'],
        'accepted' => const ['en_route'],
        'en_route' => const ['arrived'],
        'arrived' => const ['delivered'],
        _ => const [],
      };
}

class DispatcherAlert {
  const DispatcherAlert({
    required this.id,
    required this.reference,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reference;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DispatcherAlert.fromJson(Map<String, dynamic> json) =>
      DispatcherAlert(
        id: (json['id'] ?? '').toString(),
        reference: (json['reference'] ?? json['id'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      );
}
