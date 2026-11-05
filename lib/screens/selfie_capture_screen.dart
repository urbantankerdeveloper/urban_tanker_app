import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
import '../services/photo_permissions.dart';
import '../services/secure_screen.dart';
import '../services/temporary_photo.dart';
import '../services/friendly_error.dart';

/// Longest side of the captured photo. Smaller photos upload faster and decode
/// with less memory.
const _photoSide = 720;

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
  void initState() {
    super.initState();
    unawaited(SecureScreen.enable());
  }

  @override
  void dispose() {
    unawaited(SecureScreen.disable());
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

  /// The identity selfie is taken with the camera only. Gallery photos are not accepted.
  Future<void> _pick() async {
    try {
      final access = await requestCameraAccess();
      if (access != PhotoAccess.granted) {
        if (mounted) {
          setState(() {
            _error = photoAccessMessage(camera: true, access: access);
            _settingsNeeded = access == PhotoAccess.permanentlyDenied;
          });
        }
        return;
      }
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: _photoSide.toDouble(),
        maxHeight: _photoSide.toDouble(),
        requestFullMetadata: pickerRequestsFullMetadata,
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
          _error = 'The camera could not be opened. Try again.';
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
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final photo = _photo;
    final onHero = colors.onHero;
    return Scaffold(
      backgroundColor: AppPalette.darkScaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onHero,
        title: const Text('Take your selfie'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: onHero),
            onPressed: _saving ? null : () => widget.controller.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            DecoratedBox(
              decoration: BoxDecoration(gradient: colors.heroGradient),
              child: Center(
                child: Icon(
                  Icons.face_retouching_natural,
                  size: 96,
                  color: onHero.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              cacheWidth: _photoSide,
            ),
          if (photo == null) const OvalGuide(),
          SafeArea(
            child: Padding(
              padding: AppPageInsets.card,
              child: Align(
                alignment: Alignment.topCenter,
                child: _ScrimCard(
                  child: Text(
                    'We need a quick selfie to finish creating your account. '
                    'It is stored privately and is only visible to Urban Tanker admins for verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: onHero, height: 1.4),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: AppPageInsets.card,
                child: _ScrimCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorLine(message: _error!),
                        if (_settingsNeeded)
                          TextButton(
                            style:
                                TextButton.styleFrom(foregroundColor: onHero),
                            onPressed: () => openAppSettings(),
                            child: const Text('Open settings'),
                          ),
                        const SizedBox(height: AppSpace.md),
                      ],
                      if (photo == null)
                        PrimaryButton(
                          label: 'Open front camera',
                          icon: Icons.camera_alt_outlined,
                          onPressed: _saving ? null : _pick,
                        )
                      else ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: onHero,
                            side: BorderSide(
                                color: onHero.withValues(alpha: 0.5)),
                            minimumSize: const Size(64, AppSize.buttonHeight),
                          ),
                          onPressed: _saving ? null : _pick,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Retake with camera'),
                        ),
                        const SizedBox(height: AppSpace.md),
                        PrimaryButton(
                          label: 'Save and continue',
                          loading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark translucent card so white text reads over the camera preview.
class _ScrimCard extends StatelessWidget {
  const _ScrimCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.colors.scrim),
        child: Padding(
          padding: AppPageInsets.card,
          child: child,
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.danger;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: tone.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: tone.fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
