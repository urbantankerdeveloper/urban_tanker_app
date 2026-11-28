import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';

enum _AdminUserAction { activate, deactivate, approve, delete }

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({required this.controller, super.key});

  final AppController controller;

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.controller.api.adminUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _showActions(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    final isSelf = id == widget.controller.user?.id;
    final isRejected = user['status'] == 'rejected';
    final isRequest = user['kind'] == 'request';
    final isActive = user['is_active'] == true;
    final name = user['name']?.toString() ?? 'Admin user';
    final action = await showAppBottomSheet<_AdminUserAction>(
      context,
      builder: (sheetContext) => _AdminUserActionSheet(
        name: name,
        actions: [
          if (isRejected) ...[
            _AdminUserAction.activate,
            _AdminUserAction.approve,
          ] else
            isActive ? _AdminUserAction.deactivate : _AdminUserAction.activate,
          if (!isSelf) _AdminUserAction.delete,
        ],
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (action == null || !mounted) return;
    await _performAction(user, action, isRequest: isRequest);
  }

  Future<void> _performAction(
    Map<String, dynamic> user,
    _AdminUserAction action, {
    required bool isRequest,
  }) async {
    final id = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'this admin user';
    if (id.isEmpty) return;

    final isRequestAction = isRequest && user['status'] == 'rejected';
    final isRejectedAdmin = !isRequest && user['status'] == 'rejected';
    final prompt = switch (action) {
      _AdminUserAction.activate when isRequestAction =>
        'Reopen $name’s rejected request? It will move back to Approvals.',
      _AdminUserAction.activate when isRejectedAdmin =>
        'Approve and activate $name’s admin account?',
      _AdminUserAction.activate => 'Activate admin access for $name?',
      _AdminUserAction.deactivate => 'Set $name’s admin account inactive?',
      _AdminUserAction.approve =>
        isRequestAction
            ? 'Approve $name’s admin access request? An account setup email will be sent.'
            : 'Approve $name’s admin account?',
      _AdminUserAction.delete =>
        isRequest
            ? 'Delete the rejected request from $name?'
            : 'Delete $name’s admin account? This cannot be undone.',
    };
    final confirmed = await showAppConfirmDialog(
      context,
      title: switch (action) {
        _AdminUserAction.activate => 'Activate admin access?',
        _AdminUserAction.deactivate => 'Set admin inactive?',
        _AdminUserAction.approve => 'Approve admin access?',
        _AdminUserAction.delete => 'Delete admin user?',
      },
      message: prompt,
      confirmLabel: switch (action) {
        _AdminUserAction.activate => 'Activate',
        _AdminUserAction.deactivate => 'Set inactive',
        _AdminUserAction.approve => 'Approve',
        _AdminUserAction.delete => 'Delete',
      },
      destructive:
          action == _AdminUserAction.deactivate ||
          action == _AdminUserAction.delete,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = id);
    try {
      switch (action) {
        case _AdminUserAction.activate:
          if (isRequestAction) {
            await widget.controller.api.reactivateAdminAccessRequest(id);
          } else if (isRejectedAdmin) {
            await widget.controller.api.approveRejectedAdminUser(id);
            await widget.controller.api.setAdminUserActive(id, isActive: true);
          } else {
            await widget.controller.api.setAdminUserActive(id, isActive: true);
          }
        case _AdminUserAction.deactivate:
          await widget.controller.api.setAdminUserActive(id, isActive: false);
        case _AdminUserAction.approve:
          if (isRequestAction) {
            await widget.controller.api.reactivateAdminAccessRequest(id);
            await widget.controller.api.reviewAdminAccessRequest(
              id,
              decision: 'approved',
            );
          } else {
            await widget.controller.api.approveRejectedAdminUser(id);
          }
        case _AdminUserAction.delete:
          await widget.controller.api.deleteAdminUser(
            id,
            kind: isRequest ? 'request' : 'admin',
          );
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      showAppSnack(context, switch (action) {
        _AdminUserAction.activate when isRequestAction =>
          'Request reopened in Approvals.',
        _AdminUserAction.activate => 'Admin access activated for $name.',
        _AdminUserAction.deactivate => 'Admin access set inactive for $name.',
        _AdminUserAction.approve => 'Admin access approved for $name.',
        _AdminUserAction.delete => 'Admin user deleted.',
      }, variant: AppSnackVariant.success);
    } catch (error) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(error),
        variant: AppSnackVariant.error,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  List<Map<String, dynamic>> get _approvedAdmins => _users
      .where((user) => user['kind'] == 'admin' && user['status'] == 'approved')
      .toList();

  List<Map<String, dynamic>> get _rejectedUsers =>
      _users.where((user) => user['status'] == 'rejected').toList();

  Widget _section(
    String title,
    List<Map<String, dynamic>> users, {
    required bool rejected,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (users.isEmpty)
        SurfaceCard(
          child: Text(
            rejected
                ? 'There are no rejected admin users.'
                : 'There are no approved admin accounts.',
          ),
        )
      else
        for (final user in users) ...[
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              leading: Icon(
                user['kind'] == 'request'
                    ? Icons.person_add_alt_outlined
                    : Icons.admin_panel_settings_outlined,
              ),
              title: user['name']?.toString() ?? 'Admin user',
              subtitle:
                  [user['email']?.toString(), user['phone_e164']?.toString()]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdminStatusChip(
                    user: user,
                    rejected: rejected,
                    onTap:
                        !rejected &&
                            user['is_active'] == true &&
                            _busyId == null
                        ? () => _performAction(
                            user,
                            _AdminUserAction.deactivate,
                            isRequest: false,
                          )
                        : null,
                  ),
                  IconButton(
                    tooltip: 'More options',
                    onPressed: _busyId == null
                        ? () => _showActions(user)
                        : null,
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin Users')),
    body: _loading
        ? const LoadingState(message: 'Loading admin users...')
        : _error != null
        ? ErrorState(error: _error!, message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: AppPageInsets.withSafeAreaBottom(
                context,
                AppPageInsets.standard,
              ),
              children: [
                if (_approvedAdmins.isEmpty && _rejectedUsers.isEmpty)
                  const EmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'No admin users to display.',
                  )
                else ...[
                  _section('Approved', _approvedAdmins, rejected: false),
                  const SizedBox(height: AppSpace.md),
                  _section('Rejected', _rejectedUsers, rejected: true),
                ],
              ],
            ),
          ),
  );
}

class _AdminUserActionSheet extends StatelessWidget {
  const _AdminUserActionSheet({
    required this.name,
    required this.actions,
    required this.onSelected,
  });

  final String name;
  final List<_AdminUserAction> actions;
  final ValueChanged<_AdminUserAction> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.sm,
      AppSpace.gutter,
      AppSpace.lg,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.md),
        for (final action in actions)
          AppListRow(
            leading: Icon(_actionIcon(action)),
            title: _actionLabel(action),
            onTap: () => onSelected(action),
          ),
        AppListRow(
          leading: const Icon(Icons.close),
          title: 'Cancel',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  static String _actionLabel(_AdminUserAction action) => switch (action) {
    _AdminUserAction.activate => 'Activate',
    _AdminUserAction.deactivate => 'Set inactive',
    _AdminUserAction.approve => 'Approve',
    _AdminUserAction.delete => 'Delete',
  };

  static IconData _actionIcon(_AdminUserAction action) => switch (action) {
    _AdminUserAction.activate => Icons.check_circle_outline,
    _AdminUserAction.deactivate => Icons.pause_circle_outline,
    _AdminUserAction.approve => Icons.verified_outlined,
    _AdminUserAction.delete => Icons.delete_outline,
  };
}

class _AdminStatusChip extends StatelessWidget {
  const _AdminStatusChip({
    required this.user,
    required this.rejected,
    this.onTap,
  });

  final Map<String, dynamic> user;
  final bool rejected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = user['is_active'] == true;
    final label = rejected
        ? 'Rejected'
        : active
        ? 'Active'
        : 'Inactive';
    final tone = rejected
        ? context.colors.danger
        : active
        ? context.colors.success
        : context.colors.neutral;
    final chip = StatusChip(label: label, tone: tone);
    if (onTap == null) return chip;
    return Tooltip(
      message: 'Set inactive',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: chip,
      ),
    );
  }
}
