import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/vendor.dart';
import '../../../services/friendly_error.dart';

/// Shows an add or edit form in a bottom sheet. Resolves to true once the
/// record is saved. When [requireAll] is set, every field must have text.
Future<bool> showRecordSheet(
  BuildContext context, {
  required String title,
  required List<(String, TextEditingController)> fields,
  required Future<void> Function() submit,
  Widget? extra,
  bool requireAll = false,
}) async {
  final saved = await showAppBottomSheet<bool>(
    context,
    builder: (_) => _RecordSheet(
      title: title,
      fields: fields,
      submit: submit,
      extra: extra,
      requireAll: requireAll,
    ),
  );
  return saved == true;
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.title,
    required this.fields,
    required this.submit,
    required this.requireAll,
    this.extra,
  });

  final String title;
  final List<(String, TextEditingController)> fields;
  final Future<void> Function() submit;
  final Widget? extra;
  final bool requireAll;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  String? _error;
  bool _submitting = false;

  Future<void> _save() async {
    if (widget.requireAll &&
        widget.fields.any((field) => field.$2.text.trim().isEmpty)) {
      setState(() => _error = 'Complete all fields.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit();
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyError(value);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            if (widget.extra != null) ...[
              widget.extra!,
              const SizedBox(height: AppSpace.md),
            ],
            for (final field in widget.fields) ...[
              AppTextField(
                controller: field.$2,
                label: field.$1,
                maxLines: field.$1 == 'Message' ? 4 : 1,
              ),
              const SizedBox(height: AppSpace.md),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: colors.danger.fg),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Save',
                    loading: _submitting,
                    onPressed: _submitting ? null : _save,
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

/// Refreshes everything that depends on the vendor's fleet.
void invalidateVendorFleet(WidgetRef ref) {
  ref
    ..invalidate(vendorDashboardProvider)
    ..invalidate(vendorVehiclesProvider)
    ..invalidate(vendorDriversProvider);
}

Future<void> setVehicleActive(
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
    invalidateVendorFleet(ref);
    if (context.mounted) {
      showAppSnack(
        context,
        '${vehicle.registrationNumber} ${active ? 'activated' : 'deactivated'}.',
        variant: AppSnackVariant.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Vehicle update failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }
}

Future<void> setDriverAttendance(
  BuildContext context,
  WidgetRef ref,
  VendorDriver driver,
  String status,
) async {
  try {
    await ref.read(appControllerProvider).api.updateVendorAttendance(
          driverId: driver.id,
          status: status,
        );
    if (context.mounted) {
      showAppSnack(
        context,
        '${driver.name}: ${status.replaceAll('_', ' ')}',
        variant: AppSnackVariant.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Attendance failed: $error',
        variant: AppSnackVariant.error,
      );
    }
  }
}

Future<void> addVehicle(BuildContext context, WidgetRef ref) async {
  final registration = TextEditingController();
  final capacity = TextEditingController();
  final saved = await showRecordSheet(
    context,
    title: 'Add vehicle',
    fields: [
      ('Registration number', registration),
      ('Capacity litres', capacity),
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
  if (saved && context.mounted) invalidateVendorFleet(ref);
}

Future<void> addDriver(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final licence = TextEditingController();
  final saved = await showRecordSheet(
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
  if (saved && context.mounted) invalidateVendorFleet(ref);
}

Future<void> editVehicle(
  BuildContext context,
  WidgetRef ref,
  VendorVehicle vehicle,
) async {
  final registration = TextEditingController(text: vehicle.registrationNumber);
  final capacity = TextEditingController(text: '${vehicle.capacityLitres}');
  final saved = await showRecordSheet(
    context,
    title: 'Edit vehicle',
    fields: [
      ('Registration number', registration),
      ('Capacity litres', capacity),
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
  if (saved && context.mounted) invalidateVendorFleet(ref);
}

Future<void> editDriver(
  BuildContext context,
  WidgetRef ref,
  VendorDriver driver,
) async {
  final name = TextEditingController(text: driver.name);
  final mobile = TextEditingController(text: driver.mobile);
  final licence = TextEditingController();
  final saved = await showRecordSheet(
    context,
    title: 'Edit driver',
    fields: [
      ('Name', name),
      ('10-digit mobile', mobile),
      ('Licence number (optional)', licence),
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
  if (saved && context.mounted) invalidateVendorFleet(ref);
}
