import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../app/auth_feature_flags.dart';
import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/notification.dart';
import '../../../models/session.dart';
import '../../../models/workspace_navigation.dart';
import '../../security_settings_screen.dart';
import '../../profile_dialog.dart';
import '../../admin/admin_access_requests_screen.dart';
import '../../admin/admin_settings_screen.dart';
import 'appearance.dart';

/// Menu tab for vendor, dispatcher and admin. Replaces the old drawer: the
/// role's destinations, notifications, security, appearance and sign out.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({
    required this.controller,
    required this.role,
    required this.notifications,
    required this.onDestination,
    required this.onNotifications,
    required this.onHome,
    super.key,
  });

  final AppController controller;
  final WorkspaceRole role;
  final Future<List<NotificationItem>>? notifications;
  final ValueChanged<WorkspaceNavigationDestination> onDestination;
  final VoidCallback onNotifications;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      appControllerProvider.select((controller) => controller.user),
    );
    final profilePhoto = ref.watch(profileSelfieProvider);
    final profilePhotoUrl = profilePhoto.when(
      data: (url) => url,
      loading: () => null,
      error: (_, __) => null,
    );
    final profilePhotoFuture = ref.read(profileSelfieProvider.future);
    void openProfile() {
      if (user == null) return;
      showUserProfileDialog(
        context: context,
        api: controller.api,
        name: user.name,
        username: user.username,
        email: user.email,
        phone: user.phone,
        role: role.name,
        profilePhotoUrl: profilePhotoFuture,
        initialProfilePhotoUrl: profilePhotoUrl,
        onSaved: (profile) async {
          controller.applyProfileUpdate(profile);
          ref.invalidate(profileSelfieProvider);
        },
      );
    }

    if (AuthFeatureFlags.newUiEnabled) {
      return ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          if (user != null)
            _NewUiMenuProfileHeader(
              name: user.name,
              role: role,
              imageUrl: profilePhotoUrl,
              onTap: openProfile,
            ),
          const SizedBox(height: AppSpace.xl),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: _Rows([
              AppListRow(
                leading: const Icon(Icons.person_outline),
                title: 'Profile',
                trailing: const Icon(Icons.chevron_right),
                onTap: openProfile,
              ),
              AppListRow(
                leading: _NotificationIcon(notifications: notifications),
                title: 'Notifications',
                trailing: const Icon(Icons.chevron_right),
                onTap: onNotifications,
              ),
              AppListRow(
                leading: const Icon(Icons.settings_outlined),
                title: 'Settings',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => role == WorkspaceRole.admin
                    ? _openAdminSettings(context)
                    : _openSecurity(context),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.xl),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: _DarkModeRow(controller: controller),
          ),
          const SizedBox(height: AppSpace.xxl),
          SecondaryButton(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      );
    }

    return ListView(
      padding: AppPageInsets.withSafeAreaBottom(
        context,
        AppPageInsets.standard,
      ),
      children: [
        if (user != null)
          _ProfileHeader(
            name: user.name,
            username: user.username,
            role: role,
            email: user.email,
            phone: user.phone,
            imageUrl: profilePhotoUrl,
            onTap: openProfile,
          ),
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
            if (AuthFeatureFlags.profileMenu)
              AppListRow(
                leading: const Icon(Icons.person_outline),
                title: 'My profile',
                trailing: const Icon(Icons.chevron_right),
                onTap: openProfile,
              ),
            if (role == WorkspaceRole.admin)
              AppListRow(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: 'Admin Users',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminUsersScreen(controller: controller),
                  ),
                ),
              ),
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

  void _openAdminSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminSettingsScreen(controller: controller, onBackToHome: onHome),
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
    required this.imageUrl,
    required this.onTap,
    this.email,
    this.phone,
  });

  final String name;
  final String username;
  final WorkspaceRole role;
  final String? imageUrl;
  final String? email;
  final String? phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Open profile for $name',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs),
          child: Row(
            children: [
              AppAvatar(name: name, imageUrl: imageUrl, size: 56),
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
                    Text(
                      maskUsername(username),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (email?.isNotEmpty == true)
                      Text(
                        'Email: $email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (phone?.isNotEmpty == true)
                      Text(
                        'Phone: $phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
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
          ),
        ),
      ),
    );
  }
}

class _NewUiMenuProfileHeader extends StatelessWidget {
  const _NewUiMenuProfileHeader({
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final WorkspaceRole role;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppListRow(
    leading: AppAvatar(name: name, imageUrl: imageUrl, size: 56),
    title: name,
    subtitle: StatusChip.statusLabel(role.name),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final systemDark =
          MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      final isDark =
          controller.themeMode == ThemeMode.dark ||
          (controller.themeMode == ThemeMode.system && systemDark);
      return AppListRow(
        leading: const Icon(Icons.dark_mode_outlined),
        title: 'Dark mode',
        trailing: Switch(
          value: isDark,
          onChanged: (enabled) => controller.setThemeMode(
            enabled ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
      );
    },
  );
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
