import '../../models/booking.dart';

const _finishedStatuses = {
  'delivered',
  'completed',
  'cancelled',
  'canceled',
  'rejected',
};

/// A booking that still needs attention: anything that has not finished.
bool isActiveBooking(Booking booking) =>
    !_finishedStatuses.contains(booking.status.toLowerCase());

/// Steps shown on the progress timeline, in order.
const bookingProgressSteps = [
  'Requested',
  'Vendor assigned',
  'On the way',
  'Delivered',
];

/// Index into [bookingProgressSteps] for [status]. Null when the status is
/// off the delivery path (cancelled or rejected). Unknown statuses count as
/// requested.
int? bookingProgressIndex(String status) => switch (status.toLowerCase()) {
      'accepted' || 'vendor_accepted' || 'assigned' || 'vendor_assigned' => 1,
      'in_transit' || 'on_the_way' || 'arrived' => 2,
      'delivered' || 'completed' => 3,
      'cancelled' || 'canceled' || 'rejected' => null,
      _ => 0,
    };

/// Date as dd/mm/yyyy in local time, or "Not scheduled".
String formatBookingDate(DateTime? value) {
  if (value == null) return 'Not scheduled';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

/// Customer-facing text for a normalized payment status.
String bookingPaymentLabel(String status) => switch (status) {
      'cod' => 'Cash on delivery • Payment due at delivery',
      'paid' => 'Paid successfully',
      'failed' => 'Failed • Please contact support to retry payment',
      'cancelled' => 'Cancelled',
      'pending' => 'Pending confirmation',
      _ => status.replaceAll('_', ' '),
    };
