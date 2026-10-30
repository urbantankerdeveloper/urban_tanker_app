import 'package:flutter_test/flutter_test.dart';

import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/home_shell.dart';

void main() {
  group('VendorOrder parity', () {
    test('maps a taken offer to unavailable and keeps the backend message', () {
      final order = VendorOrder.fromJson({
        'id': 'order-1',
        'status': 'Unavailable',
        'statusMessage': 'Already accepted by another vendor.',
      });

      expect(order.status, 'unavailable');
      expect(order.statusMessage, 'Already accepted by another vendor.');
    });

    test('normalizes assigned and available statuses from the backend', () {
      expect(
        VendorOrder.fromJson({'id': '1', 'status': 'Assigned'}).status,
        'vendor_assigned',
      );
      expect(
        VendorOrder.fromJson({'id': '1', 'status': 'Available'}).status,
        'pending_vendor',
      );
    });

    test('leaves statusMessage null when the backend omits it', () {
      final order = VendorOrder.fromJson({'id': '1', 'status': 'accepted'});

      expect(order.statusMessage, isNull);
    });
  });

  group('formatQuoteSummary', () {
    test('formats server quote paise values as rupees', () {
      final summary = formatQuoteSummary({
        'subtotalPaise': 100000,
        'discountPaise': 5000,
        'gstPaise': 4750,
        'totalPaise': 99750,
      });

      expect(summary, [
        'Subtotal: ₹1000.00',
        'Discount: ₹50.00',
        'GST: ₹47.50',
        'Total: ₹997.50',
      ].join('\n'));
    });

    test('reports unavailable when the quote is missing', () {
      expect(formatQuoteSummary(null), 'Quote unavailable.');
    });

    test('marks individual missing amounts as unavailable', () {
      expect(
        formatQuoteSummary({'totalPaise': 100}),
        contains('Total: ₹1.00'),
      );
      expect(
        formatQuoteSummary({'subtotalPaise': 100}),
        contains('Discount: Unavailable'),
      );
    });
  });
}
