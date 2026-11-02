import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/page_components.dart';
import '../../models/vendor.dart';
import '../../services/photo_permissions.dart';
import '../../services/realtime_service.dart';
import '../../services/temporary_photo.dart';
import '../../services/friendly_error.dart';
import 'vendor_shared.dart';

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
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorOrdersProvider),
      ),
      data: (items) {
        final filtered = items.where(_matchesOrder).toList();
        // Fixed search and filter controls above the order cards, and the
        // offline records card below them. Only the order cards are lazy.
        final header = <Widget>[
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
        ];
        final footer = <Widget>[const _OfflineMutationsCard()];
        // An empty-state message takes the place of the order cards.
        final rowCount =
            items.isEmpty || filtered.isEmpty ? 1 : filtered.length;
        return RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(vendorOrdersProvider)
              ..invalidate(vendorDashboardProvider);
          },
          child: ListView.builder(
            padding: AppPageInsets.standard,
            itemCount: header.length + rowCount + footer.length,
            itemBuilder: (_, index) {
              if (index < header.length) return header[index];
              index -= header.length;
              if (index < rowCount) {
                if (items.isEmpty) {
                  return const VendorEmpty(message: 'No assigned orders yet.');
                }
                if (filtered.isEmpty) {
                  return const VendorEmpty(
                    message: 'No orders match these filters.',
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OrderCard(order: filtered[index]),
                );
              }
              return footer[index - rowCount];
            },
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
              subtitle: Text(friendlyError(error)),
              trailing: IconButton(
                tooltip: 'Refresh',
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
                  Semantics(
                    label:
                        'Order status: ${order.status.replaceAll('_', ' ')}',
                    child: ExcludeSemantics(
                      child: Chip(label: Text(order.status.replaceAll('_', ' '))),
                    ),
                  ),
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
                '${formatDate(order.scheduledFor)}',
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

class _OrderActionsState extends ConsumerState<_OrderActions>
    with WidgetsBindingObserver {
  String? selectedVehicle;
  String? selectedDriver;
  bool _saving = false;
  bool _sharingLocation = false;
  bool _locationUpdatePending = false;
  String? _locationStatus;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationTimer;
  Position? _latestPosition;

  /// Location is sent at most once per interval; only the latest fix is kept.
  static const _locationInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_sharingLocation) _stopLocationSharing();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
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
    _latestPosition = null;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      _locationInterval,
      (_) => unawaited(_sendLatestPosition()),
    );
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(
      (position) {
        _latestPosition = position;
      },
      onError: (Object error) {
        _stopLocationSharing();
        _showLocationMessage('Location sharing stopped: $error');
      },
    );
  }

  Future<void> _sendLatestPosition() async {
    final position = _latestPosition;
    if (position == null || _locationUpdatePending || !_sharingLocation) {
      return;
    }
    _latestPosition = null;
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
    _locationTimer?.cancel();
    _locationTimer = null;
    _latestPosition = null;
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
                        requestFullMetadata: pickerRequestsFullMetadata,
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
    if (confirmed != true || !context.mounted) {
      unawaited(discardTemporaryPhotoFile(proofPhoto?.path));
      return;
    }
    if (_saving) {
      unawaited(discardTemporaryPhotoFile(proofPhoto?.path));
      return;
    }
    setState(() => _saving = true);
    try {
      final photo = proofPhoto;
      final proofPath = photo == null
          ? null
          : await ref.read(appControllerProvider).api.uploadVendorFile(
                fileName: photo.name,
                contentType: 'image/jpeg',
                bytes: await photo.readAsBytes(),
              );
      if (photo != null) await discardTemporaryPhotoFile(photo.path);
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
      unawaited(discardTemporaryPhotoFile(proofPhoto?.path));
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
