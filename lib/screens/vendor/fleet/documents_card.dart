import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../services/friendly_error.dart';
import '../../../services/photo_permissions.dart';
import '../../../services/temporary_photo.dart';
import 'fleet_forms.dart';
import 'records_card.dart';

/// Vendor documents. Each one can be resubmitted with a new file or photo.
class DocumentsCard extends ConsumerWidget {
  const DocumentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VendorRecordsCard(
      title: 'Documents',
      icon: Icons.description_outlined,
      loader: (api) => api.vendorDocuments(),
      emptyMessage: 'No documents submitted.',
      action: () => _openSheet(context, ref),
      onTap: (record) => _openSheet(context, ref, record),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? record,
  ]) async {
    final saved = await showAppBottomSheet<bool>(
      context,
      builder: (_) => _DocumentSheet(record: record),
    );
    if (saved == true && context.mounted) {
      invalidateVendorFleet(ref);
      showAppSnack(
        context,
        'Document uploaded and submitted.',
        variant: AppSnackVariant.success,
      );
    }
  }
}

/// Submit or resubmit a document: a type, a file or a camera photo, and an
/// optional expiry date. Pops true once the record is saved.
class _DocumentSheet extends ConsumerStatefulWidget {
  const _DocumentSheet({this.record});

  final Map<String, dynamic>? record;

  @override
  ConsumerState<_DocumentSheet> createState() => _DocumentSheetState();
}

class _DocumentSheetState extends ConsumerState<_DocumentSheet> {
  late final TextEditingController _type = TextEditingController(
    text: (widget.record?['document_type'] ??
            widget.record?['documentType'] ??
            '')
        .toString(),
  );
  late final TextEditingController _objectKey = TextEditingController(
    text: (widget.record?['object_key'] ?? widget.record?['objectKey'] ?? '')
        .toString(),
  );
  late final TextEditingController _expiry = TextEditingController(
    text: (widget.record?['expires_on'] ?? widget.record?['expiresOn'] ?? '')
        .toString(),
  );
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  XFile? _cameraPhoto;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _type.dispose();
    _objectKey.dispose();
    _expiry.dispose();
    // A captured photo that was not saved is removed with the sheet.
    if (!_saved) unawaited(discardTemporaryPhotoFile(_cameraPhoto?.path));
    super.dispose();
  }

  Future<void> _chooseFile() async {
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
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedFile = file;
          _selectedFileBytes = bytes;
          _cameraPhoto = null;
          _objectKey.text = file.name;
          _error = null;
        });
      }
    } catch (value) {
      if (mounted) setState(() => _error = friendlyError(value));
    }
  }

  Future<void> _scan() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        requestFullMetadata: pickerRequestsFullMetadata,
      );
      if (photo != null && mounted) {
        setState(() {
          _cameraPhoto = photo;
          _selectedFile = null;
          _selectedFileBytes = null;
          _objectKey.text = photo.name;
          _error = null;
        });
      }
    } catch (value) {
      if (mounted) setState(() => _error = friendlyError(value));
    }
  }

  Future<void> _submit() async {
    final expiryText = _expiry.text.trim();
    if (_type.text.trim().isEmpty) {
      setState(() => _error = 'Enter a document type.');
      return;
    }
    // A new document needs a file or a photo. A resubmission can keep the old one.
    if (widget.record == null &&
        _selectedFile == null &&
        _cameraPhoto == null) {
      setState(() => _error = 'Choose a file or capture a photo.');
      return;
    }
    if (expiryText.isNotEmpty &&
        (DateTime.tryParse(expiryText) == null ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryText))) {
      setState(() => _error = 'Enter expiry as YYYY-MM-DD.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(appControllerProvider).api;
      var path = _objectKey.text.trim();
      if (_selectedFile != null) {
        final bytes = _selectedFileBytes;
        if (bytes == null) {
          throw const FormatException(
            'Could not read the selected document.',
          );
        }
        path = await api.uploadVendorFile(
          fileName: _selectedFile!.name,
          contentType: _vendorDocumentContentType(_selectedFile!.extension),
          bytes: bytes,
        );
      } else if (_cameraPhoto != null) {
        path = await api.uploadVendorFile(
          fileName: _cameraPhoto!.name,
          contentType: 'image/jpeg',
          bytes: await _cameraPhoto!.readAsBytes(),
        );
      }
      final id = widget.record?['id']?.toString();
      if (id == null || id.isEmpty) {
        await api.createVendorDocument(
          documentType: _type.text.trim(),
          objectKey: path,
          expiresOn: expiryText.isEmpty ? null : expiryText,
        );
      } else {
        await api.updateVendorDocument(
          id: id,
          documentType: _type.text.trim(),
          objectKey: path,
          expiresOn: expiryText.isEmpty ? null : expiryText,
        );
      }
      // The upload and the record are saved, so the local copy is no longer needed.
      await discardTemporaryPhotoFile(_cameraPhoto?.path);
      _saved = true;
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(value);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.record == null ? 'Submit document' : 'Resubmit document',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            AppTextField(controller: _type, label: 'Document type'),
            const SizedBox(height: AppSpace.md),
            SecondaryButton(
              label: 'Choose a document',
              icon: Icons.attach_file,
              onPressed: _saving ? null : _chooseFile,
            ),
            const SizedBox(height: AppSpace.sm),
            SecondaryButton(
              label: 'Scan with camera',
              icon: Icons.camera_alt_outlined,
              onPressed: _saving ? null : _scan,
            ),
            if (_objectKey.text.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                'Selected: ${_objectKey.text}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpace.md),
            AppTextField(
              controller: _expiry,
              label: 'Expiry date (optional, YYYY-MM-DD)',
              keyboardType: TextInputType.datetime,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(_error!, style: TextStyle(color: colors.danger.fg)),
            ],
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Upload and submit',
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
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
