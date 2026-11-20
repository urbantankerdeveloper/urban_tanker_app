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
    this.orderItems = const [],
    this.fulfilments = const [],
    this.serviceId,
    this.quotedAmount,
    this.paymentStatus,
    this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
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
  final String? paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final List<BookingServiceDetails> services;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? cancellationReason;
  final List<BookingOrderItem> orderItems;
  final List<BookingFulfilment> fulfilments;

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
    final customer = json['customer'];
    final orderItems = _records(
      json['items'] ?? json['order_items'],
      BookingOrderItem.fromJson,
    );
    final services = _records(
      json['service_details'] ?? json['services'],
      BookingServiceDetails.fromJson,
    );
    if (services.isEmpty) {
      services.addAll(orderItems.map((item) => item.details));
    }
    final rawFulfilments = json['fulfilments'] ?? json['fulfillments'];
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
      orderItems: orderItems,
      fulfilments: _records(rawFulfilments, BookingFulfilment.fromJson),
      deliveryDate: DateTime.tryParse(
        (json['scheduled_for'] ?? json['delivery_date'] ?? '').toString(),
      ),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? '').toString(),
      ),
      serviceId: (json['service_code'] ?? json['service_id'] ?? '').toString(),
      quotedAmount: (json['total_paise'] ??
              json['totalPaise'] ??
              json['quoted_amount_paise'])
          ?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod:
          (json['payment_method'] ?? json['paymentMethod'])?.toString(),
      customerName: (json['customer_name'] ??
              json['customerName'] ??
              (customer is Map ? customer['name'] : null))
          ?.toString(),
      customerPhone: (json['customer_phone_e164'] ??
              json['customer_phone'] ??
              json['customerPhone'] ??
              json['phone'])
          ?.toString(),
      customerEmail:
          (json['customer_email'] ?? json['customerEmail'] ?? json['email'])
              ?.toString(),
      services: services,
    );
  }
}

class BookingOrderItem {
  const BookingOrderItem({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.status,
    required this.details,
    required this.amountPaise,
    this.location,
    this.scheduledFor,
    this.fulfilmentId,
  });

  final String id;
  final String serviceId;
  final String serviceName;
  final String status;
  final BookingServiceDetails details;
  final int amountPaise;
  final String? location;
  final DateTime? scheduledFor;
  final String? fulfilmentId;

  factory BookingOrderItem.fromJson(Map<String, dynamic> json) {
    final rawDetails =
        json['service_details'] ?? json['serviceDetails'] ?? json['details'];
    final detailsMap =
        rawDetails is Map<String, dynamic> ? rawDetails : <String, dynamic>{};
    final serviceId = (json['service_type_id'] ??
            json['serviceTypeId'] ??
            json['service_id'] ??
            json['serviceId'] ??
            detailsMap['serviceId'] ??
            '')
        .toString();
    final serviceType = json['service_type'];
    final serviceName = json['service_type_name'] ??
        json['serviceName'] ??
        (serviceType is Map ? serviceType['name'] : null);
    final location = (json['address_text'] ?? json['location'])?.toString();
    final scheduledFor = json['scheduled_for'] ??
        json['scheduledFor'] ??
        detailsMap['deliveryDate'];
    return BookingOrderItem(
      id: (json['id'] ?? json['item_id'] ?? serviceId).toString(),
      serviceId: serviceId,
      serviceName: (serviceName ?? serviceId).toString(),
      status: (json['status'] ?? 'pending').toString(),
      details: BookingServiceDetails.fromJson({
        ...detailsMap,
        'serviceId': serviceId,
        if (json['capacity'] != null) 'capacity': json['capacity'],
        if (json['quantity'] != null) 'quantity': json['quantity'],
        if (json['details'] is String) 'details': json['details'],
        if (location != null) 'location': location,
        if (scheduledFor != null) 'deliveryDate': scheduledFor,
        if (json['latitude'] != null) 'latitude': json['latitude'],
        if (json['longitude'] != null) 'longitude': json['longitude'],
      }),
      amountPaise: ((json['price_paise'] ??
                  json['amount_paise'] ??
                  json['quoted_amount_paise'] ??
                  json['quotedAmountPaise']) as num?)
              ?.toInt() ??
          0,
      location: location,
      scheduledFor: DateTime.tryParse((scheduledFor ?? '').toString()),
      fulfilmentId: (json['fulfilment_id'] ?? json['fulfilmentId'])?.toString(),
    );
  }
}

class BookingFulfilment {
  const BookingFulfilment({
    required this.id,
    required this.status,
    required this.itemIds,
    required this.amountPaise,
    this.location,
    this.scheduledFor,
    this.vendorName,
  });

  final String id;
  final String status;
  final List<String> itemIds;
  final int amountPaise;
  final String? location;
  final DateTime? scheduledFor;
  final String? vendorName;

  factory BookingFulfilment.fromJson(Map<String, dynamic> json) {
    final rawItems = json['item_ids'] ?? json['itemIds'] ?? json['items'];
    final itemIds = rawItems is List
        ? rawItems
            .map((item) => item is Map ? item['id'] : item)
            .whereType<String>()
            .toList()
        : const <String>[];
    final scheduledFor = json['scheduled_for'] ?? json['scheduledFor'];
    return BookingFulfilment(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'pending_vendor').toString(),
      itemIds: itemIds,
      amountPaise: ((json['amount_paise'] ??
                  json['amountPaise'] ??
                  json['quoted_amount_paise']) as num?)
              ?.toInt() ??
          0,
      location: (json['address_text'] ?? json['location'])?.toString(),
      scheduledFor: DateTime.tryParse((scheduledFor ?? '').toString()),
      vendorName: (json['vendor_name'] ?? json['vendorName'])?.toString(),
    );
  }
}

List<T> _records<T>(
  Object? value,
  T Function(Map<String, dynamic>) parse,
) =>
    value is List
        ? value.whereType<Map<String, dynamic>>().map(parse).toList()
        : <T>[];

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
