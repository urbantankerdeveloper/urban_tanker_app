class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Urban Tanker update').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
      read: json['read_at'] != null || json['readAt'] != null,
    );
  }
}
