import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
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
    return AppScaffold(
      title: 'Notifications',
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
      body: FutureBuilder<List<NotificationItem>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState(message: 'Loading notifications...');
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final groups = groupNotifications(snapshot.data ?? const []);
          if (groups.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Nothing new',
              message: 'You are all caught up.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.xxxl,
              ),
              itemCount: groups.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) => _GroupCard(
                group: groups[index],
                onMarkRead: _markGroupRead,
                onOpen: _openNotification,
              ),
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
    showAppSnack(
      context,
      'Notification update failed: $error',
      variant: AppSnackVariant.error,
    );
  }
}

/// One group of notifications for a booking, invoice or support request.
/// Expands to show its items.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onMarkRead,
    required this.onOpen,
  });

  final NotificationGroup group;
  final Future<void> Function(NotificationGroup group) onMarkRead;
  final Future<void> Function(NotificationItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = group.unreadItems.length;
    final count = group.items.length;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: _TypeIcon(
            icon: group.isBookingGroup
                ? Icons.local_shipping_outlined
                : Icons.notifications_none_outlined,
            unread: unread > 0,
          ),
          title: Text(
            group.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            '$count event${count == 1 ? '' : 's'}'
            '${unread == 0 ? '' : ' • $unread unread'}',
          ),
          trailing: unread == 0
              ? null
              : TextButton(
                  onPressed: () => onMarkRead(group),
                  child: const Text('Mark as read'),
                ),
          children: [
            for (final item in group.items)
              AppListRow(
                leading: _TypeIcon(
                  icon: _iconFor(item),
                  unread: !item.read,
                ),
                title: item.title,
                subtitle: _subtitle(item),
                onTap: () => onOpen(item),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationItem item) {
    if (item.bookingId != null) return Icons.local_shipping_outlined;
    if (item.invoiceId != null) return Icons.receipt_long_outlined;
    if (item.supportRequestId != null) return Icons.support_agent_outlined;
    return Icons.notifications_none_outlined;
  }

  static String _subtitle(NotificationItem item) {
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

/// Type icon in a tinted circle, with a dot when the item is unread. The dot
/// is the unread cue; the icon and text carry the meaning.
class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.icon, required this.unread});

  final IconData icon;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        if (unread)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
