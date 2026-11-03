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
  });

  final String key;
  final String title;
  final List<NotificationItem> items;

  List<NotificationItem> get unreadItems =>
      items.where((item) => !item.read).toList(growable: false);
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Groups notifications by the local calendar day they arrived on, newest day
/// first. Items keep the order the server sent them in. Items without a time
/// go in a last group called Earlier.
List<NotificationGroup> groupNotificationsByDay(
  List<NotificationItem> notifications, {
  DateTime? now,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  final byDay = <DateTime?, List<NotificationItem>>{};
  for (final item in notifications) {
    final created = item.createdAt;
    final day = created == null ? null : _dayOf(created.toLocal());
    byDay.putIfAbsent(day, () => []).add(item);
  }
  final days = byDay.keys.whereType<DateTime>().toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      NotificationGroup(
        key: day.toIso8601String(),
        title: _dayTitle(day, today, yesterday),
        items: byDay[day]!,
      ),
    if (byDay.containsKey(null))
      NotificationGroup(
        key: 'undated',
        title: 'Earlier',
        items: byDay[null]!,
      ),
  ];
}

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

String _dayTitle(DateTime day, DateTime today, DateTime yesterday) {
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  return '${day.day} ${_monthNames[day.month - 1]} ${day.year}';
}
