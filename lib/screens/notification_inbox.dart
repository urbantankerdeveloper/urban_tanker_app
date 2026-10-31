import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
import '../models/notification.dart';

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({
    required this.controller,
    required this.role,
    this.onNotificationSelected,
    super.key,
  });

  final AppController controller;
  final String role;
  final ValueChanged<NotificationItem>? onNotificationSelected;

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
                try {
                  await widget.controller.api
                      .markAllNotificationsRead(widget.role);
                  if (mounted) _reload();
                } catch (error) {
                  _showError(error);
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppStateView.loading();
          }
          if (snapshot.hasError) {
            return AppStateView.error(
              error: snapshot.error!,
              onRetry: _reload,
            );
          }
          final groups = groupNotifications(snapshot.data ?? const []);
          if (groups.isEmpty) {
            return const AppStateView.empty(
              icon: Icons.notifications_none_outlined,
              message: 'You are all caught up.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: AppPageInsets.standard,
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  child: ExpansionTile(
                    leading: Icon(
                      group.unreadItems.isEmpty
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(group.title),
                    subtitle: Text(
                      '${group.items.length} event${group.items.length == 1 ? '' : 's'}'
                      '${group.unreadItems.isEmpty ? '' : ' • ${group.unreadItems.length} unread'}',
                    ),
                    trailing: group.unreadItems.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => _markGroupRead(group),
                            child: const Text('Mark as read'),
                          ),
                    children: group.items
                        .map(
                          (item) => ListTile(
                            leading: Icon(
                              item.read
                                  ? Icons.check_circle_outline
                                  : Icons.circle_notifications_outlined,
                            ),
                            title: Text(item.title),
                            subtitle: Text(_subtitle(item)),
                            isThreeLine: true,
                            onTap: () => _openNotification(item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _markGroupRead(NotificationGroup group) async {
    try {
      for (final item in group.unreadItems) {
        await widget.controller.api.markNotificationRead(widget.role, item.id);
      }
      if (mounted) _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openNotification(NotificationItem item) async {
    try {
      if (!item.read) {
        await widget.controller.api.markNotificationRead(widget.role, item.id);
      }
      if (item.bookingId != null ||
          item.invoiceId != null ||
          item.supportRequestId != null) {
        widget.onNotificationSelected?.call(item);
      }
      if (mounted) _reload();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Notification update failed: $error')));
  }

  String _subtitle(NotificationItem item) {
    final target = item.bookingId != null
        ? 'Open booking'
        : item.invoiceId != null
            ? 'Open invoice'
            : item.supportRequestId != null
                ? 'Open support request'
                : '';
    final timestamp = item.createdAt == null
        ? ''
        : item.createdAt!.toLocal().toString().substring(0, 16);
    return [
      if (item.status != null) 'Status: ${item.status}',
      item.message,
      if (timestamp.isNotEmpty) timestamp,
      target,
    ].where((value) => value.isNotEmpty).join('\n');
  }
}
