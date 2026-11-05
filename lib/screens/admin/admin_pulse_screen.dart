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
