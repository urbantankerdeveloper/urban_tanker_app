import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/core/design_system/theme.dart';
import 'package:urban_tanker_app/models/session.dart';
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
      WorkspaceRole role,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: RealtimeNoticeListener(
              events: events.stream,
              role: role,
              child: const SizedBox(),
            ),
          ),
        ),
      );
    }

    testWidgets('shows a new-order snackbar with the alert icon for vendors',
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
