import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../models/vendor.dart';
import '../../../services/friendly_error.dart';
import 'admin_common.dart';

const _orderStatuses = <(String, String?)>[
  ('All', null),
  ('Pending', 'pending_vendor'),
  ('Accepted', 'accepted'),
  ('En route', 'en_route'),
  ('Delivered', 'delivered'),
  ('Cancelled', 'cancelled'),
];

/// Admin orders: filter by status, search the page, and act on one order from
/// its details sheet.
class AdminOrdersSection extends ConsumerStatefulWidget {
  const AdminOrdersSection({super.key});

  @override
  ConsumerState<AdminOrdersSection> createState() => _AdminOrdersSectionState();
}

class _AdminOrdersSectionState extends ConsumerState<AdminOrdersSection> {
  final _search = TextEditingController();
  String? _status;
  int _page = 1;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(
      dispatcherOrdersProvider(
        DispatcherOrderFilter(page: _page, status: _status),
      ),
    );
    return orders.when(
      loading: () => const LoadingState(message: 'Loading orders...'),
      error: (error, _) => ErrorState(
        error: error,
        message: friendlyError(error),
        onRetry: () => ref.invalidate(dispatcherOrdersProvider),
      ),
      data: (page) {
        final all =
            (page['rows'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
        final rows = [
          for (final row in all)
            if (_matches(row)) row,
        ];
        return ListView(
          padding: AppPageInsets.withSafeAreaBottom(
            context,
            AppPageInsets.standard,
          ),
          children: [
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final (label, value) in _orderStatuses)
                  ChoiceChip(
                    label: Text(label),
                    selected: _status == value,
                    onSelected: (_) => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            AdminSearchField(
              controller: _search,
              label: 'Search this page',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpace.md),
            if (all.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders found.',
              )
            else if (rows.isEmpty)
              const EmptyState(
                icon: Icons.search_off_outlined,
                title: 'No orders match this search.',
              )
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: AppListRow(
                      title: (row['reference'] ?? row['id']).toString(),
                      subtitle:
                          '${row['status'] ?? ''}\n${row['address_text'] ?? ''}',
                      onTap: () => _openOrder(row),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpace.sm),
            AdminPager(
              page: _page,
              hasNext: all.length >= 25,
              onPage: (value) => setState(() => _page = value),
            ),
          ],
        );
      },
    );
  }

  bool _matches(Map row) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      (row['reference'] ?? '').toString(),
      (row['id'] ?? '').toString(),
      (row['address_text'] ?? '').toString(),
    ].any((value) => value.toLowerCase().contains(query));
  }

  void _openOrder(Map row) {
    final cancellable =
        row['status'] != 'cancelled' && row['status'] != 'delivered';
    showDetailSheet<void>(
      context,
      title: (row['reference'] ?? 'Booking').toString(),
      message: _details(row)
          .entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
      actions: [
        SecondaryButton(
          label: 'Assign vendor and fleet',
          icon: Icons.assignment_ind_outlined,
          onPressed: () {
            Navigator.pop(context);
            _assignOrder(row);
          },
        ),
        if (cancellable) ...[
          const SizedBox(height: AppSpace.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.danger.fg,
              side: BorderSide(color: context.colors.danger.border),
              minimumSize: const Size(64, AppSize.buttonHeight),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel booking'),
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(row);
            },
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _details(Map row) => {
        'Reference': row['reference'] ?? row['id'],
        'Status': row['status'] ?? '—',
        'Service': row['service_code'] ?? '—',
        'Address': row['address_text'] ?? '—',
        'Coordinates': row['latitude'] == null || row['longitude'] == null
            ? 'Not provided'
            : '${row['latitude']}, ${row['longitude']}',
        'Delivery date': row['scheduled_for'] ?? '—',
        'Cancellation reason':
            row['cancellation_reason'] ?? row['cancellationReason'] ?? '—',
        'Vendor': row['vendor_id'] ?? 'Unassigned',
        'Vehicle': row['vehicle_id'] ?? 'Unassigned',
        'Driver': row['driver_id'] ?? 'Unassigned',
      };

  Future<void> _assignOrder(Map row) async {
    final api = ref.read(appControllerProvider).api;
    try {
      final vendors = (await api.adminVendors())
          .where((vendor) =>
              vendor.status.toLowerCase() == 'approved' ||
              vendor.data['verification']?.toString().toLowerCase() ==
                  'approved')
          .toList(growable: false);
      final vehicles = await api.adminVehicles();
      final drivers = await api.adminDrivers();
      if (!mounted) return;
      if (vendors.isEmpty) {
        showAppSnack(
          context,
          'No approved vendors are available.',
          variant: AppSnackVariant.error,
        );
        return;
      }
      final saved = await showAppBottomSheet<_Assignment>(
        context,
        builder: (_) => _AssignSheet(
          row: row,
          vendors: vendors,
          vehicles: vehicles,
          drivers: drivers,
        ),
      );
      if (saved == null || !mounted) return;
      await api.assignAdminOrder(
        row['id'].toString(),
        vendorId: saved.vendorId,
        vehicleId: saved.vehicleId,
        driverId: saved.driverId,
      );
      ref.invalidate(dispatcherOrdersProvider);
      if (!mounted) return;
      showAppSnack(
        context,
        'Booking assigned.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Assignment failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Future<void> _cancelOrder(Map row) async {
    final reason = await showAppBottomSheet<String>(
      context,
      builder: (_) => const _CancelOrderSheet(),
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(appControllerProvider)
          .api
          .cancelAdminOrder(row['id'].toString(), reason);
      ref.invalidate(dispatcherOrdersProvider);
      if (!mounted) return;
      showAppSnack(
        context,
        'Booking cancelled.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Cancellation failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }
}

/// The vendor, vehicle and driver chosen for an order.
class _Assignment {
  const _Assignment({
    required this.vendorId,
    this.vehicleId,
    this.driverId,
  });

  final String vendorId;
  final String? vehicleId;
  final String? driverId;
}

/// Assign sheet. Vehicles and drivers are limited to the chosen vendor and to
/// the approved, active ones.
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({
    required this.row,
    required this.vendors,
    required this.vehicles,
    required this.drivers,
  });

  final Map row;
  final List<AccountRecord> vendors;
  final List<AdminFleetVehicle> vehicles;
  final List<AdminFleetDriver> drivers;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late String _vendor = widget.vendors
      .firstWhere(
        (vendor) => vendor.id == widget.row['vendor_id'],
        orElse: () => widget.vendors.first,
      )
      .id;
  String? _vehicle;
  String? _driver;

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.vehicles
        .where((item) => item.vendorId == _vendor && item.eligible)
        .toList(growable: false);
    final drivers = widget.drivers
        .where((item) => item.vendorId == _vendor && item.eligible)
        .toList(growable: false);
    // Keep the order's current vehicle or driver selected when it is eligible.
    _vehicle ??= vehicles
        .where((item) => item.id == widget.row['vehicle_id'])
        .map((item) => item.id)
        .firstOrNull;
    _driver ??= drivers
        .where((item) => item.id == widget.row['driver_id'])
        .map((item) => item.id)
        .firstOrNull;
    final ready = vehicles.isNotEmpty &&
        drivers.isNotEmpty &&
        _vehicle != null &&
        _driver != null;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign booking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            DropdownButtonFormField<String>(
              initialValue: _vendor,
              decoration: const InputDecoration(labelText: 'Approved vendor'),
              items: [
                for (final vendor in widget.vendors)
                  DropdownMenuItem(value: vendor.id, child: Text(vendor.title)),
              ],
              onChanged: (value) => setState(() {
                _vendor = value ?? _vendor;
                _vehicle = null;
                _driver = null;
              }),
            ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _vehicle,
              decoration: const InputDecoration(labelText: 'Eligible vehicle'),
              items: [
                for (final vehicle in vehicles)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(vehicle.registrationNumber),
                  ),
              ],
              onChanged: vehicles.isEmpty
                  ? null
                  : (value) => setState(() => _vehicle = value),
            ),
            if (vehicles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  'This vendor has no eligible vehicles.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _driver,
              decoration: const InputDecoration(labelText: 'Eligible driver'),
              items: [
                for (final driver in drivers)
                  DropdownMenuItem(value: driver.id, child: Text(driver.name)),
              ],
              onChanged: drivers.isEmpty
                  ? null
                  : (value) => setState(() => _driver = value),
            ),
            if (drivers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  'This vendor has no eligible drivers.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Assign',
                    onPressed: ready
                        ? () => Navigator.pop(
                              context,
                              _Assignment(
                                vendorId: _vendor,
                                vehicleId: _vehicle,
                                driverId: _driver,
                              ),
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cancellation reason sheet. Pops the reason, which must be at least two
/// characters.
class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet();

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cancel booking',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.lg),
              AppTextField(
                controller: _reason,
                label: 'Cancellation reason',
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a cancellation reason.'
                    : null,
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Keep booking',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Cancel booking',
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(context, _reason.text.trim());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
