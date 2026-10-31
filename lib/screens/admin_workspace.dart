import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../app/providers.dart';
import '../app/page_components.dart';
import '../models/account.dart';
import '../models/notification.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';

class AdminPulseScreen extends ConsumerWidget {
  const AdminPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(adminHealthProvider);
    return healthState.when(
      loading: () => const AppStateView.loading(),
      error: (error, _) => AppStateView.error(
        error: error,
        onRetry: () => ref.invalidate(adminHealthProvider),
      ),
      data: (health) {
        final migrations = health['migrations'] is List
            ? (health['migrations'] as List).whereType<Map>().toList()
            : const [];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminHealthProvider),
          child: ListView(
            padding: AppPageInsets.standard,
            children: [
              Text('Platform pulse',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _MetricTile(
                label: 'System status',
                value: health['ok'] == true ? 'Healthy' : 'Attention required',
                icon: health['ok'] == true
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              _MetricTile(
                label: 'Realtime',
                value: (health['realtime'] as Map?)?['connected'] == true
                    ? 'Connected'
                    : 'Unavailable',
                icon: Icons.radar_outlined,
              ),
              _MetricTile(
                label: 'Storage',
                value: (health['storage'] as Map?)?['configured'] == true
                    ? 'Configured'
                    : 'Not configured',
                icon: Icons.storage_outlined,
              ),
              const SizedBox(height: 12),
              const Text('Migration checks'),
              ...migrations.map(
                (item) => ListTile(
                  dense: true,
                  leading: Icon(
                    item['applied'] == true ? Icons.check : Icons.error_outline,
                  ),
                  title: Text((item['table'] ?? 'Table').toString()),
                  subtitle: Text(item['applied'] == true
                      ? 'Available'
                      : (item['error'] ?? 'Unavailable').toString()),
                  trailing: item['applied'] == true
                      ? null
                      : TextButton(
                          onPressed: () => ref.invalidate(adminHealthProvider),
                          child: const Text('Retry'),
                        ),
                ),
              ),
              if ((health['configuration'] as Map?)
                      ?.values
                      .any((value) => value != true) ==
                  true)
                const ListTile(
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Configuration warnings'),
                  subtitle:
                      Text('One or more integrations are not configured.'),
                ),
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    await ref
                        .read(appControllerProvider)
                        .api
                        .adminStorageCleanup();
                    ref.invalidate(adminHealthProvider);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cleanup failed: $error')),
                      );
                    }
                  }
                },
                child: const Text('Run storage cleanup'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminOperationsScreen extends ConsumerWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: AppPageInsets.standard,
      children: [
        _AdminGroup(
          title: 'Bookings & dispatch',
          icon: Icons.local_shipping_outlined,
          children: const [_AdminOrdersSection()],
        ),
        _AdminGroup(
          title: 'People & fleet',
          icon: Icons.groups_outlined,
          children: [
            _AdminRecordsSection(
              title: 'Vendors',
              icon: Icons.storefront_outlined,
              loader: (api) => api.adminVendors(),
              onVendorStatus: (record, status) async {
                await ref
                    .read(appControllerProvider)
                    .api
                    .updateVendorVerification(record.id, status);
              },
              onAdd: () => _createVendor(context, ref),
            ),
            _AdminRecordsSection(
              title: 'Customers',
              icon: Icons.people_outline,
              loader: (api) => api.adminCustomers(),
              onAdd: () => _createCustomer(context, ref),
            ),
            const _AdminFleetSection(),
          ],
        ),
        _AdminGroup(
          title: 'Finance & promos',
          icon: Icons.payments_outlined,
          children: [
            _AdminRecordsSection(
              title: 'Coupons',
              icon: Icons.local_offer_outlined,
              loader: (api) => api.adminCoupons(),
              onAdd: () => _createCoupon(context, ref),
            ),
            const _AdminPayoutsSection(),
            const _AdminPartnerSection(),
          ],
        ),
        _AdminGroup(
          title: 'Reports & setup',
          icon: Icons.settings_outlined,
          children: const [
            _AdminServicesSection(),
            _AdminNotificationSection(),
            _AdminAuditSection(),
          ],
        ),
      ],
    );
  }
}

