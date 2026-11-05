import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../models/vendor.dart';
import '../../../services/api_client.dart';
import '../../../services/friendly_error.dart';
import 'admin_common.dart';

const _peopleTabs = ['Vendors', 'Customers', 'Vehicles', 'Drivers'];

/// Admin people and fleet: vendors, customers, vehicles and drivers. Each list
/// has search, and vendors and fleet items have status actions.
class AdminPeopleSection extends ConsumerStatefulWidget {
  const AdminPeopleSection({super.key});

  @override
  ConsumerState<AdminPeopleSection> createState() => _AdminPeopleSectionState();
}

class _AdminPeopleSectionState extends ConsumerState<AdminPeopleSection> {
  final _search = TextEditingController();
  int _tab = 0;
  String _query = '';
  late Future<List<AccountRecord>> _vendors;
  late Future<List<AccountRecord>> _customers;
  late Future<List<AdminFleetVehicle>> _vehicles;
  late Future<List<AdminFleetDriver>> _drivers;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final api = ref.read(appControllerProvider).api;
    _vendors = api.adminVendors();
    _customers = api.adminCustomers();
    _vehicles = api.adminVehicles();
    _drivers = api.adminDrivers();
  }

  bool _matches(String title, String detail) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        detail.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppPageInsets.withSafeAreaBottom(
        context,
        AppPageInsets.standard,
      ),
      children: [
        SegmentedTabs(
          labels: _peopleTabs,
          selectedIndex: _tab,
          onChanged: (index) => setState(() {
            _tab = index;
            _query = '';
            _search.clear();
          }),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: AdminSearchField(
                controller: _search,
                label: 'Search ${_peopleTabs[_tab].toLowerCase()}',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        PrimaryButton(
          label: _addLabel,
          icon: Icons.add,
          expand: false,
          onPressed: _add,
        ),
        const SizedBox(height: AppSpace.md),
        switch (_tab) {
          0 => _vendorList(),
          1 => _customerList(),
          2 => _vehicleList(),
          _ => _driverList(),
        },
      ],
    );
  }

  String get _addLabel => switch (_tab) {
        0 => 'Create vendor',
        1 => 'Create customer',
        2 => 'Add vehicle',
        _ => 'Add driver',
      };

  void _add() {
    switch (_tab) {
      case 0:
        _createVendor();
      case 1:
        _createCustomer();
      case 2:
        _showFleetForm(vehicle: true);
      default:
        _showFleetForm(vehicle: false);
    }
  }

  Widget _vendorList() => _ListBody<AccountRecord>(
        future: _vendors,
        onRetry: () => setState(_reload),
        emptyText: 'No vendors found.',
        filter: (vendor) => _matches(vendor.title, vendor.detail),
        row: (vendor) => AdminRecordRow(
          record: vendor,
          trailing: PopupMenuButton<String>(
            tooltip: 'Update vendor status',
            onSelected: (status) => _setVendorStatus(vendor, status),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'approved', child: Text('Approve')),
              PopupMenuItem(value: 'suspended', child: Text('Suspend')),
              PopupMenuItem(value: 'rejected', child: Text('Reject')),
            ],
          ),
        ),
      );

  Widget _customerList() => _ListBody<AccountRecord>(
        future: _customers,
        onRetry: () => setState(_reload),
        emptyText: 'No customers found.',
        filter: (customer) => _matches(customer.title, customer.detail),
        row: (customer) => AdminRecordRow(record: customer),
      );

  Widget _vehicleList() => _ListBody<AdminFleetVehicle>(
        future: _vehicles,
        onRetry: () => setState(_reload),
        emptyText: 'No vehicles found.',
        filter: (vehicle) => _matches(
          vehicle.registrationNumber,
          vehicle.verification,
        ),
        row: (vehicle) => SurfaceCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: vehicle.registrationNumber,
            subtitle: '${vehicle.capacityLitres} L • ${vehicle.verification} • '
                '${vehicle.active ? 'Active' : 'Inactive'}',
            trailing: _fleetStatusMenu(
              vehicle.verification,
              vehicle.active,
              (verification, isActive) => _updateVehicleStatus(
                vehicle.id,
                verification,
                isActive,
              ),
            ),
          ),
        ),
      );

  Widget _driverList() => _ListBody<AdminFleetDriver>(
        future: _drivers,
        onRetry: () => setState(_reload),
        emptyText: 'No drivers found.',
        filter: (driver) => _matches(driver.name, driver.mobile),
        row: (driver) => SurfaceCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: driver.name,
            subtitle: '${driver.mobile} • ${driver.verification} • '
                '${driver.active ? 'Active' : 'Inactive'}',
            trailing: _fleetStatusMenu(
              driver.verification,
              driver.active,
              (verification, isActive) => _updateDriverStatus(
                driver.id,
                verification,
                isActive,
              ),
            ),
          ),
        ),
      );

  Future<void> _setVendorStatus(AccountRecord vendor, String status) async {
    try {
      await ref
          .read(appControllerProvider)
          .api
          .updateVendorVerification(vendor.id, status);
      if (!mounted) return;
      setState(_reload);
      showAppSnack(
        context,
        'Vendor ${status == 'approved' ? 'approved' : status}.',
        variant: AppSnackVariant.success,
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Vendor update failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Widget _fleetStatusMenu(
    String verification,
    bool active,
    Future<void> Function(String verification, bool isActive) onSelected,
  ) =>
      PopupMenuButton<(String, bool)>(
        tooltip: 'Update fleet status',
        onSelected: (value) async {
          try {
            await onSelected(value.$1, value.$2);
            if (mounted) {
              setState(_reload);
              showAppSnack(
                context,
                'Fleet status updated.',
                variant: AppSnackVariant.success,
              );
            }
          } catch (error) {
            if (mounted) {
              showAppSnack(
                context,
                'Fleet status update failed: $error',
                variant: AppSnackVariant.error,
              );
            }
          }
        },
        itemBuilder: (_) => [
          if (!active || verification.toLowerCase() != 'approved')
            const PopupMenuItem(
              value: ('approved', true),
              child: Text('Approve and activate'),
            ),
          if (active || verification.toLowerCase() != 'suspended')
            const PopupMenuItem(
              value: ('suspended', false),
              child: Text('Suspend and deactivate'),
            ),
        ],
      );

  Future<void> _updateVehicleStatus(
    String id,
    String verification,
    bool isActive,
  ) =>
      ref.read(appControllerProvider).api.updateAdminVehicleStatus(
            id,
            verification: verification,
            isActive: isActive,
          );

  Future<void> _updateDriverStatus(
    String id,
    String verification,
    bool isActive,
  ) =>
      ref.read(appControllerProvider).api.updateAdminDriverStatus(
            id,
            verification: verification,
            isActive: isActive,
          );

  Future<void> _createVendor() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    final business = TextEditingController();
    final zone = TextEditingController();
    await adminForm(
      context,
      title: 'Create vendor',
      fields: [
        ('Email', email),
        ('Password', password),
        ('Contact name', name),
        ('10-digit phone', phone),
        ('Business name', business),
        ('Service zone', zone),
      ],
      submit: () => ref.read(appControllerProvider).api.createAdminVendor({
        'email': email.text.trim(),
        'password': password.text,
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'businessName': business.text.trim(),
        'serviceZone': zone.text.trim(),
      }),
    );
    for (final controller in [email, password, name, phone, business, zone]) {
      controller.dispose();
    }
    if (mounted) setState(_reload);
  }

  Future<void> _createCustomer() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    await adminForm(
      context,
      title: 'Create customer',
      fields: [
        ('Email', email),
        ('Password', password),
        ('Name', name),
        ('10-digit phone', phone),
      ],
      submit: () => ref.read(appControllerProvider).api.createAdminCustomer({
        'email': email.text.trim(),
        'password': password.text,
        'name': name.text.trim(),
        'phone': phone.text.trim(),
      }),
    );
    for (final controller in [email, password, name, phone]) {
      controller.dispose();
    }
    if (mounted) setState(_reload);
  }

  /// Vehicle or driver form. Only approved vendors can own fleet.
  Future<void> _showFleetForm({required bool vehicle}) async {
    final api = ref.read(appControllerProvider).api;
    final List<AccountRecord> vendors;
    try {
      vendors = (await api.adminVendors())
          .where((vendor) =>
              vendor.status.toLowerCase() == 'approved' ||
              vendor.data['verification']?.toString().toLowerCase() ==
                  'approved')
          .toList(growable: false);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not load vendors: $error',
          variant: AppSnackVariant.error,
        );
      }
      return;
    }
    if (!mounted) return;
    if (vendors.isEmpty) {
      showAppSnack(
        context,
        'Add or approve a vendor before adding fleet.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    final created = await showAppBottomSheet<bool>(
      context,
      builder: (_) => _FleetFormSheet(vendors: vendors, vehicle: vehicle),
    );
    if (created == true && mounted) {
      setState(_reload);
      showAppSnack(
        context,
        '${vehicle ? 'Vehicle' : 'Driver'} added.',
        variant: AppSnackVariant.success,
      );
    }
  }
}

