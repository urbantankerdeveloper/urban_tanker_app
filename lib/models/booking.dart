class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.status,
    required this.location,
    required this.capacity,
    required this.deliveryDate,
    required this.createdAt,
    this.quotedAmount,
    this.paymentStatus,
  });

  final String id;
  final String reference;
  final String status;
  final String location;
  final String capacity;
  final DateTime? deliveryDate;
  final DateTime? createdAt;
  final String? quotedAmount;
  final String? paymentStatus;

  double? get quotedAmountRupees {
    final paise = int.tryParse(quotedAmount ?? '');
    return paise == null ? null : paise / 100;
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: (json['id'] ?? '').toString(),
      reference: (json['reference'] ?? json['order_number'] ?? json['id'] ?? '')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      location: (json['location'] ??
              json['delivery_address'] ??
              json['address_text'] ??
              'Address unavailable')
          .toString(),
      capacity: (json['capacity_litres'] ?? json['capacity'] ?? '').toString(),
      deliveryDate: DateTime.tryParse(
        (json['scheduled_for'] ?? json['delivery_date'] ?? '').toString(),
      ),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? '').toString(),
      ),
      quotedAmount: json['quoted_amount_paise']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
    );
  }
}

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.orderId,
    required this.status,
    required this.trackingAvailable,
    this.latitude,
    this.longitude,
    this.vehicle,
    this.driver,
    this.recordedAt,
  });

  final String orderId;
  final String status;
  final bool trackingAvailable;
  final double? latitude;
  final double? longitude;
  final String? vehicle;
  final String? driver;
  final DateTime? recordedAt;

  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    return TrackingSnapshot(
      orderId: (json['orderId'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      trackingAvailable: json['trackingAvailable'] == true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      vehicle: json['vehicle']?.toString(),
      driver: json['driver']?.toString(),
      recordedAt: DateTime.tryParse(
        (json['recorded_at'] ?? '').toString(),
      ),
    );
  }
}
