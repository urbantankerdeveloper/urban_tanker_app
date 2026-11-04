import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../../services/photo_permissions.dart';
import '../../../services/temporary_photo.dart';

/// Actions for one vendor order: assign a vehicle and driver, accept, move the
/// order along, share live location, reject, and verify delivery.
class OrderActionsSheet extends ConsumerStatefulWidget {
  const OrderActionsSheet({required this.order, super.key});

  final VendorOrder order;

  @override
  ConsumerState<OrderActionsSheet> createState() => _OrderActionsSheetState();
}

class _OrderActionsSheetState extends ConsumerState<OrderActionsSheet>
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
    final colors = context.colors;
    final theme = Theme.of(context);
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
    final hasLocation = order.latitude != null && order.longitude != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.reference,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                BookingStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(order.address, style: theme.textTheme.bodyLarge),
            if (hasLocation)
              Text(
                'Delivery coordinates: ${order.latitude!.toStringAsFixed(5)}, '
                '${order.longitude!.toStringAsFixed(5)}',
                style: theme.textTheme.bodyMedium,
              ),
            if (order.cancellationReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                'Cancellation reason: ${order.cancellationReason}',
                style: TextStyle(color: colors.danger.fg),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            if (order.serviceDetails.isNotEmpty)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final detail in order.serviceDetails) ...[
                      Text(detail.service, style: theme.textTheme.titleSmall),
                      if (detail.capacity.isNotEmpty)
                        Text('Capacity/quantity: ${detail.capacity}'),
                      if (detail.waterType?.isNotEmpty == true)
                        Text('Water type: ${detail.waterType}'),
                      if (detail.tankerCount?.isNotEmpty == true)
                        Text('Tanker count: ${detail.tankerCount}'),
                      if (detail.details.isNotEmpty) Text(detail.details),
                      const SizedBox(height: AppSpace.sm),
                    ],
                  ],
                ),
              ),
            if (order.vehicle != null || order.driver != null) ...[
              const SizedBox(height: AppSpace.md),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.vehicle != null)
                      Text('Vehicle: ${order.vehicle}'),
                    if (order.driver != null) Text('Driver: ${order.driver}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
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
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              if (assignableDrivers.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
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
              ],
              const SizedBox(height: AppSpace.lg),
              PrimaryButton(
                label: 'Assign vehicle and driver',
                icon: Icons.assignment_turned_in_outlined,
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
              ),
            ],
            if (order.status == 'vendor_assigned')
              PrimaryButton(
                label: 'Accept order',
                icon: Icons.thumb_up_alt_outlined,
                onPressed: _saving
                    ? null
                    : assignedVehicleId == null || assignedDriverId == null
                        ? () => _showAssignmentRequired(context)
                        : () => _confirmAccept(context, ref),
              ),
            if (order.status == 'accepted')
              _statusButton(context, ref, 'en_route', 'Mark en route'),
            if (order.status == 'en_route')
              _statusButton(context, ref, 'arrived', 'Mark arrived'),
            if (['en_route', 'arrived'].contains(order.status)) ...[
              const SizedBox(height: AppSpace.md),
              SecondaryButton(
                label: _sharingLocation
                    ? 'Stop sharing location'
                    : 'Share live location',
                icon: _sharingLocation
                    ? Icons.location_off_outlined
                    : Icons.my_location,
                onPressed: _saving
                    ? null
                    : _sharingLocation
                        ? _stopLocationSharing
                        : _startLocationSharing,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                _locationStatus ??
                    'Location is shared only while this screen is open.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (order.status == 'arrived') ...[
              const SizedBox(height: AppSpace.md),
              SecondaryButton(
                label: 'Verify delivery OTP',
                icon: Icons.verified_outlined,
                onPressed: _saving ? null : () => _verifyDelivery(context, ref),
              ),
            ],
            if ([
              'pending_vendor',
              'vendor_assigned',
              'accepted',
            ].contains(order.status)) ...[
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger.fg,
                  side: BorderSide(color: colors.danger.border),
                  minimumSize: const Size(64, AppSize.buttonHeight),
                ),
                onPressed: _saving ? null : () => _reject(context, ref),
                icon: const Icon(Icons.block),
                label: const Text('Reject order'),
              ),
            ],
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(AppSpace.md),
                child: Center(child: CircularProgressIndicator()),
              ),
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: SecondaryButton(
        label: label,
        onPressed: _saving
            ? null
            : () => _transition(context, ref, action: 'status', status: status),
      ),
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
    showAppSnack(context, message, variant: AppSnackVariant.error);
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
        showAppSnack(
          context,
          'Order updated successfully.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Order update failed and was not applied: $error',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Accepting is a commitment to the customer, so it asks first.
  Future<void> _confirmAccept(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Accept this order?',
      message:
          'Accepting confirms the order with the vehicle and driver you assigned.',
      confirmLabel: 'Accept order',
    );
    if (confirmed && context.mounted) {
      await _transition(context, ref, action: 'accept');
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showAppBottomSheet<String>(
      context,
      builder: (_) => const _RejectSheet(),
    );
    if (reason == null || !context.mounted) return;
    if (reason.length < 2) {
      showAppSnack(
        context,
        'Enter a rejection reason.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    await _transition(context, ref, action: 'reject', reason: reason);
  }

  Future<void> _verifyDelivery(BuildContext context, WidgetRef ref) async {
    final request = await showAppBottomSheet<_VerifyRequest>(
      context,
      builder: (_) => const _VerifySheet(),
    );
    if (request == null) return;
    if (!context.mounted || _saving) {
      unawaited(discardTemporaryPhotoFile(request.photo?.path));
      return;
    }
    setState(() => _saving = true);
    try {
      final photo = request.photo;
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
            otp: request.otp,
            proofPath: proofPath,
          );
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
      if (context.mounted) {
        Navigator.pop(context);
        showAppSnack(
          context,
          'Delivery verified successfully.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Delivery verification failed: $error',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      unawaited(discardTemporaryPhotoFile(request.photo?.path));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAssignmentRequired(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Assignment required',
        message:
            'An active, approved vehicle and driver are required before accepting this order.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Yes or no in a bottom sheet. Resolves to true only when the confirm button
/// is pressed.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showAppBottomSheet<bool>(
    context,
    builder: (sheetContext) => Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(message, style: Theme.of(sheetContext).textTheme.bodyLarge),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Not now',
                  onPressed: () => Navigator.pop(sheetContext, false),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: SlideToConfirm(
                  label: confirmLabel.toLowerCase(),
                  onConfirmed: () => Navigator.pop(sheetContext, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Reason sheet for rejecting an order. Pops the trimmed reason, or null.
class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reject order', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          AppTextField(
            controller: _reason,
            label: 'Reason',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Keep',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Reject',
                  onPressed: () => Navigator.pop(context, _reason.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the verify sheet returns: the six-digit OTP and an optional photo.
class _VerifyRequest {
  const _VerifyRequest({required this.otp, this.photo});

  final String otp;
  final XFile? photo;
}

class _VerifySheet extends StatefulWidget {
  const _VerifySheet();

  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  final _otp = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _photo;
  bool _submitted = false;

  @override
  void dispose() {
    _otp.dispose();
    // A photo that was never submitted is removed with the sheet.
    if (!_submitted) unawaited(discardTemporaryPhotoFile(_photo?.path));
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        requestFullMetadata: pickerRequestsFullMetadata,
      );
      if (image != null && mounted) setState(() => _photo = image);
    } catch (error) {
      if (mounted) {
        setState(() => _photo = null);
        showAppSnack(
          context,
          'Camera unavailable: $error',
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _submitted = true;
    Navigator.pop(
      context,
      _VerifyRequest(otp: _otp.text.trim(), photo: _photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verify delivery', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            AppTextField(
              controller: _otp,
              label: 'Six-digit delivery OTP',
              keyboardType: TextInputType.number,
              maxLength: 6,
              validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                  ? null
                  : 'Enter the six-digit OTP.',
            ),
            const SizedBox(height: AppSpace.sm),
            SecondaryButton(
              label: _photo == null
                  ? 'Capture delivery photo (optional)'
                  : 'Retake delivery photo',
              icon: Icons.camera_alt_outlined,
              onPressed: _capture,
            ),
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: Text(
                  _photo!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
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
                  child: PrimaryButton(label: 'Verify', onPressed: _submit),
                ),
              ],
            ),
          ],
        ),
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