/// A list body for one people tab. Loading, error and empty states replace the
/// rows. Rows are built lazily.
class _ListBody<T> extends StatelessWidget {
  const _ListBody({
    required this.future,
    required this.onRetry,
    required this.emptyText,
    required this.filter,
    required this.row,
  });

  final Future<List<T>> future;
  final VoidCallback onRetry;
  final String emptyText;
  final bool Function(T item) filter;
  final Widget Function(T item) row;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState(message: 'Loading...');
          }
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error!,
              onRetry: onRetry,
            );
          }
          final items =
              (snapshot.data ?? <T>[]).where(filter).toList(growable: false);
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: emptyText,
            );
          }
          return Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: row(item),
                ),
            ],
          );
        },
      );
}

/// Vehicle or driver form: an approved vendor, then the record's details.
class _FleetFormSheet extends ConsumerStatefulWidget {
  const _FleetFormSheet({required this.vendors, required this.vehicle});

  final List<AccountRecord> vendors;
  final bool vehicle;

  @override
  ConsumerState<_FleetFormSheet> createState() => _FleetFormSheetState();
}

class _FleetFormSheetState extends ConsumerState<_FleetFormSheet> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _licence = TextEditingController();
  final _capacity = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _vendor = widget.vendors.first.id;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _licence.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(appControllerProvider).api;
      if (widget.vehicle) {
        await api.createAdminVehicle(
          vendorId: _vendor,
          registrationNumber: _name.text.trim(),
          capacityLitres: int.parse(_capacity.text.trim()),
        );
      } else {
        await api.createAdminDriver(
          vendorId: _vendor,
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
          licenceNumber: _licence.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          _error = friendlyError(value);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.vehicle ? 'Add vehicle' : 'Add driver',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.lg),
                DropdownButtonFormField<String>(
                  initialValue: _vendor,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: [
                    for (final vendor in widget.vendors)
                      DropdownMenuItem(
                        value: vendor.id,
                        child: Text(vendor.title),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _vendor = value ?? _vendor),
                ),
                const SizedBox(height: AppSpace.md),
                if (widget.vehicle) ...[
                  AppTextField(
                    controller: _name,
                    label: 'Registration number',
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Enter a valid registration number.'
                        : null,
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _capacity,
                    label: 'Capacity (litres)',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      return amount == null || amount < 1
                          ? 'Enter a positive capacity.'
                          : null;
                    },
                  ),
                ] else ...[
                  AppTextField(
                    controller: _name,
                    label: 'Driver name',
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter the driver name.'
                        : null,
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _mobile,
                    label: '10-digit mobile number',
                    keyboardType: TextInputType.phone,
                    validator: (value) => RegExp(r'^\d{10}$').hasMatch(
                      normalizeIndianPhone(value ?? ''),
                    )
                        ? null
                        : 'Enter a valid 10-digit mobile number.',
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppTextField(
                    controller: _licence,
                    label: 'Licence number',
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Enter a valid licence number.'
                        : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _error!,
                    style: TextStyle(color: context.colors.danger.fg),
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Save',
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
