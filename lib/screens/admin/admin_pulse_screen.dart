import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';

/// Platform health: the system, realtime, storage and configuration as status
/// tiles, then migration checks and storage cleanup.
class AdminPulseScreen extends ConsumerWidget {
  const AdminPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(adminHealthProvider);
    return healthState.when(
      loading: () => const LoadingState(message: 'Checking the platform...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(adminHealthProvider),
      ),
      data: (health) {
        final ok = health['ok'] == true;
        final realtime = (health['realtime'] as Map?)?['connected'] == true;
        final storage = (health['storage'] as Map?)?['configured'] == true;
        final configWarnings = (health['configuration'] as Map?)
                ?.values
                .where((value) => value != true)
                .length ??
            0;
        final migrations = health['migrations'] is List
            ? (health['migrations'] as List).whereType<Map>().toList()
            : const <Map>[];
        final theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminHealthProvider),
          child: ListView(
            padding: AppPageInsets.withSafeAreaBottom(
              context,
              AppPageInsets.standard,
            ),
            children: [
              Text('Platform pulse', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpace.lg),
              if (ref.watch(appControllerProvider.select(
                (controller) => controller.adminDashboardV2Enabled,
              ))) ...[
                _DashboardSummarySection(
                  areaAvailabilityEnabled: ref.watch(
                      appControllerProvider.select(
                          (controller) => controller.areaAvailabilityEnabled)),
                ),
                const SizedBox(height: AppSpace.xl),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpace.md,
                crossAxisSpacing: AppSpace.md,
                childAspectRatio: 1.45,
                children: [
                  _HealthTile(
                    label: 'System',
                    value: ok ? 'Healthy' : 'Attention required',
                    healthy: ok,
                  ),
                  _HealthTile(
                    label: 'Realtime',
                    value: realtime ? 'Connected' : 'Unavailable',
                    healthy: realtime,
                  ),
                  _HealthTile(
                    label: 'Storage',
                    value: storage ? 'Configured' : 'Not configured',
                    healthy: storage,
                  ),
                  _HealthTile(
                    label: 'Configuration',
                    value: configWarnings == 0
                        ? 'Complete'
                        : '$configWarnings to review',
                    healthy: configWarnings == 0,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'MIGRATION CHECKS',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpace.md),
              if (migrations.isEmpty)
                const EmptyState(
                  icon: Icons.storage_outlined,
                  title: 'No migration checks reported.',
                ),
              for (final item in migrations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: AppListRow(
                      leading: StatusDot(healthy: item['applied'] == true),
                      title: (item['table'] ?? 'Table').toString(),
                      subtitle: item['applied'] == true
                          ? 'Available'
                          : (item['error'] ?? 'Unavailable').toString(),
                      trailing: item['applied'] == true
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  ref.invalidate(adminHealthProvider),
                              child: const Text('Retry'),
                            ),
                    ),
                  ),
                ),
              if (configWarnings > 0) ...[
                const SizedBox(height: AppSpace.md),
                SurfaceCard(
                  child: AppListRow(
                    leading: Icon(
                      Icons.warning_amber_outlined,
                      color: context.colors.warning.fg,
                    ),
                    title: 'Configuration warnings',
                    subtitle: 'One or more integrations are not configured.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              SecondaryButton(
                label: 'Run storage cleanup',
                icon: Icons.cleaning_services_outlined,
                onPressed: () => _cleanup(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cleanup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appControllerProvider).api.adminStorageCleanup();
      ref.invalidate(adminHealthProvider);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Cleanup failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }
}

class _DashboardSummarySection extends ConsumerWidget {
  const _DashboardSummarySection({required this.areaAvailabilityEnabled});

  final bool areaAvailabilityEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(adminDashboardSummaryProvider);
    return summaryState.when(
      loading: () => const LoadingState(
        message: "Loading today's operations...",
      ),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(adminDashboardSummaryProvider),
      ),
      data: (summary) {
        final statuses = summary['activeOrdersByStatus'];
        final statusCounts =
            statuses is Map ? statuses : const <String, dynamic>{};
        final activeOrders = statusCounts.values
            .whereType<num>()
            .fold<int>(0, (total, count) => total + count.toInt());
        final revenue = summary['todayRevenuePaise'];
        final revenueRupees = revenue is num ? revenue / 100 : 0;
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operations dashboard',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh operations dashboard',
                  onPressed: () {
                    ref.invalidate(adminDashboardSummaryProvider);
                    if (areaAvailabilityEnabled) {
                      ref.invalidate(adminAvailabilityByAreaProvider);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpace.sm,
              crossAxisSpacing: AppSpace.sm,
              childAspectRatio: 1.25,
              children: [
                _DashboardMetric(
                  label: 'Active orders',
                  value: '$activeOrders',
                  detail: 'Across all active statuses',
                  icon: Icons.local_shipping_outlined,
                ),
                _DashboardMetric(
                  label: "Today's captured revenue",
                  value: '₹${revenueRupees.toStringAsFixed(2)}',
                  detail: 'Payments captured today',
                  icon: Icons.currency_rupee,
                ),
                _DashboardMetric(
                  label: 'Partner applications',
                  value: '${summary['pendingPartnerApplications'] ?? 0}',
                  detail: 'Submitted or under review',
                  icon: Icons.business_outlined,
                ),
                _DashboardMetric(
                  label: 'Vendors online',
                  value: '${summary['onlineVendors'] ?? 0}',
                  detail: 'Approved vendors',
                  icon: Icons.people_outline,
                ),
                _DashboardMetric(
                  label: 'Drivers active',
                  value: '${summary['activeDrivers'] ?? 0}',
                  detail: 'Approved drivers marked active',
                  icon: Icons.person_pin_circle_outlined,
                ),
                _DashboardMetric(
                  label: 'Open order alerts',
                  value: '${summary['openOrderAlerts'] ?? 0}',
                  detail: 'Unresolved dispatcher alerts',
                  icon: Icons.warning_amber_outlined,
                ),
                _DashboardMetric(
                  label: 'Failed payments',
                  value: '${summary['failedPayments'] ?? 0}',
                  detail: 'Payment records requiring attention',
                  icon: Icons.payment_outlined,
                ),
                _DashboardMetric(
                  label: 'Orders unchanged 2+ hours',
                  value: '${summary['stuckOrders'] ?? 0}',
                  detail: 'Active orders by last update',
                  icon: Icons.hourglass_bottom,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Text('Active orders by status', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            for (final (status, label) in const [
              ('pending_vendor', 'Awaiting assignment'),
              ('vendor_assigned', 'Vendor assigned'),
              ('accepted', 'Accepted'),
              ('en_route', 'En route'),
              ('arrived', 'Arrived'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: AppListRow(
                    title: label,
                    trailing: Text(
                      '${statusCounts[status] ?? 0}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            if (areaAvailabilityEnabled) ...[
              const SizedBox(height: AppSpace.md),
              _AreaAvailabilitySection(),
            ],
          ],
        );
      },
    );
  }
}

class _AreaAvailabilitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasState = ref.watch(adminAvailabilityByAreaProvider);
    return areasState.when(
      loading: () => const LoadingState(
        message: 'Loading availability by service area...',
      ),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(adminAvailabilityByAreaProvider),
      ),
      data: (areas) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Availability by service area',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Grouped by vendor-entered service-zone names.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpace.sm),
            if (areas.isEmpty)
              const EmptyState(
                icon: Icons.location_on_outlined,
                title: 'No service-area availability yet.',
              ),
            for (final area in areas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (area['area'] ?? 'Unassigned area').toString(),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Online vendors: ${area['onlineVendors'] ?? 0} · '
                        'Active vehicles: ${area['activeVehicles'] ?? 0} · '
                        'Active drivers: ${area['activeDrivers'] ?? 0}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: context.colors.primary),
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatusDot(healthy: healthy),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
