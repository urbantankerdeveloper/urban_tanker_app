import 'package:flutter_test/flutter_test.dart';

import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/models/account.dart';

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
}
