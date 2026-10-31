import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../app/providers.dart';
import '../app/page_components.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';

class VendorOperationsScreen extends ConsumerStatefulWidget {
  const VendorOperationsScreen({super.key});

  @override
  ConsumerState<VendorOperationsScreen> createState() =>
      _VendorOperationsScreenState();
}

class _VendorOperationsScreenState
    extends ConsumerState<VendorOperationsScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _realtimeSubscription =
        ref.read(appControllerProvider).realtime?.events.listen((event) {
      if (event.name != 'vendor.order.created' &&
          event.name != 'vendor.order.taken' &&
          event.name != 'vendor.order.declined' &&
          event.name != 'booking.updated') {
        return;
      }
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(vendorOrdersProvider);
    return orders.when(
      loading: () => const AppStateView.loading(),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorOrdersProvider),
      ),
      data: (items) {
        final filtered = items.where(_matchesOrder).toList();
        return RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(vendorOrdersProvider)
              ..invalidate(vendorDashboardProvider);
          },
          child: ListView(
            padding: AppPageInsets.standard,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search orders',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in [
                    'All',
                    'Needs action',
                    'In progress',
                    'Completed',
                  ])
                    ChoiceChip(
                      label: Text(status),
                      selected: _statusFilter == status,
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${filtered.length} of ${items.length} orders'),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const _VendorEmpty(message: 'No assigned orders yet.')
              else if (filtered.isEmpty)
                const _VendorEmpty(
                  message: 'No orders match these filters.',
                )
              else
                ...filtered.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OrderCard(order: item),
                    )),
              const _OfflineMutationsCard(),
            ],
          ),
        );
      },
    );
  }

  bool _matchesOrder(VendorOrder order) {
    final statusMatches = switch (_statusFilter) {
      'Needs action' =>
        ['pending_vendor', 'vendor_assigned'].contains(order.status),
      'In progress' =>
        ['accepted', 'en_route', 'arrived'].contains(order.status),
      'Completed' => ['delivered', 'cancelled'].contains(order.status),
      _ => true,
    };
    if (!statusMatches) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      order.reference,
      order.serviceCode,
      order.address,
      ...order.serviceDetails.map((detail) => detail.service),
      ...order.serviceDetails.map((detail) => detail.details),
    ].any((value) => value.toLowerCase().contains(query));
  }
}

class _OfflineMutationsCard extends ConsumerStatefulWidget {
  const _OfflineMutationsCard();

  @override
  ConsumerState<_OfflineMutationsCard> createState() =>
      _OfflineMutationsCardState();
}

class _OfflineMutationsCardState extends ConsumerState<_OfflineMutationsCard> {
  final Set<String> _processing = {};

