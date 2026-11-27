import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({
    required this.controller,
    super.key,
  });

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

  Future<void> _review(
    Map<String, dynamic> user, {
    required bool approve,
  }) async {
    final id = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'this applicant';
    if (id.isEmpty) return;
    final decision = approve ? 'approved' : 'rejected';
    final confirmed = await showAppConfirmDialog(
      context,
      title: approve ? 'Approve admin access?' : 'Reject admin request?',
      message: approve
          ? 'Create an admin account for $name? A password setup link will be sent by email.'
          : 'Reject the admin access request from $name?',
      confirmLabel: approve ? 'Approve' : 'Reject',
      destructive: !approve,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = id);
    try {
      await widget.controller.api.reviewAdminAccessRequest(
        id,
        decision: decision,
      );
      if (!mounted) return;
      if (approve) {
        await _load();
        if (!mounted) return;
      } else {
        setState(() {
          _users = [
            for (final item in _users)
              if (item['id'] == id) {...item, 'status': 'rejected'} else item,
          ];
        });
      }
      showAppSnack(
        context,
        approve
            ? 'Admin access approved for $name.'
            : 'Request rejected for $name.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
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

  Future<void> _setActive(
    Map<String, dynamic> user, {
    required bool isActive,
  }) async {
    final id = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'this admin';
    if (id.isEmpty) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: isActive ? 'Reactivate admin access?' : 'Deactivate admin access?',
      message:
          '${isActive ? 'Reactivate' : 'Deactivate'} admin access for $name?',
      confirmLabel: isActive ? 'Reactivate' : 'Deactivate',
      destructive: !isActive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = id);
    try {
      await widget.controller.api.setAdminUserActive(id, isActive: isActive);
      if (!mounted) return;
      setState(() {
        _users = [
          for (final item in _users)
            if (item['id'] == id) {...item, 'is_active': isActive} else item,
        ];
      });
      showAppSnack(
        context,
        'Admin access ${isActive ? 'reactivated' : 'deactivated'} for $name.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
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

  Widget _section(
    String title,
    List<Map<String, dynamic>> users,
    String emptyMessage, {
    required bool approvalEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (users.isEmpty)
          SurfaceCard(child: Text(emptyMessage))
        else
          for (final user in users) ...[
            _UserCard(
              user: user,
              busy: _busyId != null,
              approvalEnabled: approvalEnabled,
              onApprove: () => _review(user, approve: true),
              onReject: () => _review(user, approve: false),
              onSetActive: (isActive) => _setActive(user, isActive: isActive),
            ),
            const SizedBox(height: AppSpace.md),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvalState = ref.watch(adminApprovalRequiredProvider);
    final approvalEnabled = approvalState.asData?.value == true;
    final pending =
        _users.where((user) => user['status'] == 'pending').toList();
    final approved = _users
        .where(
            (user) => user['kind'] == 'admin' && user['status'] == 'approved')
        .toList();
    final rejected =
        _users.where((user) => user['status'] == 'rejected').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Users')),
      body: _loading
          ? const LoadingState(message: 'Loading admin users...')
          : _error != null
              ? ErrorState(
                  error: _error!,
                  message: _error!,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: AppPageInsets.withSafeAreaBottom(
                      context,
                      AppPageInsets.standard,
                    ),
                    children: [
                      if (_users.isEmpty)
                        const EmptyState(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'No admin accounts or requests.',
                        )
                      else ...[
                        _section(
                          'Pending',
                          pending,
                          'There are no pending admin requests.',
                          approvalEnabled: approvalEnabled,
                        ),
                        _section(
                          'Approved',
                          approved,
                          'There are no approved admin accounts.',
                          approvalEnabled: approvalEnabled,
                        ),
                        _section(
                          'Rejected',
                          rejected,
                          'There are no rejected admin requests.',
                          approvalEnabled: approvalEnabled,
                        ),
                      ],
                      if (approvalState.hasError)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpace.md),
                          child: Text(
                            'Approval settings could not be loaded. Existing approved accounts can still be deactivated or reactivated.',
                          ),
                        )
                      else if (approvalState.hasValue && !approvalEnabled)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpace.md),
                          child: Text(
                            'Admin approval is off. Existing approved accounts can still be deactivated or reactivated.',
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.approvalEnabled,
    required this.onApprove,
    required this.onReject,
    required this.onSetActive,
  });

  final Map<String, dynamic> user;
  final bool busy;
  final bool approvalEnabled;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = user['kind']?.toString();
    final isAdmin = kind == 'admin';
    final isActive = user['is_active'] == true;
    final requestedAt = DateTime.tryParse(
      user['requested_at']?.toString() ?? '',
    );
    final requestedAtLabel = requestedAt == null
        ? 'Date unavailable'
        : requestedAt.toLocal().toString().substring(0, 16);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user['name']?.toString() ?? 'Admin user',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(user['email']?.toString() ?? ''),
          if (user['phone_e164'] is String) Text(user['phone_e164'] as String),
          Text(
            'Status: ${user['status']}${isAdmin ? ' · ${isActive ? 'Active' : 'Deactivated'}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.md),
          if (user['reason'] is String) ...[
            Text('Reason', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpace.xs),
            Text(user['reason'] as String),
            const SizedBox(height: AppSpace.md),
          ],
          Text('Requested $requestedAtLabel', style: theme.textTheme.bodySmall),
          if (kind == 'request' && user['status'] == 'pending') ...[
            const SizedBox(height: AppSpace.md),
            if (approvalEnabled)
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  PrimaryButton(
                    label: 'Approve',
                    icon: Icons.check_circle_outline,
                    onPressed: busy ? null : onApprove,
                  ),
                  GhostButton(
                    label: 'Reject',
                    onPressed: busy ? null : onReject,
                  ),
                ],
              )
            else
              const Text('Approval actions are disabled.'),
          ] else if (isAdmin && user['status'] == 'approved') ...[
            const SizedBox(height: AppSpace.md),
            GhostButton(
              label: isActive ? 'Deactivate' : 'Reactivate',
              onPressed: busy ? null : () => onSetActive(!isActive),
            ),
          ],
        ],
      ),
    );
  }
}
