import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';

class VendorOperationsScreen extends ConsumerWidget {
  const VendorOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(vendorOrdersProvider);
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorOrdersProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorOrdersProvider),
        child: items.isEmpty
            ? ListView(
                children: const [
                  _VendorEmpty(message: 'No assigned orders yet.'),
                  _OfflineMutationsCard(),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OrderCard(order: item),
                      )),
                  const _OfflineMutationsCard(),
                ],
              ),
      ),
    );
  }
}

class _OfflineMutationsCard extends ConsumerWidget {
  const _OfflineMutationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutations = ref.watch(vendorOfflineMutationsProvider);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.sync_problem_outlined),
        title: const Text('Offline sync'),
        children: [
          mutations.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => ListTile(
              title: const Text('Could not load pending mutations'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.invalidate(vendorOfflineMutationsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => items.isEmpty
                ? const ListTile(title: Text('No pending offline mutations.'))
                : Column(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(item.type),
                            subtitle: Text(item.lastError ?? item.status),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Retry',
                                  onPressed: () async {
                                    await ref
                                        .read(appControllerProvider)
                                        .api
                                        .retryVendorMutation(item.id);
                                    ref.invalidate(
                                        vendorOfflineMutationsProvider);
                                  },
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: 'Discard',
                                  onPressed: () async {
                                    await ref
                                        .read(appControllerProvider)
                                        .api
                                        .discardVendorMutation(item.id);
                                    ref.invalidate(
                                        vendorOfflineMutationsProvider);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final VendorOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => _showOrder(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.reference,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(order.status.replaceAll('_', ' '))),
                ],
              ),
              Text(order.address),
              const SizedBox(height: 8),
              Text(
                '₹${order.amountRupees.toStringAsFixed(2)} • '
                '${_formatDate(order.scheduledFor)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrder(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderActions(order: order),
    );
  }
}

class _OrderActions extends ConsumerStatefulWidget {
  const _OrderActions({required this.order});
  final VendorOrder order;

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
  String? selectedVehicle;
  String? selectedDriver;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vendorVehiclesProvider).valueOrNull ?? const [];
    final drivers = ref.watch(vendorDriversProvider).valueOrNull ?? const [];
    final assignableVehicles =
        vehicles.where((item) => item.assignable).toList();
    final assignableDrivers = drivers.where((item) => item.assignable).toList();
    selectedVehicle ??=
        assignableVehicles.isEmpty ? null : assignableVehicles.first.id;
    selectedDriver ??=
        assignableDrivers.isEmpty ? null : assignableDrivers.first.id;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.order.reference,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.order.address),
            const SizedBox(height: 16),
            if (widget.order.status == 'pending_vendor') ...[
              if (assignableVehicles.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedVehicle,
                  decoration:
                      const InputDecoration(labelText: 'Approved vehicle'),
                  items: assignableVehicles
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.registrationNumber),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              if (assignableDrivers.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedDriver,
                  decoration:
                      const InputDecoration(labelText: 'Approved driver'),
                  items: assignableDrivers
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedDriver = value),
                ),
              OutlinedButton(
                onPressed: selectedVehicle == null || selectedDriver == null
                    ? () => _showAssignmentRequired(context)
                    : () => _transition(
                          context,
                          ref,
                          action: 'accept',
                          vehicleId: selectedVehicle,
                          driverId: selectedDriver,
                        ),
                child: const Text('Accept with first approved assignment'),
              ),
            ],
            if (!['delivered', 'cancelled'].contains(widget.order.status)) ...[
              _statusButton(context, ref, 'en_route', 'Mark en route'),
              _statusButton(context, ref, 'arrived', 'Mark arrived'),
              if (widget.order.status == 'arrived')
                OutlinedButton(
                  onPressed: () => _verifyDelivery(context, ref),
                  child: const Text('Verify delivery OTP'),
                ),
              OutlinedButton(
                onPressed: () => _reject(context, ref),
                child: const Text('Reject order'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    BuildContext context,
    WidgetRef ref,
    String status,
    String label,
  ) {
    return FilledButton.tonal(
      onPressed: () =>
          _transition(context, ref, action: 'status', status: status),
      child: Text(label),
    );
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    String? status,
    String? vehicleId,
    String? driverId,
    String? reason,
  }) async {
    try {
      await ref.read(appControllerProvider).api.transitionVendorOrder(
            widget.order.id,
            action: action,
            status: status,
            vehicleId: vehicleId,
            driverId: driverId,
            reason: reason,
          );
      ref.invalidate(vendorOrdersProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        try {
          await ref.read(appControllerProvider).api.queueVendorMutation(
            mutationType: action,
            entityType: 'booking',
            entityId: widget.order.id,
            payload: {
              'status': status,
              'reason': reason,
              'vehicleId': vehicleId,
              'driverId': driverId,
            },
          );
          ref.invalidate(vendorOfflineMutationsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Update failed and was queued for retry.'),
              ),
            );
          }
        } catch (queueError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$error\nQueue failed: $queueError')),
            );
          }
        }
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject order'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject')),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed == true && reason.length >= 2 && context.mounted) {
      await _transition(context, ref, action: 'reject', reason: reason);
    }
  }

  Future<void> _verifyDelivery(BuildContext context, WidgetRef ref) async {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify delivery'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Six-digit delivery OTP',
            ),
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                ? null
                : 'Enter the six-digit OTP.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    final otp = otpController.text.trim();
    otpController.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.verifyVendorDelivery(
            orderId: widget.order.id,
            otp: otp,
          );
      ref.invalidate(vendorOrdersProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery verified successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery verification failed: $error')),
        );
      }
    }
  }

  void _showAssignmentRequired(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Assignment required'),
        content: Text(
            'An active, approved vehicle and driver are required before accepting this order.'),
      ),
    );
  }
}

