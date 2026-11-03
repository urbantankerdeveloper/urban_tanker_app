import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../unlock_setup_screen.dart';

/// After the first sign-in, offers to set up an MPIN (and fingerprint).
Future<void> offerUnlockSetup(
  BuildContext context,
  AppController controller,
) async {
  if (!controller.pendingUnlockSetup) return;
  await controller.markBiometricPromptOffered();
  if (!context.mounted) return;
  final setUp = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('Set up quick unlock?'),
      content: const Text(
        'Create an MPIN so you can unlock the app without your password. You can also use your fingerprint if your device supports it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Set up'),
        ),
      ],
    ),
  );
  if (setUp != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UnlockSetupScreen(controller: controller),
    ),
  );
}