class _AdminGroup extends StatelessWidget {
  const _AdminGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          children: children,
        ),
      );
}

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(dispatcherVendorsProvider);
    return vendors.when(
      loading: () => const AppStateView.loading(message: 'Loading reports...'),
      error: (error, _) => AppStateView.error(
        error: error,
        onRetry: () => ref.invalidate(dispatcherVendorsProvider),
      ),
      data: (items) {
        return ListView(
          padding: AppPageInsets.standard,
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _MetricTile(
              label: 'Registered vendors',
              value: '${items.length}',
              icon: Icons.storefront_outlined,
            ),
            _AdminReportForm(),
          ],
        );
      },
    );
  }
}

class _AdminOrdersSection extends ConsumerStatefulWidget {
  const _AdminOrdersSection();

  @override
  ConsumerState<_AdminOrdersSection> createState() =>
      _AdminOrdersSectionState();
}

class _AdminOrdersSectionState extends ConsumerState<_AdminOrdersSection> {
  String? status;
  int page = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Orders'),
        children: [
          DropdownButton<String?>(
            value: status,
            hint: const Text('All statuses'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'pending_vendor', child: Text('Pending')),
              DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
              DropdownMenuItem(value: 'en_route', child: Text('En route')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (value) => setState(() {
              status = value;
              page = 1;
            }),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: ref.read(appControllerProvider).api.adminOrders(
                  page: page,
                  status: status,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final rows = (snapshot.data?['rows'] as List?)
                      ?.whereType<Map>()
                      .toList() ??
                  const [];
              if (rows.isEmpty) {
                return const ListTile(title: Text('No orders found.'));
              }
              return Column(
                children: [
                  ...rows.map(
                    (row) => ListTile(
                      title: Text((row['reference'] ?? row['id']).toString()),
                      subtitle: Text(
                        '${row['status'] ?? ''}\n${row['address_text'] ?? ''}',
                      ),
                      isThreeLine: true,
                      onTap: () => _showOrder(context, row),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed:
                            page > 1 ? () => setState(() => page--) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Page $page'),
                      IconButton(
                        onPressed: rows.length >= 25
                            ? () => setState(() => page++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showOrder(BuildContext context, Map row) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('View booking details'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('Assign vendor and fleet'),
              onTap: () => Navigator.pop(context, 'assign'),
            ),
            if (row['status'] != 'cancelled' && row['status'] != 'delivered')
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel booking'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'details') {
      final details = <String, dynamic>{
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
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text((row['reference'] ?? 'Booking').toString()),
          content: SingleChildScrollView(
            child: Text(
              details.entries
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else if (action == 'assign') {
      await _assignOrder(context, row);
    } else if (action == 'cancel') {
      await _cancelOrder(context, row);
    }
  }

  Future<void> _assignOrder(BuildContext context, Map row) async {
    try {
      final api = ref.read(appControllerProvider).api;
      final vendors = (await api.adminVendors())
          .where((vendor) =>
              vendor.status.toLowerCase() == 'approved' ||
              vendor.data['verification']?.toString().toLowerCase() ==
                  'approved')
          .toList(growable: false);
      final vehicles = await api.adminVehicles();
      final drivers = await api.adminDrivers();
      if (!context.mounted) return;
      if (vendors.isEmpty) {
        _showMessage(context, 'No approved vendors are available.');
        return;
      }
      var selectedVendor = vendors
          .firstWhere(
            (vendor) => vendor.id == row['vendor_id'],
            orElse: () => vendors.first,
          )
          .id;
      String? selectedVehicle;
      String? selectedDriver;
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final eligibleVehicles = vehicles
                .where(
                    (item) => item.vendorId == selectedVendor && item.eligible)
                .toList(growable: false);
            final eligibleDrivers = drivers
                .where(
                    (item) => item.vendorId == selectedVendor && item.eligible)
                .toList(growable: false);
            final currentVehicles = eligibleVehicles
                .where((item) => item.id == row['vehicle_id'])
                .toList(growable: false);
            final currentDrivers = eligibleDrivers
                .where((item) => item.id == row['driver_id'])
                .toList(growable: false);
            selectedVehicle ??=
                currentVehicles.isEmpty ? null : currentVehicles.first.id;
            selectedDriver ??=
                currentDrivers.isEmpty ? null : currentDrivers.first.id;
            return AlertDialog(
              title: const Text('Assign booking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedVendor,
                    decoration:
                        const InputDecoration(labelText: 'Approved vendor'),
                    items: vendors
                        .map((vendor) => DropdownMenuItem(
                              value: vendor.id,
                              child: Text(vendor.title),
                            ))
                        .toList(growable: false),
                    onChanged: (value) => setDialogState(() {
                      selectedVendor = value ?? selectedVendor;
                      selectedVehicle = null;
                      selectedDriver = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicle,
                    decoration:
                        const InputDecoration(labelText: 'Eligible vehicle'),
                    items: eligibleVehicles
                        .map((vehicle) => DropdownMenuItem(
                              value: vehicle.id,
                              child: Text(vehicle.registrationNumber),
                            ))
                        .toList(growable: false),
                    onChanged: eligibleVehicles.isEmpty
                        ? null
                        : (value) =>
                            setDialogState(() => selectedVehicle = value),
                    validator: (value) => value == null
                        ? 'Select an approved active vehicle.'
                        : null,
                  ),
                  if (eligibleVehicles.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('This vendor has no eligible vehicles.'),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDriver,
                    decoration:
                        const InputDecoration(labelText: 'Eligible driver'),
                    items: eligibleDrivers
                        .map((driver) => DropdownMenuItem(
                              value: driver.id,
                              child: Text(driver.name),
                            ))
                        .toList(growable: false),
                    onChanged: eligibleDrivers.isEmpty
                        ? null
                        : (value) =>
                            setDialogState(() => selectedDriver = value),
                    validator: (value) => value == null
                        ? 'Select an approved active driver.'
                        : null,
                  ),
                  if (eligibleDrivers.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('This vendor has no eligible drivers.'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: eligibleVehicles.isEmpty ||
                          eligibleDrivers.isEmpty ||
                          selectedVehicle == null ||
                          selectedDriver == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        ),
      );
      if (saved != true || !context.mounted) return;
      await api.assignAdminOrder(
        row['id'].toString(),
        vendorId: selectedVendor,
        vehicleId: selectedVehicle,
        driverId: selectedDriver,
      );
      if (!context.mounted) return;
      setState(() {});
      _showMessage(context, 'Booking assigned.');
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Assignment failed: $error');
      }
    }
  }

  Future<void> _cancelOrder(BuildContext context, Map row) async {
    final formKey = GlobalKey<FormState>();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Cancellation reason',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Enter a cancellation reason.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(appControllerProvider)
          .api
          .cancelAdminOrder(row['id'].toString(), value);
      if (!context.mounted) return;
      setState(() {});
      _showMessage(context, 'Booking cancelled.');
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Cancellation failed: $error');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminServicesSection extends ConsumerStatefulWidget {
  const _AdminServicesSection();

  @override
  ConsumerState<_AdminServicesSection> createState() =>
      _AdminServicesSectionState();
}

class _AdminServicesSectionState extends ConsumerState<_AdminServicesSection> {
  late Future<List<AccountRecord>> _services;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _services = ref.read(appControllerProvider).api.adminServices();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: const Text('Services'),
          trailing: IconButton(
            tooltip: 'Add service',
            onPressed: () => _editService(context),
            icon: const Icon(Icons.add),
          ),
          children: [
            FutureBuilder<List<AccountRecord>>(
              future: _services,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return ListTile(
                    title: const Text('Services could not be loaded'),
                    subtitle: Text(snapshot.error.toString()),
                    trailing: IconButton(
                      tooltip: 'Retry',
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                    ),
                  );
                }
                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return ListTile(
                    title: const Text('No services configured.'),
                    trailing: TextButton(
                      onPressed: () => _editService(context),
                      child: const Text('Add service'),
                    ),
                  );
                }
                return Column(
                  children: records
                      .map(
                        (record) => ListTile(
                          title: Text(record.title),
                          subtitle: Text(
                            '${record.data['code'] ?? ''} • '
                            '${record.data['is_active'] == true ? 'Active' : 'Inactive'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit service options',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editService(context, record),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      );

  Future<void> _editService(
    BuildContext context, [
    AccountRecord? record,
  ]) async {
    final config = record?.data['config'] is Map
        ? Map<String, dynamic>.from(record!.data['config'] as Map)
        : const <String, dynamic>{};
    String optionText(String key) {
      final values = config[key];
      return values is List
          ? values.map((value) => value.toString()).join('\n')
          : '';
    }

    final code = TextEditingController(
      text: (record?.data['code'] ?? '').toString(),
    );
    final name = TextEditingController(
      text: (record?.data['name'] ?? '').toString(),
    );
    final price = TextEditingController(
      text: (record?.data['base_price_paise'] ?? '').toString(),
    );
    final capacities =
        TextEditingController(text: optionText('capacityOptions'));
    final details = TextEditingController(text: optionText('detailOptions'));
    final waterTypes =
        TextEditingController(text: optionText('waterTypeOptions'));
    final tankerCounts =
        TextEditingController(text: optionText('tankerCountOptions'));
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add service' : 'Edit service options'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: code,
                    readOnly: record != null,
                    decoration:
                        const InputDecoration(labelText: 'Service code'),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter a service code.'
                        : null,
                  ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter a service name.'
                        : null,
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Base price (paise)'),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      return parsed == null || parsed < 0
                          ? 'Enter a valid non-negative price.'
                          : null;
                    },
                  ),
                  _optionEditor(capacities, 'Capacity options'),
                  _optionEditor(details, 'Service detail options'),
                  _optionEditor(waterTypes, 'Water type options'),
                  _optionEditor(
                    tankerCounts,
                    'Tanker count options (1–5)',
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final counts = _parseOptionLines(tankerCounts.text);
                      if (counts.any(
                        (item) =>
                            !const ['1', '2', '3', '4', '5'].contains(item),
                      )) {
                        setDialogState(() {
                          error = 'Tanker counts must be between 1 and 5.';
                        });
                        return;
                      }
                      final body = <String, dynamic>{
                        if (record == null) 'code': code.text.trim(),
                        'name': name.text.trim(),
                        'basePricePaise': int.parse(price.text.trim()),
                        'capacityOptions': _parseOptionLines(capacities.text),
                        'detailOptions': _parseOptionLines(details.text),
                        'waterTypeOptions': _parseOptionLines(waterTypes.text),
                        'tankerCountOptions': counts,
                        if (record == null) 'isActive': true,
                      };
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final api = ref.read(appControllerProvider).api;
                        if (record == null) {
                          await api.createAdminService(body);
                        } else {
                          await api.updateAdminService(record.id, body);
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (value) {
                        setDialogState(() {
                          error = value.toString();
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      code,
      name,
      price,
      capacities,
      details,
      waterTypes,
      tankerCounts,
    ]) {
      controller.dispose();
    }
    if (saved == true && context.mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service configuration saved.')),
      );
    }
  }

  Widget _optionEditor(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: label,
          helperText: 'One option per line',
        ),
      );

  List<String> _parseOptionLines(String value) => value
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

class _AdminFleetSection extends ConsumerStatefulWidget {
  const _AdminFleetSection();

  @override
  ConsumerState<_AdminFleetSection> createState() => _AdminFleetSectionState();
}

class _AdminFleetSectionState extends ConsumerState<_AdminFleetSection> {
  late Future<List<AccountRecord>> _vendors;
  late Future<List<AdminFleetVehicle>> _vehicles;
  late Future<List<AdminFleetDriver>> _drivers;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = ref.read(appControllerProvider).api;
    _vendors = api.adminVendors();
    _vehicles = api.adminVehicles();
    _drivers = api.adminDrivers();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.local_shipping_outlined),
          title: const Text('Vehicles & drivers'),
          children: [
            _fleetList<AdminFleetVehicle>(
              context,
              title: 'Vehicles',
              future: _vehicles,
              label: (vehicle) =>
                  '${vehicle.registrationNumber} • ${vehicle.capacityLitres} L',
              detail: (vehicle) =>
                  '${vehicle.verification} • ${vehicle.active ? 'Active' : 'Inactive'}',
              trailing: (vehicle) => _fleetStatusMenu(
                vehicle.verification,
                vehicle.active,
                (verification, isActive) => _updateVehicleStatus(
                  vehicle.id,
                  verification,
                  isActive,
                ),
              ),
              onAdd: () => _showFleetForm(context, vehicle: true),
            ),
            _fleetList<AdminFleetDriver>(
              context,
              title: 'Drivers',
              future: _drivers,
              label: (driver) => driver.name,
              detail: (driver) => '${driver.mobile} • ${driver.verification} • '
                  '${driver.active ? 'Active' : 'Inactive'}',
              trailing: (driver) => _fleetStatusMenu(
                driver.verification,
                driver.active,
                (verification, isActive) => _updateDriverStatus(
                  driver.id,
                  verification,
                  isActive,
                ),
              ),
              onAdd: () => _showFleetForm(context, vehicle: false),
            ),
          ],
        ),
      );

  Widget _fleetList<T>(
    BuildContext context, {
    required String title,
    required Future<List<T>> future,
    required String Function(T) label,
    required String Function(T) detail,
    required Widget Function(T) trailing,
    required VoidCallback onAdd,
  }) =>
      ExpansionTile(
        title: Text(title),
        trailing: IconButton(
          tooltip: 'Add $title',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
        children: [
          FutureBuilder<List<T>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('$title could not be loaded'),
                  subtitle: Text(snapshot.error.toString()),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh),
                  ),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return ListTile(
                  title: Text('No $title found.'),
                  trailing: TextButton(
                    onPressed: onAdd,
                    child: Text('Add ${title.substring(0, title.length - 1)}'),
                  ),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        title: Text(label(item)),
                        subtitle: Text(detail(item)),
                        trailing: trailing(item),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      );

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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fleet status updated.')),
              );
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fleet status update failed: $error')),
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
        icon: const Icon(Icons.more_vert),
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

  Future<void> _showFleetForm(
    BuildContext context, {
    required bool vehicle,
  }) async {
    late final List<AccountRecord> vendors;
    try {
      vendors = await _vendors;
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Could not load vendors: $error');
      }
      return;
    }
    final approvedVendors = vendors
        .where((vendor) =>
            vendor.status.toLowerCase() == 'approved' ||
            vendor.data['verification']?.toString().toLowerCase() == 'approved')
        .toList(growable: false);
    if (!context.mounted) return;
    if (approvedVendors.isEmpty) {
      _showMessage(context, 'Add or approve a vendor before adding fleet.');
      return;
    }

    final name = TextEditingController();
    final mobile = TextEditingController();
    final licence = TextEditingController();
    final capacity = TextEditingController();
    var selectedVendor = approvedVendors.first.id;
    var saving = false;
    String? error;
    final formKey = GlobalKey<FormState>();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(vehicle ? 'Add vehicle' : 'Add driver'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedVendor,
                    decoration: const InputDecoration(labelText: 'Vendor'),
                    items: approvedVendors
                        .map((vendor) => DropdownMenuItem(
                              value: vendor.id,
                              child: Text(vendor.title),
                            ))
                        .toList(growable: false),
                    onChanged: (value) =>
                        selectedVendor = value ?? selectedVendor,
                  ),
                  if (vehicle) ...[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                          labelText: 'Registration number'),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter a valid registration number.'
                          : null,
                    ),
                    TextFormField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Capacity (litres)'),
                      validator: (value) {
                        final amount = int.tryParse(value?.trim() ?? '');
                        return amount == null || amount < 1
                            ? 'Enter a positive capacity.'
                            : null;
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Driver name'),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter the driver name.'
                          : null,
                    ),
                    TextFormField(
                      controller: mobile,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: '10-digit mobile number',
                      ),
                      validator: (value) => RegExp(r'^\d{10}$').hasMatch(
                        normalizeIndianPhone(value ?? ''),
                      )
                          ? null
                          : 'Enter a valid 10-digit mobile number.',
                    ),
                    TextFormField(
                      controller: licence,
                      decoration:
                          const InputDecoration(labelText: 'Licence number'),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter a valid licence number.'
                          : null,
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final api = ref.read(appControllerProvider).api;
                        if (vehicle) {
                          await api.createAdminVehicle(
                            vendorId: selectedVendor,
                            registrationNumber: name.text.trim(),
                            capacityLitres: int.parse(capacity.text.trim()),
                          );
                        } else {
                          await api.createAdminDriver(
                            vendorId: selectedVendor,
                            name: name.text.trim(),
                            mobile: mobile.text.trim(),
                            licenceNumber: licence.text.trim(),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (value) {
                        setDialogState(() {
                          error = value.toString();
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    mobile.dispose();
    licence.dispose();
    capacity.dispose();
    if (created == true && context.mounted) {
      setState(_reload);
      _showMessage(context, '${vehicle ? 'Vehicle' : 'Driver'} added.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminPayoutsSection extends ConsumerWidget {
  const _AdminPayoutsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSimpleRecords(
        title: 'Payouts',
        icon: Icons.payments_outlined,
        loader: (api) => api.adminPayouts(),
      );
}

class _AdminPartnerSection extends ConsumerWidget {
  const _AdminPartnerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSimpleRecords(
        title: 'Partner applications',
        icon: Icons.handshake_outlined,
        loader: (api) => api.adminPartnerApplications(),
      );
}

class _AdminNotificationSection extends ConsumerStatefulWidget {
  const _AdminNotificationSection();

  @override
  ConsumerState<_AdminNotificationSection> createState() =>
      _AdminNotificationSectionState();
}

class _AdminNotificationSectionState
    extends ConsumerState<_AdminNotificationSection> {
  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Send customer notification'),
              onTap: () async {
                final customer = TextEditingController();
                final title = TextEditingController();
                final detail = TextEditingController();
                await _adminForm(
                  context,
                  title: 'Send notification',
                  fields: [
                    ('Customer ID', customer),
                    ('Title', title),
                    ('Message', detail)
                  ],
                  submit: () => ref
                      .read(appControllerProvider)
                      .api
                      .sendAdminNotification({
                    'customerId': customer.text.trim(),
                    'title': title.text.trim(),
                    'detail': detail.text.trim(),
                  }),
                );
                customer.dispose();
                title.dispose();
                detail.dispose();
              },
            ),
            FutureBuilder<List<NotificationItem>>(
              future: ref.read(appControllerProvider).api.adminNotifications(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                final groups = groupNotifications(items);
                return ExpansionTile(
                  title: const Text('Admin inbox'),
                  children: groups.isEmpty
                      ? [const ListTile(title: Text('No admin notifications.'))]
                      : groups
                          .map(
                            (group) => ExpansionTile(
                              title: Text(group.title),
                              subtitle: Text(
                                '${group.items.length} event(s)'
                                '${group.unreadItems.isEmpty ? '' : ' • ${group.unreadItems.length} unread'}',
                              ),
                              trailing: group.unreadItems.isEmpty
                                  ? null
                                  : TextButton(
                                      onPressed: () async {
                                        try {
                                          for (final item
                                              in group.unreadItems) {
                                            await ref
                                                .read(appControllerProvider)
                                                .api
                                                .markAdminNotificationRead(
                                                    item.id);
                                          }
                                          if (mounted) setState(() {});
                                        } catch (error) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not mark notifications as read: $error',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Mark as read'),
                                    ),
                              children: group.items
                                  .map(
                                    (item) => ListTile(
                                      title: Text(item.title),
                                      subtitle: Text([
                                        if (item.status != null)
                                          'Status: ${item.status}',
                                        item.message,
                                        if (item.createdAt != null)
                                          item.createdAt!
                                              .toLocal()
                                              .toString()
                                              .substring(0, 16),
                                      ]
                                          .where((part) => part.isNotEmpty)
                                          .join('\n')),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          )
                          .toList(),
                );
              },
            ),
          ],
        ),
      );
}

class _AdminAuditSection extends ConsumerStatefulWidget {
  const _AdminAuditSection();

  @override
  ConsumerState<_AdminAuditSection> createState() => _AdminAuditSectionState();
}

class _AdminAuditSectionState extends ConsumerState<_AdminAuditSection> {
  int page = 1;
  String action = '';
  String entityType = '';

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.history_outlined),
          title: const Text('Audit logs'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Action'),
                      onChanged: (value) => setState(() => action = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Entity'),
                      onChanged: (value) => setState(() => entityType = value),
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: ref.read(appControllerProvider).api.adminAuditLogs(
                    page: page,
                    action: action,
                    entityType: entityType,
                  ),
              builder: (context, snapshot) {
                final rows = (snapshot.data?['rows'] as List?)
                        ?.whereType<Map>()
                        .toList() ??
                    const [];
                return Column(
                  children: [
                    ...rows.map(
                      (row) => ListTile(
                        title: Text(
                            '${row['action'] ?? ''} • ${row['entity_type'] ?? ''}'),
                        subtitle: Text((row['metadata'] ?? '').toString()),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed:
                              page > 1 ? () => setState(() => page--) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $page'),
                        IconButton(
                          onPressed: rows.length >= 50
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _AdminSimpleRecords extends ConsumerWidget {
  const _AdminSimpleRecords({
    required this.title,
    required this.icon,
    required this.loader,
  });

  final String title;
  final IconData icon;
  final Future<List<AccountRecord>> Function(dynamic api) loader;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(title),
          children: [
            FutureBuilder<List<AccountRecord>>(
              future: loader(ref.read(appControllerProvider).api),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  );
                }
                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return const ListTile(title: Text('No records found.'));
                }
                return Column(
                  children: records
                      .map((record) => ListTile(
                            title: Text(record.title),
                            subtitle: Text(record.detail),
                            trailing: Text(record.status),
                            onTap: () => _showAdminRecord(context, record),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
}

void _showAdminRecord(BuildContext context, AccountRecord record) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(record.title),
      content: SingleChildScrollView(
        child: Text(record.data.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    ),
  );
}

Future<void> _adminForm(
  BuildContext context, {
  required String title,
  required List<(String, TextEditingController)> fields,
  required Future<void> Function() submit,
}) async {
  final formKey = GlobalKey<FormState>();
  var saving = false;
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  TextFormField(
                    controller: field.$2,
                    decoration: InputDecoration(labelText: field.$1),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter ${field.$1.toLowerCase()}.',
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                saving ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setDialogState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await submit();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (value) {
                      setDialogState(() {
                        error = value.toString();
                        saving = false;
                      });
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title completed successfully.')),
    );
  }
}

class _AdminReportForm extends ConsumerStatefulWidget {
  const _AdminReportForm();

  @override
  ConsumerState<_AdminReportForm> createState() => _AdminReportFormState();
}

class _AdminReportFormState extends ConsumerState<_AdminReportForm> {
  Map<String, dynamic>? report;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.filter_alt_outlined),
          title: const Text('Filtered report'),
          children: [
            FilledButton(
              onPressed: () async {
                final today = DateTime.now().toIso8601String().split('T').first;
                try {
                  final value =
                      await ref.read(appControllerProvider).api.adminReport({
                    'type': 'revenue',
                    'from': today,
                    'to': today,
                  });
                  if (mounted) setState(() => report = value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Run today report'),
            ),
            if (report != null)
              ListTile(
                title: Text('Total: ₹${report!['total'] ?? 0}'),
                subtitle:
                    Text('Rows: ${(report!['rows'] as List?)?.length ?? 0}'),
                trailing: IconButton(
                  tooltip: 'Share report',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => Share.share(
                    'Urban Tanker report\n'
                    'Total: ₹${report!['total'] ?? 0}\n'
                    'Rows: ${(report!['rows'] as List?)?.length ?? 0}',
                  ),
                ),
              ),
          ],
        ),
      );
}

class _AdminRecordsSection extends ConsumerWidget {
  const _AdminRecordsSection({
    required this.title,
    required this.icon,
    required this.loader,
    this.onVendorStatus,
    this.onAdd,
  });

  final String title;
  final IconData icon;
  final Future<List<AccountRecord>> Function(dynamic api) loader;
  final Future<void> Function(AccountRecord record, String status)?
      onVendorStatus;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: title == 'Vendors',
        leading: Icon(icon),
        title: Text(title),
        trailing: onAdd == null
            ? null
            : IconButton(onPressed: onAdd, icon: const Icon(Icons.add)),
        children: [
          FutureBuilder<List<AccountRecord>>(
            future: loader(ref.read(appControllerProvider).api),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('Could not load $title'),
                  subtitle: Text(snapshot.error.toString()),
                );
              }
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return const ListTile(title: Text('No records found.'));
              }
              return Column(
                children: records
                    .map(
                      (record) => ListTile(
                        title: Text(record.title),
                        subtitle: Text(record.detail),
                        onTap: () => _showAdminRecord(context, record),
                        trailing: onVendorStatus == null
                            ? Text(record.status)
                            : PopupMenuButton<String>(
                                onSelected: (status) async {
                                  await onVendorStatus!(record, status);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'approved',
                                      child: Text('Approve')),
                                  PopupMenuItem(
                                      value: 'suspended',
                                      child: Text('Suspend')),
                                  PopupMenuItem(
                                      value: 'rejected', child: Text('Reject')),
                                ],
                              ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _createVendor(BuildContext context, WidgetRef ref) async {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final business = TextEditingController();
  final zone = TextEditingController();
  await _adminForm(
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
}

Future<void> _createCustomer(BuildContext context, WidgetRef ref) async {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  await _adminForm(
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
}

Future<void> _createCoupon(BuildContext context, WidgetRef ref) async {
  final code = TextEditingController();
  final label = TextEditingController();
  final discount = TextEditingController();
  final expires = TextEditingController();
  await _adminForm(
    context,
    title: 'Create coupon',
    fields: [
      ('Code', code),
      ('Label', label),
      ('Discount (10% or 100)', discount),
      ('Expiry (YYYY-MM-DD)', expires),
    ],
    submit: () {
      final expiry = DateTime.tryParse(expires.text.trim());
      if (expiry == null || expiry.isBefore(DateTime.now())) {
        throw const FormatException('Enter a valid future expiry date.');
      }
      return ref.read(appControllerProvider).api.createAdminCoupon({
        'code': code.text.trim(),
        'label': label.text.trim(),
        'discount': discount.text.trim(),
        'expires': expires.text.trim(),
        'active': true,
      });
    },
  );
  for (final controller in [code, label, discount, expires]) {
    controller.dispose();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value),
        ),
      );
}