  Future<void> _runMutation(
    VendorOfflineMutation mutation,
  ) async {
    setState(() => _processing.add(mutation.id));
    try {
      await ref
          .read(appControllerProvider)
          .api
          .discardVendorMutation(mutation.id);
      ref
        ..invalidate(vendorOfflineMutationsProvider)
        ..invalidate(vendorOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Update record discarded.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update queued item: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(mutation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutations = ref.watch(vendorOfflineMutationsProvider);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.sync_problem_outlined),
        title: const Text('Saved update records'),
        subtitle: const Text(
          'Server logs only; failed actions are not auto-replayed.',
        ),
        children: [
          mutations.when(
            loading: () => const AppStateInline.loading(),
            error: (error, _) => ListTile(
              title: const Text('Could not load pending mutations'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.invalidate(vendorOfflineMutationsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => items.isEmpty
                ? const ListTile(title: Text('No saved update records.'))
                : Column(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(
                              '${item.type} • ${item.entityType}'
                              '${item.entityId == null ? '' : ' ${item.entityId}'}',
                            ),
                            subtitle: Text(
                              item.lastError ??
                                  item.status.replaceAll('_', ' '),
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Discard',
                                  onPressed: _processing.contains(item.id)
                                      ? null
                                      : () => _confirmDiscard(item),
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

  Future<void> _confirmDiscard(VendorOfflineMutation mutation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard update record?'),
        content: const Text('This removes the saved update record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runMutation(mutation);
    }
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
              if (order.statusMessage?.trim().isNotEmpty == true)
                Text(order.statusMessage!),
              if (order.latitude != null && order.longitude != null)
                Text(
                  'Delivery coordinates: ${order.latitude!.toStringAsFixed(5)}, '
                  '${order.longitude!.toStringAsFixed(5)}',
                ),
              if (order.cancellationReason?.trim().isNotEmpty == true)
                Text('Cancellation reason: ${order.cancellationReason}'),
              if (order.serviceDetails.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final detail in order.serviceDetails) ...[
                  Text(
                    detail.service,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (detail.capacity.isNotEmpty)
                    Text('Capacity/quantity: ${detail.capacity}'),
                  if (detail.waterType?.isNotEmpty == true)
                    Text('Water type: ${detail.waterType}'),
                  if (detail.tankerCount?.isNotEmpty == true)
                    Text('Tanker count: ${detail.tankerCount}'),
                  if (detail.details.isNotEmpty) Text(detail.details),
                ],
              ] else if (order.serviceCode.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(order.serviceCode.replaceAll('_', ' ')),
              ],
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
  bool _saving = false;
  bool _sharingLocation = false;
  bool _locationUpdatePending = false;
  String? _locationStatus;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final vehicles = ref.watch(vendorVehiclesProvider).value ?? const [];
    final drivers = ref.watch(vendorDriversProvider).value ?? const [];
    final assignableVehicles =
        vehicles.where((item) => item.assignable).toList();
    final assignableDrivers = drivers.where((item) => item.assignable).toList();
    final assignedVehicleId =
        order.vehicleId ?? _vehicleIdForLabel(vehicles, order.vehicle);
    final assignedDriverId =
        order.driverId ?? _driverIdForLabel(drivers, order.driver);
    final currentVehicleId = assignableVehicles.any(
      (item) => item.id == assignedVehicleId,
    )
        ? assignedVehicleId
        : null;
    final currentDriverId = assignableDrivers.any(
      (item) => item.id == assignedDriverId,
    )
        ? assignedDriverId
        : null;
    selectedVehicle ??= currentVehicleId ??
        (assignableVehicles.isEmpty ? null : assignableVehicles.first.id);
    selectedDriver ??= currentDriverId ??
        (assignableDrivers.isEmpty ? null : assignableDrivers.first.id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(order.reference,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(order.address),
              if (order.cancellationReason?.trim().isNotEmpty == true)
                Text('Cancellation reason: ${order.cancellationReason}'),
              if (order.latitude != null && order.longitude != null)
                Text(
                  'Delivery coordinates: ${order.latitude!.toStringAsFixed(5)}, '
                  '${order.longitude!.toStringAsFixed(5)}',
                ),
              const SizedBox(height: 8),
              for (final detail in order.serviceDetails) ...[
                Text(detail.service,
                    style: Theme.of(context).textTheme.titleSmall),
                if (detail.capacity.isNotEmpty)
                  Text('Capacity/quantity: ${detail.capacity}'),
                if (detail.waterType?.isNotEmpty == true)
                  Text('Water type: ${detail.waterType}'),
                if (detail.tankerCount?.isNotEmpty == true)
                  Text('Tanker count: ${detail.tankerCount}'),
                if (detail.details.isNotEmpty) Text(detail.details),
                const SizedBox(height: 6),
              ],
              if (order.vehicle != null || order.driver != null) ...[
                Text(
                  [
                    if (order.vehicle != null) 'Vehicle: ${order.vehicle}',
                    if (order.driver != null) 'Driver: ${order.driver}',
                  ].join('\n'),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              if (order.status == 'pending_vendor') ...[
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
                    onChanged: (value) =>
                        setState(() => selectedVehicle = value),
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
                    onChanged: (value) =>
                        setState(() => selectedDriver = value),
                  ),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : selectedVehicle == null || selectedDriver == null
                          ? () => _showAssignmentRequired(context)
                          : () => _transition(
                                context,
                                ref,
                                action: 'assign',
                                vehicleId: selectedVehicle,
                                driverId: selectedDriver,
                              ),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Assign vehicle and driver'),
                ),
              ],
              if (order.status == 'vendor_assigned')
                FilledButton(
                  onPressed: _saving
                      ? null
                      : assignedVehicleId == null || assignedDriverId == null
                          ? () => _showAssignmentRequired(context)
                          : () => _transition(context, ref, action: 'accept'),
                  child: const Text('Accept order'),
                ),
              if (order.status == 'accepted')
                _statusButton(context, ref, 'en_route', 'Mark en route'),
              if (order.status == 'en_route')
                _statusButton(context, ref, 'arrived', 'Mark arrived'),
              if (['en_route', 'arrived'].contains(order.status)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : _sharingLocation
                          ? _stopLocationSharing
                          : _startLocationSharing,
                  icon: Icon(
                    _sharingLocation
                        ? Icons.location_off_outlined
                        : Icons.my_location,
                  ),
                  label: Text(
                    _sharingLocation
                        ? 'Stop sharing location'
                        : 'Share live location',
                  ),
                ),
                Text(
                  _locationStatus ??
                      'Location is shared only while this screen is open.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (order.status == 'arrived')
                OutlinedButton(
                  onPressed:
                      _saving ? null : () => _verifyDelivery(context, ref),
                  child: const Text('Verify delivery OTP'),
                ),
              if ([
                'pending_vendor',
                'vendor_assigned',
                'accepted',
              ].contains(order.status))
                OutlinedButton(
                  onPressed: _saving ? null : () => _reject(context, ref),
                  child: const Text('Reject order'),
                ),
              if (_saving)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
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
      onPressed: _saving
          ? null
          : () => _transition(context, ref, action: 'status', status: status),
      child: Text(label),
    );
  }

  Future<void> _startLocationSharing() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      await showAppPermissionDialog(
        context,
        message: 'Turn on location services to share your location.',
        onOpenSettings: () {
          unawaited(Geolocator.openLocationSettings());
        },
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showAppPermissionDialog(
          context,
          message:
              'Allow location access in device settings to share your location.',
          onOpenSettings: () {
            unawaited(Geolocator.openAppSettings());
          },
        );
      } else {
        _showLocationMessage(
          'Location permission is required to share your location.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _sharingLocation = true;
      _locationStatus = 'Waiting for a location fix...';
    });
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(
      _sharePosition,
      onError: (Object error) {
        _stopLocationSharing();
        _showLocationMessage('Location sharing stopped: $error');
      },
    );
  }

  Future<void> _sharePosition(Position position) async {
    if (_locationUpdatePending) return;
    _locationUpdatePending = true;
    try {
      await ref.read(appControllerProvider).api.updateVendorLocation(
            bookingId: widget.order.id,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );
      if (mounted) {
        setState(() {
          _locationStatus =
              'Location shared at ${TimeOfDay.fromDateTime(DateTime.now()).format(context)}';
        });
      }
    } catch (error) {
      _stopLocationSharing();
      _showLocationMessage('Could not share location: $error');
    } finally {
      _locationUpdatePending = false;
    }
  }

  void _stopLocationSharing() {
    unawaited(_locationSubscription?.cancel());
    _locationSubscription = null;
    if (mounted) {
      setState(() {
        _sharingLocation = false;
        _locationStatus = 'Live location sharing is stopped.';
      });
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider).api.transitionVendorOrder(
            widget.order.id,
            action: action,
            status: status,
            vehicleId: vehicleId,
            driverId: driverId,
            reason: reason,
          );
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order update failed and was not applied: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    if (confirmed != true || !context.mounted) return;
    if (reason.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a rejection reason.')),
      );
      return;
    }
    await _transition(context, ref, action: 'reject', reason: reason);
  }

  Future<void> _verifyDelivery(BuildContext context, WidgetRef ref) async {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    XFile? proofPhoto;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Verify delivery'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
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
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final image = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (image != null && context.mounted) {
                        setDialogState(() => proofPhoto = image);
                      }
                    } catch (error) {
                      if (context.mounted) {
                        setDialogState(
                          () => proofPhoto = null,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Camera unavailable: $error')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    proofPhoto == null
                        ? 'Capture delivery photo (optional)'
                        : 'Retake delivery photo',
                  ),
                ),
                if (proofPhoto != null)
                  Text(
                    proofPhoto!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    final otp = otpController.text.trim();
    otpController.dispose();
    if (confirmed != true || !context.mounted) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final proofPath = proofPhoto == null
          ? null
          : await ref.read(appControllerProvider).api.uploadVendorFile(
                fileName: proofPhoto!.name,
                contentType: 'image/jpeg',
                bytes: await proofPhoto!.readAsBytes(),
              );
      await ref.read(appControllerProvider).api.verifyVendorDelivery(
            orderId: widget.order.id,
            otp: otp,
            proofPath: proofPath,
          );
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
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
    } finally {
      if (mounted) setState(() => _saving = false);
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
      loading: () => const AppStateView.loading(),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorDashboardProvider),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorDashboardProvider),
        child: ListView(
          padding: AppPageInsets.standard,
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
                  onPressed: () => _setVehicleActive(
                    context,
                    ref,
                    vehicle,
                    !vehicle.active,
                  ),
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

  Future<void> _setVehicleActive(
    BuildContext context,
    WidgetRef ref,
    VendorVehicle vehicle,
    bool active,
  ) async {
    try {
      await ref.read(appControllerProvider).api.updateVendorVehicle(
            vehicle.id,
            isActive: active,
          );
      _invalidateVendorFleet(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${vehicle.registrationNumber} ${active ? 'activated' : 'deactivated'}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vehicle update failed: $error')),
        );
      }
    }
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
    if (saved && context.mounted) _invalidateVendorFleet(ref);
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
    if (saved && context.mounted) _invalidateVendorFleet(ref);
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
    if (saved && context.mounted) _invalidateVendorFleet(ref);
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
    if (saved && context.mounted) _invalidateVendorFleet(ref);
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
    PlatformFile? selectedFile;
    Uint8List? selectedFileBytes;
    XFile? cameraPhoto;
    String? error;
    var saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Submit document' : 'Resubmit document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: type,
                  decoration: const InputDecoration(labelText: 'Document type'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          try {
                            final files = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const [
                                'pdf',
                                'jpg',
                                'jpeg',
                                'png',
                                'webp',
                                'doc',
                                'docx',
                              ],
                            );
                            final file = files.isEmpty ? null : files.single;
                            if (file != null && dialogContext.mounted) {
                              final bytes = await file.readAsBytes();
                              setDialogState(() {
                                selectedFile = file;
                                selectedFileBytes = bytes;
                                cameraPhoto = null;
                                objectKey.text = file.name;
                                error = null;
                              });
                            }
                          } catch (value) {
                            if (dialogContext.mounted) {
                              setDialogState(() => error = value.toString());
                            }
                          }
                        },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose a document'),
                ),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.camera,
                              imageQuality: 80,
                            );
                            if (photo != null && dialogContext.mounted) {
                              setDialogState(() {
                                cameraPhoto = photo;
                                selectedFile = null;
                                selectedFileBytes = null;
                                objectKey.text = photo.name;
                                error = null;
                              });
                            }
                          } catch (value) {
                            if (dialogContext.mounted) {
                              setDialogState(() => error = value.toString());
                            }
                          }
                        },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan with camera'),
                ),
                if (objectKey.text.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selected: ${objectKey.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                TextField(
                  controller: expiry,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Expiry date (optional, YYYY-MM-DD)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
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
                      final expiryText = expiry.text.trim();
                      if (type.text.trim().isEmpty) {
                        setDialogState(() => error = 'Enter a document type.');
                        return;
                      }
                      if ((record == null ||
                              selectedFile != null ||
                              cameraPhoto != null) &&
                          selectedFile == null &&
                          cameraPhoto == null) {
                        setDialogState(
                          () => error = 'Choose a file or capture a photo.',
                        );
                        return;
                      }
                      if (expiryText.isNotEmpty &&
                          (DateTime.tryParse(expiryText) == null ||
                              !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                  .hasMatch(expiryText))) {
                        setDialogState(
                          () => error = 'Enter expiry as YYYY-MM-DD.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        var path = objectKey.text.trim();
                        if (selectedFile != null) {
                          final bytes = selectedFileBytes;
                          if (bytes == null) {
                            throw const FormatException(
                              'Could not read the selected document.',
                            );
                          }
                          path = await ref
                              .read(appControllerProvider)
                              .api
                              .uploadVendorFile(
                                fileName: selectedFile!.name,
                                contentType: _vendorDocumentContentType(
                                  selectedFile!.extension,
                                ),
                                bytes: bytes,
                              );
                        } else if (cameraPhoto != null) {
                          path = await ref
                              .read(appControllerProvider)
                              .api
                              .uploadVendorFile(
                                fileName: cameraPhoto!.name,
                                contentType: 'image/jpeg',
                                bytes: await cameraPhoto!.readAsBytes(),
                              );
                        }
                        final api = ref.read(appControllerProvider).api;
                        final id = record?['id']?.toString();
                        if (id == null || id.isEmpty) {
                          await api.createVendorDocument(
                            documentType: type.text.trim(),
                            objectKey: path,
                            expiresOn: expiryText.isEmpty ? null : expiryText,
                          );
                        } else {
                          await api.updateVendorDocument(
                            id: id,
                            documentType: type.text.trim(),
                            objectKey: path,
                            expiresOn: expiryText.isEmpty ? null : expiryText,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (value) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = value.toString();
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload and submit'),
            ),
          ],
        ),
      ),
    );
    type.dispose();
    objectKey.dispose();
    expiry.dispose();
    if (saved == true && context.mounted) {
      _invalidateVendorFleet(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded and submitted.')),
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
      loading: () => const AppStateView.loading(),
      error: (error, _) => _VendorError(
        message: error.toString(),
        retry: () => ref.invalidate(vendorPayoutsProvider),
      ),
      data: (items) {
        final paidPaise = items
            .where((item) =>
                ['paid', 'completed'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        final pendingPaise = items
            .where((item) =>
                ['pending', 'processing'].contains(item.status.toLowerCase()))
            .fold<int>(0, (total, item) => total + item.amountPaise);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorPayoutsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payout summary',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Paid: ₹${(paidPaise / 100).toStringAsFixed(2)}',
                      ),
                      Text(
                        'Pending/processing: '
                        '₹${(pendingPaise / 100).toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on payout records; this is not an available-balance estimate.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
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
                      subtitle: Text([
                        payout.reference,
                        _formatDate(payout.createdAt),
                        if (payout.periodStart != null ||
                            payout.periodEnd != null)
                          'Period: ${_formatDate(payout.periodStart)} – '
                              '${_formatDate(payout.periodEnd)}',
                      ].join('\n')),
                      trailing: Text(payout.status),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTimeRange? period;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request payout'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: period,
                    );
                    if (selected != null) {
                      setDialogState(() => period = selected);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    period == null
                        ? 'Add earning period (optional)'
                        : '${_formatDate(period!.start)} – '
                            '${_formatDate(period!.end)}',
                  ),
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (submitted != true || amount == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.requestVendorPayout(
            amount: amount,
            periodStart: period?.start,
            periodEnd: period?.end,
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
  Widget build(BuildContext context) => AppStateView.error(
        error: message,
        onRetry: retry,
      );
}

void _invalidateVendorFleet(WidgetRef ref) {
  ref
    ..invalidate(vendorDashboardProvider)
    ..invalidate(vendorVehiclesProvider)
    ..invalidate(vendorDriversProvider);
}

String? _vehicleIdForLabel(List<VendorVehicle> vehicles, String? label) {
  if (label == null || label.isEmpty) return null;
  for (final vehicle in vehicles) {
    if (vehicle.registrationNumber == label) return vehicle.id;
  }
  return null;
}

String? _driverIdForLabel(List<VendorDriver> drivers, String? label) {
  if (label == null || label.isEmpty) return null;
  for (final driver in drivers) {
    if (driver.name == label) return driver.id;
  }
  return null;
}

String _vendorDocumentContentType(String? extension) =>
    switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => throw const FormatException('This file type is not supported.'),
    };

String _formatDate(DateTime? value) => value == null
    ? 'Date not set'
    : value.toLocal().toString().split(' ').first;
