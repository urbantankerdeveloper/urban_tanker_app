import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/notification.dart';
import '../../../models/session.dart';
import '../../../models/workspace_navigation.dart';
import '../../security_settings_screen.dart';
import 'appearance.dart';

/// Menu tab for vendor, dispatcher and admin. Replaces the old drawer: the
/// role's destinations, notifications, security, appearance and sign out.
class MenuScreen extends StatelessWidget {
  const MenuScreen({
    required this.controller,
    required this.role,
    required this.notifications,
    required this.onDestination,
    required this.onNotifications,
    super.key,
  });

  final AppController controller;
  final WorkspaceRole role;
  final Future<List<NotificationItem>>? notifications;
  final ValueChanged<WorkspaceNavigationDestination> onDestination;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.xxxl,
      ),
      children: [
        if (user != null)
          _ProfileHeader(name: user.name, username: user.username, role: role),
        for (final group in workspaceNavigationForRole(role)) ...[
          const SizedBox(height: AppSpace.xl),
          _GroupLabel(group.title),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: _Rows([
              for (final destination in group.destinations)
                AppListRow(
                  title: destination.label,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onDestination(destination),
                ),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        const _GroupLabel('Account'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: _Rows([
            AppListRow(
              leading: _NotificationIcon(notifications: notifications),
              title: 'Notifications',
              trailing: const Icon(Icons.chevron_right),
              onTap: onNotifications,
            ),
            AppListRow(
              leading: const Icon(Icons.lock_outline),
              title: 'Security settings',
              subtitle: 'MPIN and fingerprint',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSecurity(context),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.xl),
        const _GroupLabel('Appearance'),
        AppearanceControl(controller: controller),
        const SizedBox(height: AppSpace.xxl),
        SecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  void _openSecurity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SecuritySettingsScreen(controller: controller),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need your password or MPIN to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) await controller.signOut();
  }
}

/// Shows only the first character or two of the username.
String maskUsername(String username) {
  if (username.isEmpty) return '';
  final visible = username.length < 3 ? 1 : 2;
  return '${username.substring(0, visible)}••••';
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.role,
  });

  final String name;
  final String username;
  final WorkspaceRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        AppAvatar(name: name, size: 56),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              Text(maskUsername(username), style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpace.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusChip(
                  label: StatusChip.statusLabel(role.name),
                  icon: Icons.badge_outlined,
                  tone: context.colors.info,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

/// Rows separated by hairline dividers.
class _Rows extends StatelessWidget {
  const _Rows(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      );
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.notifications});

  final Future<List<NotificationItem>>? notifications;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NotificationItem>>(
        future: notifications,
        builder: (context, snapshot) {
          final unread = snapshot.data?.where((item) => !item.read).length ?? 0;
          return Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_outlined),
          );
        },
      );
}
