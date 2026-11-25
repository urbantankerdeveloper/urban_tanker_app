import 'package:flutter_test/flutter_test.dart';

import 'package:urban_tanker_app/services/record_details.dart';

void main() {
  test('hides identifiers in record details by default', () {
    final details = formatRecordDetails({
      'id': 'vendor-123',
      'full_name': 'Asha Kumar',
      'vendorId': 'linked-vendor-456',
      'metadata': {
        'owner_profile_id': 'profile-789',
        'region': 'North',
      },
    });

    expect(details, contains('Name: Asha Kumar'));
    expect(details, contains('Region: North'));
    expect(details, isNot(contains('vendor-123')));
    expect(details, isNot(contains('linked-vendor-456')));
    expect(details, isNot(contains('profile-789')));
  });

  test('booking details can opt in to identifiers', () {
    final details = formatRecordDetails(
      {'id': 'booking-123', 'vendor_id': 'vendor-456'},
      includeIdentifiers: true,
    );

    expect(details, contains('Record ID: booking-123'));
    expect(details, contains('Vendor ID: vendor-456'));
  });
}
