import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../models/notification.dart';
import '../../../models/session.dart';
import '../../../services/friendly_error.dart';
import '../../booking_details_screen.dart';
import '../../invoice_detail_screen.dart';
import '../../support_request_detail_screen.dart';
import 'role_tabs.dart';

/// Whether a notification names a booking, invoice or support request.
bool hasNotificationTarget(NotificationItem item) =>
    item.bookingId != null ||
    item.invoiceId != null ||
    item.supportRequestId != null;

/// Pages a notification opens for [role]: the booking page when the
/// notification names a booking, otherwise the second page.
(ShellPage booking, ShellPage other) _notificationPages(WorkspaceRole role) =>
    switch (role) {
      WorkspaceRole.vendor => (
          ShellPage.vendorOperations,
          ShellPage.vendorEarnings
        ),
      WorkspaceRole.dispatcher => (
          ShellPage.dispatchLive,
          ShellPage.dispatchAlerts
        ),
      WorkspaceRole.admin => (
          ShellPage.adminOperations,
          ShellPage.adminReports
        ),
      WorkspaceRole.customer => (ShellPage.bookings, ShellPage.account),
    };

/// Tab index a notification switches to. Looked up by page, so it stays
/// correct when tabs are reordered. Menu is never a target.
int notificationTabIndex(WorkspaceRole role, NotificationItem item) {
  final pages = _notificationPages(role);
  final page = item.bookingId != null ? pages.$1 : pages.$2;
  return tabsForRole(role).indexWhere((tab) => tab.page == page);
}

/// Opens the detail page for a customer notification. Other roles only see a
/// confirmation, as before; their tab switch happens in the shell.
Future<void> openNotificationTarget(
  BuildContext context,
  AppController controller,
  WorkspaceRole role,
  NotificationItem item,
) async {
  if (role != WorkspaceRole.customer) {
    final target = item.bookingId != null ? 'Operations' : 'this section';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$target selected.')),
    );
    return;
  }
  try {
    final Widget page;
    if (item.bookingId != null) {
      final bookings = await controller.api.bookings();
      final matches = bookings.where((booking) => booking.id == item.bookingId);
      if (matches.isEmpty) {
        throw StateError('This booking is no longer available.');
      }
      page = BookingDetailsScreen(booking: matches.first);
    } else if (item.invoiceId != null) {
      page = InvoiceDetailScreen(invoiceId: item.invoiceId!);
    } else if (item.supportRequestId != null) {
      page = SupportRequestDetailScreen(requestId: item.supportRequestId!);
    } else {
      throw StateError('This notification has no valid destination.');
    }
    if (!context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }
}
