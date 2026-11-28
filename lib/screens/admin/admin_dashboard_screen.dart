import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/workspace_navigation.dart';
import '../../services/friendly_error.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({
    required this.userName,
    required this.onOpenOperations,
    required this.onOpenReports,
    super.key,
  });

  final String userName;
  final ValueChanged<OperationsFocus> onOpenOperations;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminDashboardSummaryProvider);
    return summary.when(
      loading: () => const HomeLoadingState(),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(adminDashboardSummaryProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDashboardSummaryProvider),
        child: ListView(
          padding: AppPageInsets.withSafeAreaBottom(
            context,
            AppPageInsets.standard,
          ),
          children: [
            GradientCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE WHOLE NETWORK. ONE CLEAR VIEW.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.onHero.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Welcome back, ${userName.trim().isEmpty ? 'Admin' : userName.trim()}.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.colors.onHero,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Bookings, approvals and business performance at a glance.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.onHero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              'Network overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = AppSpace.sm;
                const columns = 4;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cardHeight = (cardWidth * 0.95)
                    .clamp(78.0, 108.0)
                    .toDouble();
                final metrics = <_DashboardMetric>[
                  _DashboardMetric(
                    label: 'Active orders',
                    value: '${data.activeOrderCount}',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(OperationsSection.orders),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Revenue today',
                    value:
                        '₹${(data.todayRevenuePaise / 100).toStringAsFixed(2)}',
                    icon: Icons.currency_rupee,
                    onTap: onOpenReports,
                  ),
                  _DashboardMetric(
                    label: 'Partner applications',
                    value: '${data.pendingPartnerApplications}',
                    icon: Icons.fact_check_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(
                        OperationsSection.finance,
                        subsection: 2,
                      ),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Online vendors',
                    value: '${data.onlineVendors}',
                    icon: Icons.storefront_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(
                        OperationsSection.people,
                        subsection: 0,
                      ),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Active drivers',
                    value: '${data.activeDrivers}',
                    icon: Icons.badge_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(
                        OperationsSection.people,
                        subsection: 3,
                      ),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Open order alerts',
                    value: '${data.openOrderAlerts}',
                    icon: Icons.warning_amber_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(OperationsSection.orders),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Failed payments',
                    value: '${data.failedPayments}',
                    icon: Icons.payment_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(
                        OperationsSection.finance,
                        subsection: 1,
                      ),
                    ),
                  ),
                  _DashboardMetric(
                    label: 'Stuck orders',
                    value: '${data.stuckOrders}',
                    icon: Icons.hourglass_bottom_outlined,
                    onTap: () => onOpenOperations(
                      const OperationsFocus(OperationsSection.orders),
                    ),
                  ),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: cardWidth / cardHeight,
                  children: metrics,
                );
              },
            ),
            const SizedBox(height: AppSpace.xl),
            Text('Quick access', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.md),
            _DashboardAction(
              icon: Icons.alt_route_outlined,
              title: 'Bookings & dispatch',
              subtitle: 'Review and manage current orders.',
              onTap: () => onOpenOperations(
                const OperationsFocus(OperationsSection.orders),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _DashboardAction(
              icon: Icons.people_outline,
              title: 'People & approvals',
              subtitle: 'Manage vendors, customers and fleet.',
              onTap: () => onOpenOperations(
                const OperationsFocus(OperationsSection.people),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _DashboardAction(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Finance & partners',
              subtitle: 'Review payouts, coupons and partner activity.',
              onTap: () => onOpenOperations(
                const OperationsFocus(OperationsSection.finance),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _DashboardAction(
              icon: Icons.analytics_outlined,
              title: 'Reports & performance',
              subtitle: 'View revenue reports and business trends.',
              onTap: onOpenReports,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: context.colors.primary),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: constraints.maxWidth < 90 ? 9 : 11,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpace.md),
    child: AppListRow(
      leading: Icon(icon, color: context.colors.primary),
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
