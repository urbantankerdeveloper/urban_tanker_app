import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/models/notification.dart';
import 'package:urban_tanker_app/models/dispatcher.dart';
import 'package:urban_tanker_app/models/booking_service_details.dart';
import 'package:urban_tanker_app/models/booking_service_form.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://example.test/api');

  Map<String, dynamic>? requestBody;
  String? requestPath;

  @override
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    requestPath = path;
    requestBody = body;
    return http.Response(jsonEncode({'id': 'booking-1'}), 200);
  }
}

void main() {
  test('unknown server roles fail closed to customer', () {
    expect(roleFromString('root'), WorkspaceRole.customer);
    expect(roleFromString('dispatcher'), WorkspaceRole.dispatcher);
  });

  test('authentication responses retain native refresh tokens', () {
    final result = AuthResult.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'user': {
        'id': 'user-1',
        'name': 'Customer',
        'username': 'customer',
        'role': 'customer',
      },
    });

    expect(result.refreshToken, 'refresh-token');
  });

  test('booking responses map server delivery fields', () {
    final booking = Booking.fromJson({
      'id': 'booking-1',
      'reference': 'UT-1001',
      'status': 'in_transit',
      'location': '12 Main Street',
      'service_code': 'water_tanker',
      'capacity_litres': 5000,
      'scheduled_for': '2026-10-22T09:00:00Z',
      'created_at': '2026-10-21T09:00:00Z',
    });

    expect(booking.reference, 'UT-1001');
    expect(booking.capacity, '5000');
    expect(booking.serviceId, 'water_tanker');
    expect(booking.deliveryDate?.year, 2026);
    expect(booking.status, 'in_transit');
  });

  test('tracking responses map vendor location and accuracy', () {
    final tracking = TrackingSnapshot.fromJson({
      'orderId': 'booking-1',
      'status': 'en_route',
      'trackingAvailable': true,
      'latitude': 12.9716,
      'longitude': 77.5946,
      'accuracy': 8.5,
      'recorded_at': '2026-10-24T08:00:00Z',
    });

    expect(tracking.trackingAvailable, isTrue);
    expect(tracking.latitude, 12.9716);
    expect(tracking.longitude, 77.5946);
    expect(tracking.accuracy, 8.5);
  });

  test('booking payment fields expose customer checkout details', () {
    final booking = Booking.fromJson({
      'id': 'booking-2',
      'reference': 'UT-1002',
      'status': 'pending',
      'address_text': '12 Main Street',
      'quoted_amount_paise': 125000,
      'payment_status': 'pending',
    });

    expect(booking.quotedAmountRupees, 1250);
    expect(booking.paymentStatus, 'pending');
    expect(booking.normalizedPaymentStatus, 'pending');
  });

  test('booking payment status normalizes COD and captured values', () {
    expect(
      Booking.fromJson({'id': '1', 'payment_status': 'cod'})
          .normalizedPaymentStatus,
      'cod',
    );
    expect(
      Booking.fromJson({'id': '2', 'payment_status': 'captured'})
          .normalizedPaymentStatus,
      'paid',
    );
  });

  test('booking service details keep each quantity and answer isolated', () {
    const water = BookingServiceDetails(
      serviceId: 'water_tanker',
      quantity: '5000 litres',
      details: 'Potable water for the overhead tank',
    );
    const cleaning = BookingServiceDetails(
      serviceId: 'tank_cleaning',
      quantity: '2 tanks',
      details: 'Clean both rooftop tanks',
    );

    expect(water.toJson(), {
      'serviceId': 'water_tanker',
      'capacity': '5000 litres',
      'details': 'Potable water for the overhead tank',
    });
    expect(cleaning.toJson(), {
      'serviceId': 'tank_cleaning',
      'capacity': '2 tanks',
      'details': 'Clean both rooftop tanks',
    });
    expect(
      BookingServiceForm.forService('water_tanker').detailsLabel,
      isNot(BookingServiceForm.forService('tank_cleaning').detailsLabel),
    );
    expect(
      BookingServiceForm.forService('tank_cleaning').serviceName,
      'Tank cleaning',
    );
  });

  test('combined booking request submits all per-service details', () {
    final body = buildBookingRequestBody(
      serviceId: 'water_tanker',
      capacity: '5000 litres',
      location: '12 Main Street',
      deliveryDate: '2026-10-25',
      services: const [
        BookingServiceDetails(
          serviceId: 'water_tanker',
          quantity: '5000 litres',
          details: 'Potable water',
        ),
        BookingServiceDetails(
          serviceId: 'tank_cleaning',
          quantity: '2 tanks',
          details: 'Rooftop tanks',
        ),
      ],
      couponCode: 'save10',
    );

    expect(body['serviceId'], 'water_tanker');
    expect(body['capacity'], '5000 litres');
    expect(body['couponCode'], 'SAVE10');
    expect(body['services'], [
      {
        'serviceId': 'water_tanker',
        'capacity': '5000 litres',
        'details': 'Potable water',
      },
      {
        'serviceId': 'tank_cleaning',
        'capacity': '2 tanks',
        'details': 'Rooftop tanks',
      },
    ]);
  });

  test('booking submission sends combined services to the quote endpoint',
      () async {
    final api = _RecordingApiClient();

    await api.createBooking(
      serviceId: 'water_tanker',
      capacity: '5000',
      location: '12 Main Street',
      deliveryDate: '2026-10-25',
      services: const [
        BookingServiceDetails(
          serviceId: 'water_tanker',
          quantity: '5000',
          details: 'Potable water',
        ),
        BookingServiceDetails(
          serviceId: 'tank_cleaning',
          quantity: '2 tanks',
          details: 'Rooftop tanks',
        ),
      ],
    );

    expect(api.requestPath, '/customer/orders/quote');
    expect(api.requestBody?['services'], hasLength(2));
    expect(
      (api.requestBody?['services'] as List<Map<String, String>>)
          .last['details'],
      'Rooftop tanks',
    );
  });

  test('single-service booking retains legacy fields and structured detail',
      () {
    final body = buildBookingRequestBody(
      serviceId: 'water_tanker',
      capacity: '5000',
      location: '12 Main Street',
      deliveryDate: '2026-10-25',
      services: const [
        BookingServiceDetails(
          serviceId: 'water_tanker',
          quantity: '5000',
          details: 'Potable water',
        ),
      ],
    );

    expect(body['serviceId'], 'water_tanker');
    expect(body['services'], hasLength(1));
    expect(
      (body['services'] as List<Map<String, String>>).single['details'],
      'Potable water',
    );
  });

  test('booking response retains structured per-service details', () {
    final booking = Booking.fromJson({
      'id': 'booking-3',
      'reference': 'UT-1003',
      'service_details': [
        {
          'serviceId': 'water_tanker',
          'capacity': '5000 litres',
          'details': 'Potable water',
        },
        {
          'serviceId': 'tank_cleaning',
          'capacity': '2 tanks',
          'details': 'Rooftop tanks',
        },
      ],
    });

    expect(booking.services, hasLength(2));
    expect(booking.services.last.quantity, '2 tanks');
    expect(booking.services.last.details, 'Rooftop tanks');
  });

  test('customer profile supports backend profile field names', () {
    final profile = CustomerProfile.fromJson({
      'full_name': 'Asha Customer',
      'email': 'asha@example.com',
      'phone_e164': '+919876543210',
    });

    expect(profile.name, 'Asha Customer');
    expect(profile.email, 'asha@example.com');
    expect(profile.phone, '+919876543210');
  });

  test('account records expose useful fallback labels', () {
    final record = AccountRecord({
      'subject': 'Delivery issue',
      'message': 'Please call me back',
      'status': 'open',
    });

    expect(record.title, 'Delivery issue');
    expect(record.detail, 'Please call me back');
    expect(record.status, 'open');
  });

  test('account record exposes identifiers for scoped mutations', () {
    final record = AccountRecord({
      'id': 'address-1',
      'label': 'Home',
      'address': '12 Main Street',
    });

    expect(record.id, 'address-1');
    expect(record.title, 'Home');
    expect(record.detail, '12 Main Street');
  });

  test('support records expose booking and response timeline data', () {
    final record = AccountRecord({
      'id': 'support-1',
      'subject': 'Delivery issue',
      'bookingId': 'booking-1',
      'timeline': [
        {'type': 'customer', 'message': 'Help'},
        {'type': 'support', 'message': 'We are checking'},
      ],
    });

    expect(record.bookingId, 'booking-1');
    expect(record.timeline, hasLength(2));
  });

  test('notification IDs ignore missing and blank payload values', () {
    final item = NotificationItem.fromJson({
      'id': 'notification-1',
      'payload': {'bookingId': '  ', 'invoiceId': 'invoice-1'},
    });

    expect(item.bookingId, isNull);
    expect(item.invoiceId, 'invoice-1');
  });

  test('offer records expose discount and expiry details', () {
    final offer = AccountRecord({
      'code': 'SAVE10',
      'title': 'New customer offer',
      'discount_type': 'percentage',
      'discount_value': 10,
      'valid_until': '2026-12-31T00:00:00Z',
    });

    expect(offer.title, 'New customer offer');
    expect(offer.offerDetail, contains('10% off'));
    expect(offer.offerDetail, contains('Valid until'));
  });

  test('usage response maps customer summary values', () {
    final usage = CustomerUsage.fromJson({
      'deliveries': 3,
      'totalSpend': 4200.5,
      'averageAmount': 1400,
    });

    expect(usage.deliveries, 3);
    expect(usage.totalSpend, 4200.5);
    expect(usage.averageAmount, 1400);
  });

  test('booking status actions parse server booking responses', () {
    final booking = Booking.fromJson({
      'id': 'booking-1',
      'reference': 'UT-1001',
      'status': 'cancelled',
      'address_text': '12 Main Street',
    });

    expect(booking.id, 'booking-1');
    expect(booking.status, 'cancelled');
  });

  test('vendor records enforce approved active assignment rules', () {
    final vehicle = VendorVehicle.fromJson({
      'id': 'vehicle-1',
      'registration_number': 'KA01AB1234',
      'capacity_litres': 10000,
      'is_active': true,
      'verification': 'approved',
    });
    final driver = VendorDriver.fromJson({
      'id': 'driver-1',
      'name': 'Driver One',
      'mobile_e164': '+919876543210',
      'is_active': true,
      'verification': 'pending',
    });

    expect(vehicle.assignable, isTrue);
    expect(driver.assignable, isFalse);
  });

  test('vendor dashboard maps orders, fleet, and drivers', () {
    final dashboard = VendorDashboard.fromJson({
      'orders': [
        {
          'id': 'order-1',
          'reference': 'UT-2001',
          'address_text': 'Main Street',
          'quoted_amount_paise': 250000,
        },
      ],
      'vehicles': [],
      'drivers': [],
    });

    expect(dashboard.orders.single.reference, 'UT-2001');
    expect(dashboard.orders.single.amountRupees, 2500);
  });

  test('vendor orders map normalized API fields and service details', () {
    final order = VendorOrder.fromJson({
      'id': 'order-2',
      'reference': 'UT-2002',
      'service': 'Water tanker, Tank cleaning',
      'serviceDetails': [
        {
          'service': 'Water tanker',
          'capacity': '5000 litres',
          'details': 'Potable water',
        },
        {
          'service': 'Tank cleaning',
          'capacity': '2 tanks',
          'details': 'Rooftop tanks',
        },
      ],
      'location': 'Main Street',
      'amount': '₹2,500',
      'status': 'Available',
      'vehicle': 'KA01AB1234',
      'driver': 'Driver One',
      'createdAt': '2026-10-24T08:00:00Z',
      'scheduledFor': '2026-10-25T09:00:00Z',
    });

    expect(order.status, 'pending_vendor');
    expect(order.serviceCode, 'Water tanker, Tank cleaning');
    expect(order.amountPaise, 250000);
    expect(order.address, 'Main Street');
    expect(order.vehicle, 'KA01AB1234');
    expect(order.driver, 'Driver One');
    expect(order.serviceDetails, hasLength(2));
    expect(order.serviceDetails.last.details, 'Rooftop tanks');
    expect(order.scheduledFor?.day, 25);
  });

  test('vendor order statuses normalize before workflow checks', () {
    expect(
      VendorOrder.fromJson({'status': 'Assigned'}).status,
      'vendor_assigned',
    );
    expect(
      VendorOrder.fromJson({'status': 'En route'}).status,
      'en_route',
    );
    expect(
      VendorOrder.fromJson({'status': 'Rejected'}).status,
      'cancelled',
    );
  });

  test('vendor services map current availability state', () {
    final service = VendorService.fromJson({
      'code': 'water_delivery',
      'name': 'Water delivery',
      'description': 'Scheduled tanker delivery',
      'vendor_enabled': false,
    });

    expect(service.code, 'water_delivery');
    expect(service.enabled, isFalse);
  });

  test('offline mutations retain entity identifiers', () {
    final mutation = VendorOfflineMutation.fromJson({
      'id': 'mutation-1',
      'mutation_type': 'status',
      'entity_type': 'booking',
      'entity_id': 'booking-1',
      'conflict_status': 'queued',
      'payload': {'status': 'en_route'},
    });

    expect(mutation.entityId, 'booking-1');
    expect(mutation.status, 'queued');
  });

  test('dispatcher models map assignment and alert fields', () {
    final order = DispatcherOrder.fromJson({
      'id': 'order-1',
      'reference': 'UT-3001',
      'status': 'vendor_assigned',
      'service_code': 'water_delivery',
      'address_text': 'Main Street',
      'quoted_amount_paise': 180000,
      'vendor_id': 'vendor-1',
      'latitude': 12.97,
      'longitude': 77.59,
    });
    final alert = DispatcherAlert.fromJson({
      'id': 'order-1',
      'reference': 'UT-3001',
      'status': 'pending_vendor',
      'alertType': 'unassigned',
    });

    expect(order.isAssigned, isTrue);
    expect(order.amountRupees, 1800);
    expect(order.latitude, 12.97);
    expect(order.allowedNextStatuses, contains('accepted'));
    expect(order.allowedNextStatuses, isNot(contains('delivered')));
    expect(alert.reference, 'UT-3001');
  });
}
