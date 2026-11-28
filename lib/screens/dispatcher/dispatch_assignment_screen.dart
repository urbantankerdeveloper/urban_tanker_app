import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/dispatcher.dart';
import '../../models/vendor.dart';
import '../../services/friendly_error.dart';
import '../common/booking_format.dart';

void openDispatchAssignment(
  BuildContext context,
  Map<String, dynamic> rawOrder,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DispatchAssignmentScreen(rawOrder: rawOrder),
    ),
  );
}

class DispatchAssignmentScreen extends ConsumerStatefulWidget {
  const DispatchAssignmentScreen({required this.rawOrder, super.key});

  final Map<String, dynamic> rawOrder;

  @override
  ConsumerState<DispatchAssignmentScreen> createState() =>
      _DispatchAssignmentScreenState();
}

class _DispatchAssignmentScreenState
    extends ConsumerState<DispatchAssignmentScreen> {
  String? _selectedVendorId;
  String? _selectedVehicleId;
  String? _selectedDriverId;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final order = DispatcherOrder.fromJson(widget.rawOrder);
    final vendors = ref.watch(dispatcherVendorsProvider);
    return AppScaffold(
      title: 'Assign order',
      body: vendors.when(
        loading: () =>
            const LoadingState(message: 'Loading approved vendors...'),
        error: (error, _) => ErrorState(
          error: error,
          message: friendlyError(error),
          onRetry: () => ref.invalidate(dispatcherVendorsProvider),
        ),
        data: (allVendors) {
          final eligible = allVendors
              .where(
                (vendor) =>
                    vendor.status == 'approved' ||
                    vendor.data['verification'] == 'approved',
              )
              .toList();
          if (eligible.isEmpty) {
            return const NewUiEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No approved vendors available',
              message:
                  'An approved vendor is required before this order can be assigned.',
            );
          }
          final selectedId = eligible
              .firstWhere(
                (vendor) => vendor.id == _selectedVendorId,
                orElse: () => eligible.first,
              )
              .id;
          final selectedVendor = eligible.firstWhere(
            (vendor) => vendor.id == selectedId,
          );
          final fleet = ref.watch(dispatcherVendorDetailsProvider(selectedId));
          final selectedVehicleId =
              _selectedVehicleId ??
              (order.vendorId == selectedId ? order.vehicleId : null);
          final selectedDriverId =
              _selectedDriverId ??
              (order.vendorId == selectedId ? order.driverId : null);
          final fleetData = fleet.asData?.value.data;
          final vehicles = fleetData == null
              ? const <AdminFleetVehicle>[]
              : _approvedVehicles(
                  fleetData,
                ).where((item) => item.vendorId == selectedId).toList();
          final drivers = fleetData == null
              ? const <AdminFleetDriver>[]
              : _approvedDrivers(
                  fleetData,
                ).where((item) => item.vendorId == selectedId).toList();
          final validVehicleId =
              vehicles.any((item) => item.id == selectedVehicleId)
              ? selectedVehicleId
              : null;
          final validDriverId =
              drivers.any((item) => item.id == selectedDriverId)
              ? selectedDriverId
              : null;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppPageInsets.withSafeAreaBottom(
                    context,
                    AppPageInsets.standard,
                  ),
                  children: [
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.reference,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            '${StatusChip.statusLabel(order.status)} • '
                            '${order.address.isEmpty ? 'Address unavailable' : order.address}',
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            '${formatBookingDate(order.scheduledFor)} • '
                            '₹${order.amountRupees.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      'Select an approved vendor',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final vendor in eligible)
                      AppListRow(
                        leading: Icon(
                          vendor.id == selectedId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: context.colors.primary,
                        ),
                        title: vendor.title,
                        onTap: _isSubmitting
                            ? null
                            : () => setState(() {
                                _selectedVendorId = vendor.id;
                                _selectedVehicleId = null;
                                _selectedDriverId = null;
                              }),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Assign vehicle and driver',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      selectedVendor.title,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.md),
                    fleet.when(
                      loading: () => const LoadingState(
                        message: 'Loading this vendor’s approved fleet...',
                      ),
                      error: (error, _) => ErrorState(
                        error: error,
                        message: friendlyError(error),
                        onRetry: () => ref.invalidate(
                          dispatcherVendorDetailsProvider(selectedId),
                        ),
                      ),
                      data: (_) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: AppSpace.xs),
                            if (vehicles.isEmpty)
                              const SurfaceCard(
                                child: Text(
                                  'No approved vehicles for this vendor.',
                                ),
                              )
                            else
                              for (final vehicle in vehicles)
                                AppListRow(
                                  leading: Icon(
                                    vehicle.id == selectedVehicleId
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: context.colors.primary,
                                  ),
                                  title: vehicle.registrationNumber,
                                  subtitle:
                                      '${vehicle.capacityLitres} L capacity',
                                  onTap: _isSubmitting
                                      ? null
                                      : () => setState(
                                          () => _selectedVehicleId = vehicle.id,
                                        ),
                                ),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              'Driver',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: AppSpace.xs),
                            if (drivers.isEmpty)
                              const SurfaceCard(
                                child: Text(
                                  'No approved drivers for this vendor.',
                                ),
                              )
                            else
                              for (final driver in drivers)
                                AppListRow(
                                  leading: Icon(
                                    driver.id == selectedDriverId
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: context.colors.primary,
                                  ),
                                  title: driver.name,
                                  onTap: _isSubmitting
                                      ? null
                                      : () => setState(
                                          () => _selectedDriverId = driver.id,
                                        ),
                                ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: AppPageInsets.standard,
                  child: PrimaryButton(
                    label: _isSubmitting
                        ? 'Assigning...'
                        : 'Complete assignment',
                    icon: Icons.assignment_turned_in_outlined,
                    onPressed:
                        _isSubmitting ||
                            validVehicleId == null ||
                            validDriverId == null
                        ? null
                        : () => _assignOrder(
                            selectedId,
                            validVehicleId,
                            validDriverId,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignOrder(
    String vendorId,
    String vehicleId,
    String driverId,
  ) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(appControllerProvider)
          .api
          .dispatcherAssignOrder(
            widget.rawOrder['id'].toString(),
            vendorId: vendorId,
            vehicleId: vehicleId,
            driverId: driverId,
          );
      ref.invalidate(dispatcherOrdersProvider);
      if (!mounted) return;
      showAppSnack(
        context,
        'Order assigned.',
        variant: AppSnackVariant.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Assignment failed: ${friendlyError(error)}',
        variant: AppSnackVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<AdminFleetVehicle> _approvedVehicles(Map<String, dynamic> vendor) {
    final rows = vendor['vehicles'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => AdminFleetVehicle.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.eligible)
        .toList();
  }

  List<AdminFleetDriver> _approvedDrivers(Map<String, dynamic> vendor) {
    final rows = vendor['drivers'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => AdminFleetDriver.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.eligible)
        .toList();
  }
}
