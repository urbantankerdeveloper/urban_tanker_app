import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../services/friendly_error.dart';
import 'records_card.dart';

/// Service availability for the vendor, with a switch per service.
class ServiceAvailabilityCard extends ConsumerWidget {
  const ServiceAvailabilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(vendorServicesProvider);
    return FleetCardShell(
      title: 'Service availability',
      icon: Icons.toggle_on_outlined,
      children: [
        services.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: SkeletonBox(height: 48),
          ),
          error: (error, _) => AppListRow(
            title: 'Could not load service availability',
            subtitle: friendlyError(error),
            trailing: IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(vendorServicesProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          data: (items) => items.isEmpty
              ? const AppListRow(title: 'No services available.')
              : Column(
                  children: [
                    for (final service in items)
                      AppListRow(
                        title: service.name,
                        subtitle: service.description,
                        trailing: Switch(
                          value: service.enabled,
                          onChanged: (enabled) async {
                            try {
                              await ref
                                  .read(appControllerProvider)
                                  .api
                                  .updateVendorServiceAvailability(
                                    serviceCode: service.code,
                                    enabled: enabled,
                                  );
                              ref.invalidate(vendorServicesProvider);
                            } catch (error) {
                              if (context.mounted) {
                                showAppSnack(
                                  context,
                                  'Availability update failed: $error',
                                  variant: AppSnackVariant.error,
                                );
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