class VendorFleetScreen extends ConsumerWidget {
  const VendorFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(vendorDashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorDashboardProvider),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Vehicles')),
                TextButton(
                  onPressed: () => _addVehicle(context, ref),
                  child: const Text('Add'),
                ),
              ],
            ),
            ...value.vehicles.map(
              (vehicle) => ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(vehicle.registrationNumber),
                subtitle: Text(
                    '${vehicle.capacityLitres} litres • ${vehicle.verification}'),
                onTap: () => _editVehicle(context, ref, vehicle),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(appControllerProvider)
                        .api
                        .updateVendorVehicle(
                          vehicle.id,
                          isActive: !vehicle.active,
                        );
                    ref.invalidate(vendorDashboardProvider);
                  },
                  child: Text(vehicle.active ? 'Deactivate' : 'Activate'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Drivers')),
                TextButton(
                  onPressed: () => _addDriver(context, ref),
                  child: const Text('Add'),
                ),
              ],
            ),
            ...value.drivers.map(
              (driver) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(driver.name),
                subtitle: Text('${driver.mobile} • ${driver.verification}'),
                onTap: () => _editDriver(context, ref, driver),
                trailing: PopupMenuButton<String>(
                  onSelected: (status) async {
                    try {
                      await ref
                          .read(appControllerProvider)
                          .api
                          .updateVendorAttendance(
                            driverId: driver.id,
                            status: status,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${driver.name}: ${status.replaceAll('_', ' ')}',
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Attendance failed: $error')),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'present', child: Text('Mark present')),
                    PopupMenuItem(value: 'absent', child: Text('Mark absent')),
                    PopupMenuItem(
                      value: 'on_leave',
                      child: Text('Mark on leave'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _VendorAvailabilityCard(),
            _VendorComplaintCard(orders: value.orders),
            const _VendorDocumentCard(),
            _VendorAttendanceCard(drivers: value.drivers),
          ],
        ),
      ),
    );
  }

  Future<void> _addVehicle(BuildContext context, WidgetRef ref) async {
    final registration = TextEditingController();
    final capacity = TextEditingController();
    final saved = await _showRecordForm(
      context,
      title: 'Add vehicle',
      fields: [
        ('Registration number', registration),
        ('Capacity litres', capacity)
      ],
      submit: () async {
        final litres = int.tryParse(capacity.text.trim());
        if (litres == null || litres <= 0) {
          throw const FormatException('Enter a valid capacity.');
        }
        await ref.read(appControllerProvider).api.createVendorVehicle(
              registrationNumber: registration.text.trim(),
              capacityLitres: litres,
            );
      },
    );
    registration.dispose();
    capacity.dispose();
    if (saved && context.mounted) ref.invalidate(vendorDashboardProvider);
  }

  Future<void> _addDriver(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final licence = TextEditingController();
    final saved = await _showRecordForm(
      context,
      title: 'Add driver',
      fields: [
        ('Name', name),
        ('10-digit mobile', mobile),
        ('Licence number', licence),
      ],
      submit: () async {
        if (!RegExp(r'^\d{10}$').hasMatch(mobile.text.trim())) {
          throw const FormatException('Enter a valid 10-digit mobile number.');
        }

        await ref.read(appControllerProvider).api.createVendorDriver(
              name: name.text.trim(),
              mobile: mobile.text.trim(),
              licenceNumber: licence.text.trim(),
            );
      },
    );
    name.dispose();
    mobile.dispose();
    licence.dispose();
    if (saved && context.mounted) ref.invalidate(vendorDashboardProvider);
  }

  Future<void> _editVehicle(
    BuildContext context,
    WidgetRef ref,
    VendorVehicle vehicle,
  ) async {
    final registration =
        TextEditingController(text: vehicle.registrationNumber);
    final capacity = TextEditingController(text: '${vehicle.capacityLitres}');
    final saved = await _showRecordForm(
      context,
      title: 'Edit vehicle',
      fields: [
        ('Registration number', registration),
        ('Capacity litres', capacity)
      ],
      submit: () async {
        final litres = int.tryParse(capacity.text.trim());
        if (litres == null || litres <= 0) {
          throw const FormatException('Enter a valid capacity.');
        }
        await ref.read(appControllerProvider).api.updateVendorVehicle(
              vehicle.id,
              registrationNumber: registration.text.trim(),
              capacityLitres: litres,
            );
      },
    );
    registration.dispose();
    capacity.dispose();
    if (saved && context.mounted) ref.invalidate(vendorDashboardProvider);
  }

  Future<void> _editDriver(
    BuildContext context,
    WidgetRef ref,
    VendorDriver driver,
  ) async {
    final name = TextEditingController(text: driver.name);
    final mobile = TextEditingController(text: driver.mobile);
    final licence = TextEditingController();
    final saved = await _showRecordForm(
      context,
      title: 'Edit driver',
      fields: [
        ('Name', name),
        ('10-digit mobile', mobile),
        ('Licence number (optional)', licence)
      ],
      submit: () async {
        if (!RegExp(r'^\d{10}$').hasMatch(mobile.text.trim())) {
          throw const FormatException('Enter a valid 10-digit mobile number.');
        }
        await ref.read(appControllerProvider).api.updateVendorDriver(
              driver.id,
              name: name.text.trim(),
              mobile: mobile.text.trim(),
              licenceNumber:
                  licence.text.trim().isEmpty ? null : licence.text.trim(),
            );
      },
    );
    name.dispose();
    mobile.dispose();
    licence.dispose();
    if (saved && context.mounted) ref.invalidate(vendorDashboardProvider);
  }

  Future<bool> _showRecordForm(
    BuildContext context, {
    required String title,
    required List<(String, TextEditingController)> fields,
    required Future<void> Function() submit,
  }) async {
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...fields.map(
                (field) => TextField(
                  controller: field.$2,
                  decoration: InputDecoration(labelText: field.$1),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await submit();
                  if (context.mounted) Navigator.pop(context, true);
                } catch (value) {
                  setState(() => error = value.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    return saved == true;
  }
}

class _VendorAvailabilityCard extends ConsumerWidget {
  const _VendorAvailabilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(vendorServicesProvider);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.toggle_on_outlined),
        title: const Text('Service availability'),
        children: [
          services.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => ListTile(
              title: const Text('Could not load service availability'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.invalidate(vendorServicesProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => items.isEmpty
                ? const ListTile(title: Text('No services available.'))
                : Column(
                    children: items
                        .map(
                          (service) => SwitchListTile(
                            title: Text(service.name),
                            subtitle: Text(service.description),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Availability update failed: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VendorComplaintCard extends ConsumerWidget {
  const _VendorComplaintCard({required this.orders});

  final List<VendorOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VendorRecordsCard(
      title: 'Complaints',
      icon: Icons.report_problem_outlined,
      loader: (api) => api.vendorComplaints(),
      emptyMessage: 'No complaints recorded.',
      action: () => _createComplaint(context, ref),
      onTap: (record) => _showComplaint(context, ref, record),
    );
  }

  Future<void> _createComplaint(BuildContext context, WidgetRef ref) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A booking is required to create a complaint.')),
      );
      return;
    }
    final subject = TextEditingController();
    final message = TextEditingController();
    String bookingId = orders.first.id;
    final saved = await _showVendorForm(
      context,
      title: 'Create complaint',
      fields: [('Subject', subject), ('Message', message)],
      extra: DropdownButtonFormField<String>(
        initialValue: bookingId,
        decoration: const InputDecoration(labelText: 'Booking'),
        items: orders
            .map((order) => DropdownMenuItem(
                  value: order.id,
                  child: Text(order.reference),
                ))
            .toList(),
        onChanged: (value) => bookingId = value ?? bookingId,
      ),
      submit: () async {
        await ref.read(appControllerProvider).api.createVendorComplaint(
              bookingId: bookingId,
              subject: subject.text.trim(),
              message: message.text.trim(),
            );
      },
    );
    subject.dispose();
    message.dispose();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted.')),
      );
    }
  }

  Future<void> _showComplaint(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> record,
  ) async {
    final resolution = TextEditingController(
      text: (record['message'] ?? record['response'] ?? '').toString(),
    );
    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((record['subject'] ?? 'Complaint').toString()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text((record['message'] ?? '').toString()),
            TextField(
              controller: resolution,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Resolution / response'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'resolved'),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (status == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.updateVendorComplaint(
            id: (record['id'] ?? '').toString(),
            status: status,
            resolution: resolution.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint updated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint update failed: $error')),
        );
      }
    } finally {
      resolution.dispose();
    }
  }
}

class _VendorDocumentCard extends ConsumerWidget {
  const _VendorDocumentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VendorRecordsCard(
      title: 'Documents',
      icon: Icons.description_outlined,
      loader: (api) => api.vendorDocuments(),
      emptyMessage: 'No documents submitted.',
      action: () => _editDocument(context, ref),
      onTap: (record) => _editDocument(context, ref, record),
    );
  }

  Future<void> _editDocument(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? record,
  ]) async {
    final type = TextEditingController(
      text: (record?['document_type'] ?? record?['documentType'] ?? '')
          .toString(),
    );
    final objectKey = TextEditingController(
      text: (record?['object_key'] ?? record?['objectKey'] ?? '').toString(),
    );
    final expiry = TextEditingController(
      text: (record?['expires_on'] ?? record?['expiresOn'] ?? '').toString(),
    );
    final saved = await _showVendorForm(
      context,
      title: record == null ? 'Submit document' : 'Resubmit document',
      fields: [
        ('Document type', type),
        ('Object key / uploaded file path', objectKey),
        ('Expiry date (YYYY-MM-DD)', expiry),
      ],
      submit: () async {
        final id = record?['id']?.toString();
        if (id == null || id.isEmpty) {
          await ref.read(appControllerProvider).api.createVendorDocument(
                documentType: type.text.trim(),
                objectKey: objectKey.text.trim(),
                expiresOn: expiry.text.trim(),
              );
        } else {
          await ref.read(appControllerProvider).api.updateVendorDocument(
                id: id,
                documentType: type.text.trim(),
                objectKey: objectKey.text.trim(),
                expiresOn: expiry.text.trim(),
              );
        }
      },
    );
    type.dispose();
    objectKey.dispose();
    expiry.dispose();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document submitted.')),
      );
    }
  }
}

