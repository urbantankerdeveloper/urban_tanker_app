import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/account.dart';
import '../../services/friendly_error.dart';

/// How urgent an alert is. Drives the group it sits in and its colour.
enum AlertSeverity { danger, warning, info }

/// Severity from the alert data. An explicit `severity` wins. Without one, the
/// alert type decides: delivery problems are danger, unassigned work is a
/// warning, and anything else is info.
AlertSeverity alertSeverity(AccountRecord item) {
  final declared = (item.data['severity'] ?? '').toString().toLowerCase();
  switch (declared) {
    case 'critical' || 'high' || 'danger':
      return AlertSeverity.danger;
    case 'medium' || 'warning':
      return AlertSeverity.warning;
    case 'low' || 'info':
      return AlertSeverity.info;
  }
  final type = (item.data['type'] ??
          item.data['alert_type'] ??
          item.data['alertType'] ??
          item.status)
      .toString()
      .toLowerCase();
  if (type.contains('exception') ||
      type.contains('failed') ||
      type.contains('cancel')) {
    return AlertSeverity.danger;
  }
  if (type.contains('unassigned') || type.contains('pending')) {
    return AlertSeverity.warning;
  }
  return AlertSeverity.info;
}

/// Dispatcher alerts, grouped by severity, with one-tap resolve and dismiss.
class DispatcherAlertsScreen extends ConsumerStatefulWidget {
  const DispatcherAlertsScreen({super.key});

  @override
  ConsumerState<DispatcherAlertsScreen> createState() =>
      _DispatcherAlertsScreenState();
}

class _DispatcherAlertsScreenState
    extends ConsumerState<DispatcherAlertsScreen> {
  String? status;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(dispatcherAlertsProvider(status));
    return alerts.when(
      loading: () => const LoadingState(message: 'Loading alerts...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(dispatcherAlertsProvider(status)),
      ),
      data: (items) {
        final open = status == null;
        // Fixed status filter above the groups. Only the groups are lazy.
        final groups = <(AlertSeverity, List<AccountRecord>)>[
          for (final severity in AlertSeverity.values)
            (
              severity,
              [
                for (final item in items)
                  if (alertSeverity(item) == severity) item,
              ],
            ),
        ].where((group) => group.$2.isNotEmpty).toList();
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(dispatcherAlertsProvider(status)),
          child: ListView(
            padding: AppPageInsets.withSafeAreaBottom(
              context,
              AppPageInsets.standard,
            ),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Alert status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Open alerts')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(
                    value: 'dismissed',
                    child: Text('Dismissed'),
                  ),
                ],
                onChanged: (value) => setState(() => status = value),
              ),
              const SizedBox(height: AppSpace.lg),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No dispatch alerts.',
                ),
              for (final (severity, group) in groups) ...[
                _GroupHeader(severity: severity, count: group.length),
                const SizedBox(height: AppSpace.sm),
                for (final item in group)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: _AlertCard(
                      item: item,
                      severity: severity,
                      actionable: open && item.status == 'open',
                      onAction: (action) => _update(item, action),
                      onDetails: () => _details(item),
                    ),
                  ),
                const SizedBox(height: AppSpace.sm),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _update(AccountRecord item, String action) async {
    try {
      await ref.read(appControllerProvider).api.updateDispatcherAlert(
            item.id,
            action,
          );
      ref.invalidate(dispatcherAlertsProvider(status));
      if (!mounted) return;
      showAppSnack(
        context,
        'Alert ${action == 'resolved' ? 'resolved' : 'dismissed'}.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Alert update failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }

  void _details(AccountRecord item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: item.title,
        message: item.data.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.severity, required this.count});

  final AlertSeverity severity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, tone, icon) = switch (severity) {
      AlertSeverity.danger => ('Critical', colors.danger, Icons.error_outline),
      AlertSeverity.warning => (
          'Needs attention',
          colors.warning,
          Icons.warning_amber_outlined,
        ),
      AlertSeverity.info => ('Information', colors.info, Icons.info_outline),
    };
    return Row(
      children: [
        StatusChip(label: label, tone: tone, icon: icon),
        const SizedBox(width: AppSpace.sm),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.item,
    required this.severity,
    required this.actionable,
    required this.onAction,
    required this.onDetails,
  });

  final AccountRecord item;
  final AlertSeverity severity;
  final bool actionable;
  final ValueChanged<String> onAction;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final tone = switch (severity) {
      AlertSeverity.danger => colors.danger,
      AlertSeverity.warning => colors.warning,
      AlertSeverity.info => colors.info,
    };
    return SurfaceCard(
      padding: AppPageInsets.card,
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            item.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Status: ${StatusChip.statusLabel(item.status)}',
            style: theme.textTheme.bodySmall?.copyWith(color: tone.fg),
          ),
          if (actionable) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Resolve',
                    icon: Icons.check,
                    onPressed: () => onAction('resolved'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: SecondaryButton(
                    label: 'Dismiss',
                    icon: Icons.close,
                    onPressed: () => onAction('dismissed'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
