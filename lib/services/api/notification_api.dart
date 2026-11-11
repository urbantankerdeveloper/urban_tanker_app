import '../../models/notification.dart';
import 'api_decode.dart';
import 'api_transport.dart';

/// Notification inboxes, read receipts and push device registration.
class NotificationApi {
  NotificationApi(this._api);

  final ApiTransport _api;

  Future<List<NotificationItem>> notifications(String role) async {
    final path = switch (role) {
      'vendor' => '/vendor/notifications',
      'admin' => '/admin/notifications',
      'dispatcher' => '/admin/notifications',
      'customer' => '/customer/notifications',
      _ => throw UnsupportedError(
          'Notifications are not available for the $role workspace yet.',
        ),
    };
    final response = await _api.request('GET', path);
    final decoded = await decodeBodyAsync(response);
    if (decoded is! List) {
      throw const FormatException('The notifications response was invalid.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<List<NotificationItem>> adminNotifications() async =>
      notifications('admin');

  Future<void> markNotificationRead(String role, String id) async {
    final prefix = role == 'vendor'
        ? '/vendor'
        : role == 'dispatcher' || role == 'admin'
            ? '/admin'
            : '/customer';
    await _api.request('PATCH', '$prefix/notifications/$id/read');
  }

  Future<void> markAdminNotificationRead(String id) async {
    await _api.request('PATCH', '/admin/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead(String role) async {
    if (role != 'customer') {
      throw UnsupportedError(
        'Mark all as read is not available for the $role workspace.',
      );
    }
    await _api.request('PATCH', '/customer/notifications/read-all');
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _api.request(
      'POST',
      '/devices/register',
      body: {
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<void> unregisterDevice(String token) async {
    await _api.request(
      'DELETE',
      '/devices/register',
      body: {'token': token},
    );
  }
}
