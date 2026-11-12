import '../core/design_system/widgets/app_snack.dart';
import '../models/session.dart';
import 'realtime_service.dart';

/// A user-visible message derived from a realtime event.
class RealtimeNotice {
  const RealtimeNotice({
    required this.key,
    required this.message,
    this.variant = AppSnackVariant.info,
    this.isNewOrder = false,
  });

  /// Identifies the underlying business fact. Two events describing the same
  /// fact (for example `booking.vendor_accepted` and `booking.updated` with
  /// status `accepted`) share a key so the user sees only one notice.
  final String key;
  final String message;
  final AppSnackVariant variant;
  final bool isNewOrder;
}

const _customerStatusMessages = <String, String>{
  'accepted': 'Your vendor accepted the booking.',
  'dispatched': 'Your tanker has been dispatched.',
  'en_route': 'Your tanker is on the way.',
  'arrived': 'Your tanker has arrived.',
  'delivered': 'Your delivery is complete.',
  'cancelled': 'Your booking was cancelled.',
};

/// Maps a realtime event to the notice [role] should see, or null when the
/// event is not relevant to that role.
RealtimeNotice? realtimeNoticeFor(WorkspaceRole role, RealtimeEvent event) {
  final payload = event.payload;
  if (payload is! Map) return null;
  final bookingId = payload['bookingId']?.toString() ?? '';
  final reference = payload['reference']?.toString();
  final label = (reference != null && reference.isNotEmpty)
      ? reference
      : (bookingId.isNotEmpty ? bookingId : 'order');

  switch (role) {
    case WorkspaceRole.customer:
      return switch (event.name) {
        'booking.vendor_accepted' => _bookingNotice(
            bookingId,
            'accepted',
            _customerStatusMessages['accepted']!,
          ),
        'booking.delivered' => _bookingNotice(
            bookingId,
            'delivered',
            _customerStatusMessages['delivered']!,
            variant: AppSnackVariant.success,
          ),
        'booking.updated' => _customerStatusNotice(bookingId, payload),
        _ => null,
      };
    case WorkspaceRole.vendor:
      return switch (event.name) {
        'vendor.order.created' => RealtimeNotice(
            key: 'offer:$bookingId',
            message: 'New order $label is available. Open Operations to accept.',
            isNewOrder: true,
          ),
        'vendor.order.taken' => RealtimeNotice(
            key: 'taken:$bookingId',
            message: payload['message']?.toString() ??
                'Order $label was accepted by another vendor.',
          ),
        'vendor.order.declined' => RealtimeNotice(
            key: 'declined:$bookingId',
            message: 'Order $label was declined.',
          ),
        _ => null,
      };
    case WorkspaceRole.dispatcher:
    case WorkspaceRole.admin:
      return null;
  }
}

RealtimeNotice? _customerStatusNotice(
  String bookingId,
  Map<dynamic, dynamic> payload,
) {
  final status = payload['status']?.toString().toLowerCase();
  final message = status == null ? null : _customerStatusMessages[status];
  if (status == null || message == null) return null;
  return _bookingNotice(
    bookingId,
    status,
    message,
    variant: status == 'delivered'
        ? AppSnackVariant.success
        : AppSnackVariant.info,
  );
}

RealtimeNotice _bookingNotice(
  String bookingId,
  String stage,
  String message, {
  AppSnackVariant variant = AppSnackVariant.info,
}) {
  return RealtimeNotice(
    key: 'booking:$bookingId:$stage',
    message: message,
    variant: variant,
  );
}
