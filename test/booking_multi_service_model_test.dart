import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/models/service.dart';

void main() {
  test('parses parent order items, fulfilments, and total amount', () {
    final booking = Booking.fromJson({
      'id': 'order-1',
      'reference': 'UT-ORDER-1',
      'status': 'partially_accepted',
      'total_paise': 8500,
      'items': [
        {
          'id': 'item-1',
          'service_type_id': 'water_tanker',
          'service_type': {'name': 'Water delivery'},
          'status': 'accepted',
          'price_paise': 5000,
          'service_details': {
            'serviceId': 'water_tanker',
            'capacity': '5 KL',
          },
        },
      ],
      'fulfilments': [
        {
          'id': 'fulfilment-1',
          'status': 'accepted',
          'item_ids': ['item-1'],
          'amount_paise': 5000,
          'vendor_name': 'Vendor One',
        },
      ],
    });

    expect(booking.quotedAmountRupees, 85);
    expect(booking.orderItems, hasLength(1));
    expect(booking.orderItems.single.serviceName, 'Water delivery');
    expect(booking.orderItems.single.details.quantity, '5 KL');
    expect(booking.fulfilments.single.itemIds, ['item-1']);
    expect(booking.fulfilments.single.vendorName, 'Vendor One');
  });

  test('continues to parse legacy booking service details', () {
    final booking = Booking.fromJson({
      'id': 'booking-1',
      'status': 'pending_vendor',
      'service_details': [
        {'serviceId': 'water_tanker', 'capacity': '5 KL'},
      ],
    });

    expect(booking.orderItems, isEmpty);
    expect(booking.services.single.serviceId, 'water_tanker');
    expect(booking.services.single.quantity, '5 KL');
  });

  test('reads quantity constraints for dynamically added services', () {
    final service = TankerService.fromJson({
      'code': 'waste_collection',
      'name': 'Waste collection',
      'min_quantity': 2,
      'max_quantity': 12,
      'unit': 'cubic metres',
    });

    expect(service.id, 'waste_collection');
    expect(service.minQuantity, 2);
    expect(service.maxQuantity, 12);
    expect(service.unit, 'cubic metres');
  });
}