class _VendorAttendanceCard extends ConsumerStatefulWidget {
  const _VendorAttendanceCard({required this.drivers});

  final List<VendorDriver> drivers;

  @override
  ConsumerState<_VendorAttendanceCard> createState() =>
      _VendorAttendanceCardState();
}

class _VendorAttendanceCardState extends ConsumerState<_VendorAttendanceCard> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.event_available_outlined),
        title: const Text('Attendance history'),
        subtitle: Text(_formatDate(selectedDate)),
        children: [
          ListTile(
            title: const Text('Select date'),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: selectedDate,
                );
                if (value != null) setState(() => selectedDate = value);
              },
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(appControllerProvider).api.vendorAttendance(
                  date: selectedDate,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return const ListTile(title: Text('No attendance recorded.'));
              }
              return Column(
                children: records.map((record) {
                  final driver = widget.drivers.firstWhere(
                    (item) => item.id == record['driver_id'],
                    orElse: () => const VendorDriver(
                      id: '',
                      name: 'Driver',
                      mobile: '',
                      active: false,
                      verification: '',
                    ),
                  );
                  return ListTile(
                    title: Text(driver.name),
                    trailing: Text((record['status'] ?? '').toString()),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VendorRecordsCard extends ConsumerWidget {
  const _VendorRecordsCard({
    required this.title,
    required this.icon,
    required this.loader,
    required this.emptyMessage,
    this.action,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Future<List<Map<String, dynamic>>> Function(ApiClient api) loader;
  final String emptyMessage;
  final VoidCallback? action;
  final void Function(Map<String, dynamic> record)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: action == null
            ? null
            : IconButton(
                onPressed: action,
                icon: const Icon(Icons.add),
              ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
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
              if (records.isEmpty) return ListTile(title: Text(emptyMessage));
              return Column(
                children: records
                    .map(
                      (record) => ListTile(
                        title: Text(
                          (record['subject'] ??
                                  record['document_type'] ??
                                  record['documentType'] ??
                                  'Record')
                              .toString(),
                        ),
                        subtitle: Text(
                          (record['status'] ??
                                  record['verification'] ??
                                  record['object_key'] ??
                                  record['objectKey'] ??
                                  '')
                              .toString(),
                        ),
                        onTap: onTap == null ? null : () => onTap!(record),
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

Future<bool> _showVendorForm(
  BuildContext context, {
  required String title,
  required List<(String, TextEditingController)> fields,
  Widget? extra,
  required Future<void> Function() submit,
}) async {
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (extra != null) extra,
              ...fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: field.$2,
                    maxLines: field.$1 == 'Message' ? 4 : 1,
                    decoration: InputDecoration(labelText: field.$1),
                  ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (fields.any((field) => field.$2.text.trim().isEmpty)) {
                setState(() => error = 'Complete all fields.');
                return;
              }
              try {
                await submit();
                if (context.mounted) Navigator.pop(context, true);
              } catch (value) {
                if (context.mounted) setState(() => error = value.toString());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  return saved == true;
}

class VendorEarningsScreen extends ConsumerWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(vendorPayoutsProvider);
    return payouts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorPayoutsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorPayoutsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _requestPayout(context, ref),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Request payout'),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const _VendorEmpty(message: 'No payouts yet.')
            else
              ...items.map(
                (payout) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text('₹${payout.amountRupees.toStringAsFixed(2)}'),
                    subtitle: Text(
                        '${payout.reference}\n${_formatDate(payout.createdAt)}'),
                    trailing: Text(payout.status),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request payout'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount in rupees',
              prefixText: '₹ ',
            ),
            validator: (value) {
              final amount = double.tryParse(value ?? '');
              return amount == null || amount <= 0
                  ? 'Enter a valid amount.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (submitted != true || amount == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.requestVendorPayout(
            amount: amount,
          );
      ref.invalidate(vendorPayoutsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout request submitted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout request failed: $error')),
        );
      }
    }
  }
}

class _VendorEmpty extends StatelessWidget {
  const _VendorEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(message)),
      );
}

class _VendorError extends StatelessWidget {
  const _VendorError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _formatDate(DateTime? value) => value == null
    ? 'Date not set'
    : value.toLocal().toString().split(' ').first;
