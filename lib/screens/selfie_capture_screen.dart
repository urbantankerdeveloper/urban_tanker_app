import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/app_controller.dart';
import '../services/photo_permissions.dart';
import '../services/temporary_photo.dart';

class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  XFile? _photo;
  bool _saving = false;
  String? _error;
  bool _settingsNeeded = false;

  @override
  void dispose() {
    unawaited(_discardPhoto(_photo));
    super.dispose();
  }

  Future<void> _discardPhoto(XFile? photo) async {
    if (photo == null) return;
    try {
      final temporaryRoot = (await getTemporaryDirectory()).path;
      await deleteTemporaryPhoto(photo.path, temporaryRoot: temporaryRoot);
    } catch (_) {
      // Cleanup is best effort, so a failure here should not block the user.
    }
  }

  Future<void> _pick(ImageSource source) async {
    final camera = source == ImageSource.camera;
    try {
      final access =
          camera ? await requestCameraAccess() : await requestPhotoAccess();
      if (access != PhotoAccess.granted) {
        if (mounted) {
          setState(() {
            _error = photoAccessMessage(camera: camera, access: access);
            _settingsNeeded = access == PhotoAccess.permanentlyDenied;
          });
        }
        return;
      }
      final photo = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (photo == null || !mounted) return;
      final previous = _photo;
      setState(() {
        _photo = photo;
        _error = null;
        _settingsNeeded = false;
      });
      await _discardPhoto(previous);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = camera
              ? 'The camera could not be opened. Try again.'
              : 'The photo library could not be opened. Try again.';
          _settingsNeeded = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await photo.readAsBytes();
      await widget.controller.api.uploadCustomerSelfie(bytes: bytes);
      await _discardPhoto(photo);
      _photo = null;
      if (mounted) widget.controller.markSelfieCaptured();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = _photo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take your selfie'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => widget.controller.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'We need a quick selfie to finish creating your account. '
                'It is stored privately and is only visible to Urban Tanker admins for verification.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: photo == null
                        ? Center(
                            child: Icon(
                              Icons.face_retouching_natural,
                              size: 96,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.file(File(photo.path), fit: BoxFit.cover),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                if (_settingsNeeded)
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open settings'),
                  ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  photo == null ? 'Open front camera' : 'Retake with camera',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: photo == null || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
