import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_feature_flags.dart';
import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';

class DispatcherHomeScreen extends ConsumerWidget {
  const DispatcherHomeScreen({
    required this.onOpenOrders,
    required this.onOpenLive,
    required this.onOpenAlerts,
    super.key,
  });

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenLive;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dispatcherHomeSummaryProvider);
    return summary.when(
      loading: () => AuthFeatureFlags.newUiEnabled
          ? const HomeLoadingState()
          : const LoadingState(message: 'Loading dispatch overview...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(dispatcherHomeSummaryProvider),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dispatcherHomeSummaryProvider),
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
                    'Dispatch overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.colors.onHero,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Current order workload and delivery progress.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.colors.onHero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpace.md,
                  mainAxisSpacing: AppSpace.md,
                  childAspectRatio: columns == 4 ? 1.35 : 1.15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Metric(
                      label: 'Awaiting assignment',
                      value: value.awaitingAssignment,
                      icon: Icons.pending_actions_outlined,
                    ),
                    _Metric(
                      label: 'Vendor assigned',
                      value: value.vendorAssigned,
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                    _Metric(
                      label: 'En route',
                      value: value.enRoute,
                      icon: Icons.local_shipping_outlined,
                    ),
                    _Metric(
                      label: 'Delivered today',
                      value: value.deliveredToday,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: 'View orders',
              icon: Icons.alt_route_outlined,
              onPressed: onOpenOrders,
            ),
            const SizedBox(height: AppSpace.md),
            SecondaryButton(
              label: 'Live fleet map',
              icon: Icons.radar_outlined,
              onPressed: onOpenLive,
            ),
            const SizedBox(height: AppSpace.sm),
            GhostButton(
              label: 'Open alerts',
              icon: Icons.warning_amber_outlined,
              onPressed: onOpenAlerts,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(height: AppSpace.xs),
          Text('$value', style: theme.textTheme.titleLarge),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
