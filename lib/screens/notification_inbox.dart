import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/notification.dart';

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({
    required this.controller,
    required this.role,
    super.key,
  });

  final AppController controller;
  final String role;

  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  late Future<List<NotificationItem>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.controller.api.notifications(widget.role);
  }

  void _reload() {
    setState(() {
      _notifications = widget.controller.api.notifications(widget.role);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (widget.role == 'customer')
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                await widget.controller.api.markAllNotificationsRead(widget.role);
                if (mounted) _reload();
              },
            ),
        ],
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _InboxMessage(
              icon: Icons.cloud_off_outlined,
              message: snapshot.error.toString(),
              action: _reload,
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const _InboxMessage(
              icon: Icons.notifications_none_outlined,
              message: 'You are all caught up.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      item.read
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                      color: item.read
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.message),
                    isThreeLine: item.message.isNotEmpty,
                    onTap: item.read
                        ? null
                        : () async {
                            await widget.controller.api
                                .markNotificationRead(widget.role, item.id);
                            if (mounted) _reload();
                          },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: action, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
