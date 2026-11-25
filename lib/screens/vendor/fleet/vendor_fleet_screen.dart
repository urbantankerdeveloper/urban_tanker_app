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

void _refreshVendorFleet(WidgetRef ref) {
  ref.read(apiProvider).invalidateReadCache(path: '/vendor/services');
  ref
    ..invalidate(vendorDashboardProvider)
    ..invalidate(vendorServicesProvider)
    ..invalidate(vendorAttendanceProvider)
    ..invalidate(vendorComplaintsProvider)
    ..invalidate(vendorDocumentsProvider);
}

/// Vendor fleet tab: vehicles and drivers as cards, then availability,
/// complaints, documents and attendance.
class VendorFleetScreen extends ConsumerStatefulWidget {
  const VendorFleetScreen({super.key});

  @override
  ConsumerState<VendorFleetScreen> createState() => _VendorFleetScreenState();
}

class _VendorFleetScreenState extends ConsumerState<VendorFleetScreen> {
  static const _approvalTabs = ['Waiting for approval', 'Approved'];

  int _vehicleApprovalTab = 0;
  int _driverApprovalTab = 0;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref
      ..watch(vendorServicesProvider)
      ..watch(vendorAttendanceProvider(DateUtils.dateOnly(DateTime.now())))
      ..watch(vendorComplaintsProvider)
      ..watch(vendorDocumentsProvider);
    final dashboard = ref.watch(vendorDashboardProvider);
    return dashboard.when(
      loading: () => const LoadingState(message: 'Loading your fleet...'),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => _refreshVendorFleet(ref),
      ),
      data: (value) {
        final availableVehicles =
            value.vehicles.where((vehicle) => vehicle.assignable).length;
        final availableDrivers =
            value.drivers.where((driver) => driver.assignable).length;
        final waitingVehicles = value.vehicles
            .where(
                (vehicle) => vehicle.verification.toLowerCase() != 'approved')
            .toList(growable: false);
        final approvedVehicles = value.vehicles
            .where(
                (vehicle) => vehicle.verification.toLowerCase() == 'approved')
            .toList(growable: false);
        final waitingDrivers = value.drivers
            .where((driver) => driver.verification.toLowerCase() != 'approved')
            .toList(growable: false);
        final approvedDrivers = value.drivers
            .where((driver) => driver.verification.toLowerCase() == 'approved')
            .toList(growable: false);
        final shownVehicles =
            _vehicleApprovalTab == 0 ? waitingVehicles : approvedVehicles;
        final shownDrivers =
            _driverApprovalTab == 0 ? waitingDrivers : approvedDrivers;

        Widget withApprovalSwipe(
          int selectedIndex,
          ValueChanged<int> onChanged,
          Widget child,
        ) =>
            SwipeNavigationArea(
              onSwipeLeft: selectedIndex == 0 ? () => onChanged(1) : null,
              onSwipeRight: selectedIndex == 1 ? () => onChanged(0) : null,
              child: child,
            );

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
          () => withApprovalSwipe(
                _vehicleApprovalTab,
                (index) => setState(() => _vehicleApprovalTab = index),
                SectionHeader(
                  title: 'Vehicles',
                  actionLabel: 'Add',
                  onAction: () => addVehicle(context, ref),
                ),
              ),
          () => withApprovalSwipe(
                _vehicleApprovalTab,
                (index) => setState(() => _vehicleApprovalTab = index),
                SegmentedTabs(
                  labels: _approvalTabs,
                  selectedIndex: _vehicleApprovalTab,
                  onChanged: (index) =>
                      setState(() => _vehicleApprovalTab = index),
                ),
              ),
          () => withApprovalSwipe(
                _vehicleApprovalTab,
                (index) => setState(() => _vehicleApprovalTab = index),
                const SizedBox(height: AppSpace.md),
              ),
          if (shownVehicles.isEmpty)
            () => withApprovalSwipe(
                  _vehicleApprovalTab,
                  (index) => setState(() => _vehicleApprovalTab = index),
                  AppListRow(
                    title: value.vehicles.isEmpty
                        ? 'No vehicles added yet.'
                        : _vehicleApprovalTab == 0
                            ? 'No vehicles waiting for approval.'
                            : 'No approved vehicles yet.',
                  ),
                ),
          for (final vehicle in shownVehicles)
            () => withApprovalSwipe(
                  _vehicleApprovalTab,
                  (index) => setState(() => _vehicleApprovalTab = index),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: VehicleTile(vehicle: vehicle),
                  ),
                ),
          () => const SizedBox(height: AppSpace.xl),
          () => withApprovalSwipe(
                _driverApprovalTab,
                (index) => setState(() => _driverApprovalTab = index),
                SectionHeader(
                  title: 'Drivers',
                  actionLabel: 'Add',
                  onAction: () => addDriver(context, ref),
                ),
              ),
          () => withApprovalSwipe(
                _driverApprovalTab,
                (index) => setState(() => _driverApprovalTab = index),
                SegmentedTabs(
                  labels: _approvalTabs,
                  selectedIndex: _driverApprovalTab,
                  onChanged: (index) =>
                      setState(() => _driverApprovalTab = index),
                ),
              ),
          () => withApprovalSwipe(
                _driverApprovalTab,
                (index) => setState(() => _driverApprovalTab = index),
                const SizedBox(height: AppSpace.md),
              ),
          if (shownDrivers.isEmpty)
            () => withApprovalSwipe(
                  _driverApprovalTab,
                  (index) => setState(() => _driverApprovalTab = index),
                  AppListRow(
                    title: value.drivers.isEmpty
                        ? 'No drivers added yet.'
                        : _driverApprovalTab == 0
                            ? 'No drivers waiting for approval.'
                            : 'No approved drivers yet.',
                  ),
                ),
          for (final driver in shownDrivers)
            () => withApprovalSwipe(
                  _driverApprovalTab,
                  (index) => setState(() => _driverApprovalTab = index),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: DriverTile(driver: driver),
                  ),
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
          onRefresh: () async => _refreshVendorFleet(ref),
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
