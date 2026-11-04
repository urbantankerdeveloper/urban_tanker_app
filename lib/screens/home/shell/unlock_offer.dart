import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/design_system/design_system.dart';
import '../../unlock_setup_screen.dart';

/// After the first sign-in, offers to set up an MPIN (and fingerprint).
Future<void> offerUnlockSetup(
  BuildContext context,
  AppController controller,
) async {
  if (controller.pendingMpinReset) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnlockSetupScreen(
          controller: controller,
          isReset: true,
        ),
      ),
    );
    if (controller.pendingMpinReset) controller.dismissMpinReset();
    return;
  }
  if (!controller.pendingUnlockSetup) return;
  await controller.markBiometricPromptOffered();
  if (!context.mounted) return;
  final setUp = await showAppConfirmDialog(
    context,
    title: 'Set up quick unlock?',
    message:
        'Create an MPIN so you can unlock the app without your password. You can also use your fingerprint if your device supports it.',
    confirmLabel: 'Set up',
    cancelLabel: 'Not now',
  );
  if (!setUp || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UnlockSetupScreen(controller: controller),
    ),
  );
}
