import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/theme.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/home/shell/realtime_notice_listener.dart';
import 'package:urban_tanker_app/services/realtime_notice.dart';
import 'package:urban_tanker_app/services/realtime_service.dart';

void main() {
  group('realtimeNoticeFor', () {
    test('customer accepted notice shares a key with booking.updated accepted',
        () {
      final fromAccepted = realtimeNoticeFor(
        WorkspaceRole.customer,
        const RealtimeEvent('booking.vendor_accepted', {
          'bookingId': 'b1',
          'vendorId': 'v1',
          'reference': 'UT-1',
        }),
      );
      final fromUpdated = realtimeNoticeFor(
        WorkspaceRole.customer,
        const RealtimeEvent('booking.updated', {
          'bookingId': 'b1',
          'status': 'accepted',
        }),
      );
      expect(fromAccepted, isNotNull);
      expect(fromUpdated?.key, fromAccepted?.key);
      expect(fromUpdated?.message, 'Your vendor accepted the booking.');
    });

    test('vendor gets a new-order notice; customer does not', () {
      const event = RealtimeEvent('vendor.order.created', {
        'bookingId': 'b2',
        'reference': 'UT-2',
      });
      final vendorNotice = realtimeNoticeFor(WorkspaceRole.vendor, event);
      expect(vendorNotice?.isNewOrder, isTrue);
      expect(vendorNotice?.message, contains('UT-2'));
      expect(realtimeNoticeFor(WorkspaceRole.customer, event), isNull);
    });

    test('ignores booking.updated for vendors and unknown statuses', () {
      expect(
        realtimeNoticeFor(
          WorkspaceRole.vendor,
          const RealtimeEvent('booking.updated', {
            'bookingId': 'b3',
            'status': 'accepted',
          }),
        ),
        isNull,
      );
      expect(
        realtimeNoticeFor(
          WorkspaceRole.customer,
          const RealtimeEvent('booking.updated', {
            'bookingId': 'b3',
            'status': 'pending_vendor',
          }),
        ),
        isNull,
      );
    });
  });

  group('RealtimeNoticeListener', () {
    late StreamController<RealtimeEvent> events;

    setUp(() {
      events = StreamController<RealtimeEvent>.broadcast();
    });

    tearDown(() async {
      await events.close();
    });

    Future<void> pumpListener(
      WidgetTester tester,
      WorkspaceRole role, {
      List<VendorOrder> orders = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorOrdersProvider.overrideWith((ref) async => orders),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: RealtimeNoticeListener(
                events: events.stream,
                role: role,
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
    }

    VendorOrder order(String id) => VendorOrder(
          id: id,
          reference: 'UT-$id',
          serviceCode: '',
          address: '',
          status: 'pending_vendor',
          amountPaise: 0,
          createdAt: null,
          scheduledFor: null,
        );

    testWidgets('new-order offer stays open with Accept and Reject for vendors',
        (tester) async {
      await pumpListener(tester, WorkspaceRole.vendor);

      events.add(
        const RealtimeEvent('vendor.order.created', {
          'bookingId': 'b4',
          'reference': 'UT-4',
        }),
      );
      await tester.pump();

      expect(find.textContaining('New order UT-4'), findsOneWidget);
      expect(
        find.byIcon(Icons.notifications_active_outlined),
        findsOneWidget,
      );
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final accept = tester.getCenter(find.text('Accept'));
      expect(accept.dx, greaterThan(size.width / 2));
      expect(accept.dy, greaterThan(size.height / 2));

      await tester.pump(const Duration(seconds: 10));
      expect(find.textContaining('New order UT-4'), findsOneWidget);
    });

    testWidgets('notices appear in the top-right corner', (tester) async {
      await pumpListener(tester, WorkspaceRole.customer);

      events.add(
        const RealtimeEvent('booking.delivered', {
          'bookingId': 'b8',
          'reference': 'UT-8',
        }),
      );
      await tester.pump();

      final message = find.text('Your delivery is complete.');
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getTopRight(message).dx, greaterThan(size.width / 2));
      expect(tester.getTopRight(message).dy, lessThan(size.height / 4));

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Accept opens the order sheet for the offered order',
        (tester) async {
      await pumpListener(
        tester,
        WorkspaceRole.vendor,
        orders: [order('b9')],
      );

      events.add(
        const RealtimeEvent('vendor.order.created', {
          'bookingId': 'b9',
          'reference': 'UT-b9',
        }),
      );
      await tester.pump();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Assign vehicle and driver'), findsOneWidget);
    });

    testWidgets('Reject opens the reason prompt for the offered order',
        (tester) async {
      await pumpListener(
        tester,
        WorkspaceRole.vendor,
        orders: [order('b10')],
      );

      events.add(
        const RealtimeEvent('vendor.order.created', {
          'bookingId': 'b10',
          'reference': 'UT-b10',
        }),
      );
      await tester.pump();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reason'), findsOneWidget);
    });

    testWidgets('taken closes the open offer for the same booking',
        (tester) async {
      await pumpListener(tester, WorkspaceRole.vendor);

      events
        ..add(
          const RealtimeEvent('vendor.order.created', {
            'bookingId': 'b11',
            'reference': 'UT-11',
          }),
        )
        ..add(
          const RealtimeEvent('vendor.order.taken', {
            'bookingId': 'b11',
            'reference': 'UT-11',
          }),
        );
      await tester.pump();

      expect(find.textContaining('New order UT-11'), findsNothing);
      expect(find.text('Accept'), findsNothing);
      expect(
        find.text('Order UT-11 was accepted by another vendor.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
    });
    testWidgets('shows one notice when accepted arrives twice', (tester) async {
      await pumpListener(tester, WorkspaceRole.customer);

      events
        ..add(
          const RealtimeEvent('booking.vendor_accepted', {
            'bookingId': 'b5',
            'vendorId': 'v5',
            'reference': 'UT-5',
          }),
        )
        ..add(
          const RealtimeEvent('booking.updated', {
            'bookingId': 'b5',
            'status': 'accepted',
          }),
        );
      await tester.pump();

      expect(find.text('Your vendor accepted the booking.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('does not show vendor order notices to customers',
        (tester) async {
      await pumpListener(tester, WorkspaceRole.customer);

      events.add(
        const RealtimeEvent('vendor.order.created', {
          'bookingId': 'b6',
          'reference': 'UT-6',
        }),
      );
      await tester.pump();

      expect(find.textContaining('New order'), findsNothing);
    });
  });
}
