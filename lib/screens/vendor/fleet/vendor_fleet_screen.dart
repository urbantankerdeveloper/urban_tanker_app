import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../services/friendly_error.dart';
import '../vendor_shared.dart';
import 'attendance_card.dart';
import 'complaints_card.dart';
import 'documents_card.dart';
import 'fleet_forms.dart';
import 'fleet_rows.dart';
import 'service_availability_card.dart';

/// Vendor fleet tab: vehicles and drivers as cards, then availability,
/// complaints, documents and attendance.
class VendorFleetScreen extends ConsumerWidget {
  const VendorFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(vendorDashboardProvider);
    return dashboard.when(
      loading: () => const LoadingState(message: 'Loading your fleet...'),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorDashboardProvider),
      ),
      data: (value) {
        final availableVehicles =
            value.vehicles.where((vehicle) => vehicle.assignable).length;
        final availableDrivers =
            value.drivers.where((driver) => driver.assignable).length;
        // Each entry builds one fixed widget or one vehicle or driver row, so
        // the rows are only created when they scroll into view.
        final entries = <Widget Function()>[
          () => Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Vehicles ready',
                      value: '$availableVehicles of ${value.vehicles.length}',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: StatCard(
                      label: 'Drivers ready',
                      value: '$availableDrivers of ${value.drivers.length}',
                      icon: Icons.person_outline,
                    ),
                  ),
                ],
              ),
          () => const SizedBox(height: AppSpace.xl),
          () => SectionHeader(
                title: 'Vehicles',
                actionLabel: 'Add',
                onAction: () => addVehicle(context, ref),
              ),
          if (value.vehicles.isEmpty)
            () => const AppListRow(title: 'No vehicles added yet.'),
          for (final vehicle in value.vehicles)
            () => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: VehicleTile(vehicle: vehicle),
                ),
          () => const SizedBox(height: AppSpace.xl),
          () => SectionHeader(
                title: 'Drivers',
                actionLabel: 'Add',
                onAction: () => addDriver(context, ref),
              ),
          if (value.drivers.isEmpty)
            () => const AppListRow(title: 'No drivers added yet.'),
          for (final driver in value.drivers)
            () => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: DriverTile(driver: driver),
                ),
          () => const SizedBox(height: AppSpace.xl),
          () => const ServiceAvailabilityCard(),
          () => const SizedBox(height: AppSpace.md),
          () => ComplaintsCard(orders: value.orders),
          () => const SizedBox(height: AppSpace.md),
          () => const DocumentsCard(),
          () => const SizedBox(height: AppSpace.md),
          () => AttendanceCard(drivers: value.drivers),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorDashboardProvider);
            ref.invalidate(vendorAttendanceProvider);
          },
          child: ListView.builder(
            padding: AppPageInsets.withSafeAreaBottom(
              context,
              AppPageInsets.standard,
            ),
            itemCount: entries.length,
            itemBuilder: (_, index) => entries[index](),
          ),
        );
      },
    );
  }
}
