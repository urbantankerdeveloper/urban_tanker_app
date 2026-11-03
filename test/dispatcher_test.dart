import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/dispatcher.dart';
import 'package:urban_tanker_app/screens/dispatcher/alerts_screen.dart';
import 'package:urban_tanker_app/screens/dispatcher/dispatch_urgency.dart';

DispatcherOrder _order(
  String id, {
  String status = 'pending_vendor',
  String? vendorId,
  DateTime? scheduledFor,
}) =>
    DispatcherOrder(
      id: id,
      reference: id,
      status: status,
      serviceCode: 'water_tanker',
      address: 'Chennai',
      amountPaise: 0,
      scheduledFor: scheduledFor,
      vendorId: vendorId,
    );

void main() {
  final now = DateTime(2026, 11, 3, 9);

  group('dispatchUrgency', () {
    test('an unassigned order due within two hours is urgent', () {
      final order = _order(
        'a',
        scheduledFor: now.add(const Duration(hours: 1)),
      );
      expect(dispatchUrgency(order, now: now), DispatchUrgency.urgent);
    });

    test('an unassigned order due later needs a vendor', () {
      final order = _order(
        'a',
        scheduledFor: now.add(const Duration(hours: 5)),
      );
      expect(dispatchUrgency(order, now: now), DispatchUrgency.needsVendor);
    });

    test('an unassigned order with no date needs a vendor', () {
      expect(
        dispatchUrgency(_order('a'), now: now),
        DispatchUrgency.needsVendor,
      );
    });

    test('an order on the road is in progress', () {
      final order = _order('a', status: 'en_route', vendorId: 'v1');
      expect(dispatchUrgency(order, now: now), DispatchUrgency.inProgress);
    });

    test('delivered and cancelled orders are done', () {
      expect(
        dispatchUrgency(_order('a', status: 'delivered'), now: now),
        DispatchUrgency.done,
      );
      expect(
        dispatchUrgency(_order('a', status: 'cancelled'), now: now),
        DispatchUrgency.done,
      );
    });
  });

  test('sortByPriority puts urgent work first, then the soonest', () {
    final urgent = _order(
      'urgent',
      scheduledFor: now.add(const Duration(minutes: 30)),
    );
    final later = _order(
      'later',
      scheduledFor: now.add(const Duration(hours: 9)),
    );
    final moving = _order('moving', status: 'en_route', vendorId: 'v1');
    final sorted = sortByPriority([moving, later, urgent], now: now);
    expect(sorted.map((order) => order.id), ['urgent', 'later', 'moving']);
  });

  group('alertSeverity', () {
    AccountRecord alert(Map<String, dynamic> data) => AccountRecord({
          'id': 'x',
          'status': 'open',
          ...data,
        });

    test('an explicit severity wins', () {
      expect(alertSeverity(alert({'severity': 'high'})), AlertSeverity.danger);
      expect(
        alertSeverity(alert({'severity': 'medium'})),
        AlertSeverity.warning,
      );
      expect(alertSeverity(alert({'severity': 'low'})), AlertSeverity.info);
    });

    test('a delivery exception is danger', () {
      expect(
        alertSeverity(alert({'type': 'delivery_exception'})),
        AlertSeverity.danger,
      );
    });

    test('unassigned work is a warning', () {
      expect(
        alertSeverity(alert({'type': 'unassigned'})),
        AlertSeverity.warning,
      );
    });

    test('anything else is info', () {
      expect(alertSeverity(alert({})), AlertSeverity.info);
    });
  });
}
