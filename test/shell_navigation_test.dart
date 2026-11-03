import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/models/notification.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/workspace_navigation.dart';
import 'package:urban_tanker_app/screens/home/shell/menu_screen.dart';
import 'package:urban_tanker_app/screens/home/shell/notification_routing.dart';
import 'package:urban_tanker_app/screens/home/shell/role_tabs.dart';

NotificationItem _item({String? bookingId, String? invoiceId}) =>
    NotificationItem(
      id: 'n-1',
      title: 'Update',
      message: '',
      createdAt: null,
      read: false,
      payload: {
        if (bookingId != null) 'bookingId': bookingId,
        if (invoiceId != null) 'invoiceId': invoiceId,
      },
    );

void main() {
  group('tabs', () {
    test('customer has three tabs and no Menu', () {
      final tabs = tabsForRole(WorkspaceRole.customer);
      expect(tabs.map((tab) => tab.label), ['Home', 'Bookings', 'Account']);
    });

    test('vendor, dispatcher and admin end with Menu', () {
      for (final role in [
        WorkspaceRole.vendor,
        WorkspaceRole.dispatcher,
        WorkspaceRole.admin,
      ]) {
        final tabs = tabsForRole(role);
        expect(tabs, hasLength(4), reason: role.name);
        expect(tabs.last.page, ShellPage.menu, reason: role.name);
        expect(tabs.last.label, 'Menu', reason: role.name);
      }
    });

    test('every menu destination points at a real, non-Menu tab', () {
      for (final role in WorkspaceRole.values) {
        final tabs = tabsForRole(role);
        for (final group in workspaceNavigationForRole(role)) {
          for (final destination in group.destinations) {
            expect(
              destination.index,
              inInclusiveRange(0, tabs.length - 2),
              reason: '${role.name}: ${destination.label}',
            );
          }
        }
      }
    });

    test('admin destinations map to the matching operations section', () {
      final sections = {
        for (final group in workspaceNavigationForRole(WorkspaceRole.admin))
          for (final destination in group.destinations)
            destination.label: destination.operationsSection,
      };
      expect(sections['Orders'], OperationsSection.orders);
      expect(sections['Vendors, customers & fleet'], OperationsSection.people);
      expect(
        sections['Coupons, payouts & partners'],
        OperationsSection.finance,
      );
      expect(
        sections['Services, notifications & audit'],
        OperationsSection.setup,
      );
      expect(sections['Reports'], isNull);
    });
  });

  group('notification routing', () {
    test('vendor: booking goes to Operations, anything else to Earnings', () {
      expect(
        notificationTabIndex(WorkspaceRole.vendor, _item(bookingId: 'b')),
        0,
      );
      expect(notificationTabIndex(WorkspaceRole.vendor, _item()), 2);
    });

    test('dispatcher: booking goes to Live, anything else to Alerts', () {
      expect(
        notificationTabIndex(WorkspaceRole.dispatcher, _item(bookingId: 'b')),
        1,
      );
      expect(notificationTabIndex(WorkspaceRole.dispatcher, _item()), 2);
    });

    test('admin: booking goes to Operations, anything else to Reports', () {
      expect(
        notificationTabIndex(WorkspaceRole.admin, _item(bookingId: 'b')),
        1,
      );
      expect(notificationTabIndex(WorkspaceRole.admin, _item()), 2);
    });

    test('customer: booking goes to Bookings, anything else to Account', () {
      expect(
        notificationTabIndex(WorkspaceRole.customer, _item(bookingId: 'b')),
        1,
      );
      expect(notificationTabIndex(WorkspaceRole.customer, _item()), 2);
    });

    test('an invoice counts as a target', () {
      expect(hasNotificationTarget(_item(invoiceId: 'i')), isTrue);
      expect(hasNotificationTarget(_item()), isFalse);
    });
  });

  test('maskUsername keeps the first one or two characters only', () {
    expect(maskUsername('mahesh'), 'ma••••');
    expect(maskUsername('ab'), 'a••••');
    expect(maskUsername(''), '');
  });
}
