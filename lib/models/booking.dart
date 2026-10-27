import 'booking_service_details.dart';

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.status,
    required this.location,
    required this.capacity,
    required this.deliveryDate,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.notes,
    this.cancellationReason,
    this.serviceId,
    this.quotedAmount,
    this.paymentStatus,
    this.services = const [],
  });

  final String id;
  final String reference;
  final String status;
  final String location;
  final String capacity;
  final DateTime? deliveryDate;
  final DateTime? createdAt;
  final String? serviceId;
  final String? quotedAmount;
  final String? paymentStatus;
  final List<BookingServiceDetails> services;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? cancellationReason;

  double? get quotedAmountRupees {
    final paise = int.tryParse(quotedAmount ?? '');
    return paise == null ? null : paise / 100;
  }

  String get normalizedPaymentStatus {
    final value = (paymentStatus ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'pending';
    if (value == 'cash_on_delivery' || value == 'cod') return 'cod';
    if (value == 'success' || value == 'captured') return 'paid';
    return value;
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: (json['notes'] ?? json['access_notes'])?.toString(),
      cancellationReason:
          (json['cancellation_reason'] ?? json['cancellationReason'])
              ?.toString(),
      deliveryDate: DateTime.tryParse(
        (json['scheduled_for'] ?? json['delivery_date'] ?? '').toString(),
      ),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? '').toString(),
      ),
      serviceId: (json['service_code'] ?? json['service_id'] ?? '').toString(),
      quotedAmount: json['quoted_amount_paise']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      services: (json['service_details'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingServiceDetails.fromJson)
          .toList(),
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
    this.accuracy,
    this.vehicle,
    this.driver,
    this.recordedAt,
  });

  final String orderId;
  final String status;
  final bool trackingAvailable;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
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
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      vehicle: json['vehicle']?.toString(),
      driver: json['driver']?.toString(),
      recordedAt: DateTime.tryParse(
        (json['recorded_at'] ?? '').toString(),
      ),
    );
  }
}

class PublicTrackingSnapshot {
  const PublicTrackingSnapshot({
    required this.bookingReference,
    required this.status,
    required this.expectedDelivery,
    required this.vehicle,
    required this.driver,
    required this.lastLocation,
    required this.events,
    required this.trackingAvailable,
  });

  final String bookingReference;
  final String status;
  final DateTime? expectedDelivery;
  final String? vehicle;
  final String? driver;
  final TrackingLocation? lastLocation;
  final List<TrackingEvent> events;
  final bool trackingAvailable;

  factory PublicTrackingSnapshot.fromJson(Map<String, dynamic> json) =>
      PublicTrackingSnapshot(
        bookingReference: (json['bookingReference'] ?? '').toString(),
        status: (json['status'] ?? 'pending').toString(),
        expectedDelivery:
            DateTime.tryParse((json['expectedDelivery'] ?? '').toString()),
        vehicle: json['vehicle']?.toString(),
        driver: json['driver']?.toString(),
        lastLocation: json['lastLocation'] is Map
            ? TrackingLocation.fromJson(
                Map<String, dynamic>.from(json['lastLocation'] as Map),
              )
            : null,
        events: (json['events'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                TrackingEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        trackingAvailable: json['trackingAvailable'] == true,
      );
}

class TrackingLocation {
  const TrackingLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? recordedAt;

  factory TrackingLocation.fromJson(Map<String, dynamic> json) =>
      TrackingLocation(
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        recordedAt: DateTime.tryParse((json['recordedAt'] ?? '').toString()),
      );
}

class TrackingEvent {
  const TrackingEvent({
    required this.status,
    required this.note,
    required this.createdAt,
  });

  final String status;
  final String note;
  final DateTime? createdAt;

  factory TrackingEvent.fromJson(Map<String, dynamic> json) => TrackingEvent(
        status: (json['status'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      );
}
