class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
    required this.payload,
  });

  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool read;
  final Map<String, dynamic> payload;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Urban Tanker update').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
      read: json['read_at'] != null || json['readAt'] != null,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }

  String? _id(String key) {
    final value = payload[key]?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  String? get bookingId => _id('bookingId');
  String? get bookingReference =>
      _id('bookingReference') ?? _id('reference') ?? _id('orderReference');
  String? get invoiceId => _id('invoiceId');
  String? get supportRequestId => _id('supportRequestId');
  String? get status => _id('status') ?? _id('eventType');
}

class NotificationGroup {
  const NotificationGroup({
    required this.key,
    required this.title,
    required this.items,
    required this.isBookingGroup,
  });

  final String key;
  final String title;
  final List<NotificationItem> items;
  final bool isBookingGroup;

  List<NotificationItem> get unreadItems =>
      items.where((item) => !item.read).toList(growable: false);
}

List<NotificationGroup> groupNotifications(
  List<NotificationItem> notifications,
) {
  final groups = <String, List<NotificationItem>>{};
  final titles = <String, String>{};
  final bookingGroups = <String, bool>{};
  for (final item in notifications) {
    final reference = item.bookingReference;
    final bookingId = item.bookingId;
    final groupKey = reference != null
        ? 'booking-reference:$reference'
        : bookingId != null
            ? 'booking-id:$bookingId'
            : 'notification:${item.id}';
    groups.putIfAbsent(groupKey, () => []).add(item);
    titles[groupKey] = reference ??
        (bookingId == null ? item.title : 'Booking $bookingId');
    bookingGroups[groupKey] = reference != null || bookingId != null;
  }
  return [
    for (final entry in groups.entries)
      NotificationGroup(
        key: entry.key,
        title: titles[entry.key]!,
        items: entry.value,
        isBookingGroup: bookingGroups[entry.key]!,
      ),
  ];
}
