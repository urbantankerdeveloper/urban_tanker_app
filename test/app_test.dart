import 'package:flutter_test/flutter_test.dart';

import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/models/notification.dart';

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
      'capacity_litres': 5000,
      'scheduled_for': '2026-10-22T09:00:00Z',
      'created_at': '2026-10-21T09:00:00Z',
    });

    expect(booking.reference, 'UT-1001');
    expect(booking.capacity, '5000');
    expect(booking.deliveryDate?.year, 2026);
    expect(booking.status, 'in_transit');
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
}
