import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/page_components.dart';
import '../../models/vendor.dart';
import '../../services/api_client.dart';
import '../../services/photo_permissions.dart';
import '../../services/temporary_photo.dart';
import '../../services/friendly_error.dart';
import 'vendor_shared.dart';

class VendorFleetScreen extends ConsumerWidget {
  const VendorFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(vendorDashboardProvider);
    return dashboard.when(
      loading: () => const AppStateView.loading(),
      error: (error, _) => VendorError(
        message: friendlyError(error),
        retry: () => ref.invalidate(vendorDashboardProvider),
      ),
      data: (value) {
        // Each entry builds one fixed widget or one vehicle/driver row, so the
        // rows are only created when they scroll into view.
        final entries = <Widget Function()>[
          () => Row(
                children: [
                  const Expanded(child: Text('Vehicles')),
                  TextButton(
                    onPressed: () => _addVehicle(context, ref),
                    child: const Text('Add'),
                  ),
                ],
              ),
          for (final vehicle in value.vehicles)
            () => ListTile(
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
          () => const SizedBox(height: 16),
          () => Row(
                children: [
                  const Expanded(child: Text('Drivers')),
                  TextButton(
                    onPressed: () => _addDriver(context, ref),
                    child: const Text('Add'),
                  ),
                ],
              ),
          for (final driver in value.drivers)
            () => ListTile(
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
                            SnackBar(
                                content: Text('Attendance failed: $error')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'present', child: Text('Mark present')),
                      PopupMenuItem(
                          value: 'absent', child: Text('Mark absent')),
                      PopupMenuItem(
                        value: 'on_leave',
                        child: Text('Mark on leave'),
                      ),
                    ],
                  ),
                ),
          () => const SizedBox(height: 16),
          () => const _VendorAvailabilityCard(),
          () => _VendorComplaintCard(orders: value.orders),
          () => const _VendorDocumentCard(),
          () => _VendorAttendanceCard(drivers: value.drivers),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(vendorDashboardProvider);
            ref.invalidate(vendorAttendanceProvider);
          },
          child: ListView.builder(
            padding: AppPageInsets.standard,
            itemCount: entries.length,
            itemBuilder: (_, index) => entries[index](),
          ),
        );
      },
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
    var submitting = false;
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
              onPressed: submitting
                  ? null
                  : () async {
                      setState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        await submit();
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (value) {
                        setState(() {
                          submitting = false;
                          error = friendlyError(value);
                        });
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
              subtitle: Text(friendlyError(error)),
              trailing: IconButton(
                tooltip: 'Refresh',
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
                              setDialogState(() => error = friendlyError(value));
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
                              requestFullMetadata: pickerRequestsFullMetadata,
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
                              setDialogState(() => error = friendlyError(value));
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
                        // The upload and the record are saved, so the local copy is no longer needed.
                        await discardTemporaryPhotoFile(cameraPhoto?.path);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (value) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = friendlyError(value);
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
    // A captured photo that was not saved is removed with the dialog.
    unawaited(discardTemporaryPhotoFile(cameraPhoto?.path));
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
        subtitle: Text(formatDate(selectedDate)),
        children: [
          ListTile(
            title: const Text('Select date'),
            trailing: IconButton(
              tooltip: 'Choose date',
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
            future: ref.watch(vendorAttendanceProvider(selectedDate).future),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListTile(
                  title: const Text('Could not load this section'),
                  subtitle: Text(friendlyError(snapshot.error!)),
                );
              }
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

class _VendorRecordsCard extends ConsumerStatefulWidget {
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
  ConsumerState<_VendorRecordsCard> createState() => _VendorRecordsCardState();
}

class _VendorRecordsCardState extends ConsumerState<_VendorRecordsCard> {
  // Loaded once per mounted card so rebuilds do not call the API again.
  late final Future<List<Map<String, dynamic>>> _records =
      widget.loader(ref.read(apiProvider));

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(widget.icon),
        title: Text(widget.title),
        trailing: widget.action == null
            ? null
            : IconButton(
              tooltip: 'Add',
                onPressed: widget.action,
                icon: const Icon(Icons.add),
              ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _records,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('Could not load ${widget.title}'),
                  subtitle: Text(friendlyError(snapshot.error!)),
                );
              }
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return ListTile(title: Text(widget.emptyMessage));
              }
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
                        onTap: widget.onTap == null
                            ? null
                            : () => widget.onTap!(record),
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
                if (context.mounted) setState(() => error = friendlyError(value));
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

void _invalidateVendorFleet(WidgetRef ref) {
  ref
    ..invalidate(vendorDashboardProvider)
    ..invalidate(vendorVehiclesProvider)
    ..invalidate(vendorDriversProvider);
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
