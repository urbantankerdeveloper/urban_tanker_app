import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
import 'unlock_setup_screen.dart';

/// Turns the MPIN and fingerprint unlock on or off. Shown to every role.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late final Future<bool> _fingerprintAvailable =
      widget.controller.biometricAuth.canAuthenticate();

  Future<void> _setFingerprint(bool enable) async {
    if (!enable) {
      await widget.controller.setBiometricEnabled(false);
      return;
    }
    try {
      final authenticated = await widget.controller.biometricAuth.authenticate(
        'Confirm fingerprint unlock for Urban Tanker',
      );
      if (!mounted) return;
      if (authenticated) {
        await widget.controller.setBiometricEnabled(true);
      } else {
        showAppSnack(context, 'Fingerprint unlock was not enabled.');
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        error.message ?? 'Fingerprint unlock could not be enabled.',
        variant: AppSnackVariant.error,
      );
    }
  }

  Future<void> _confirmTurnOffMpin() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Turn off MPIN?',
      message: 'The app will no longer ask for an MPIN when you reopen it.',
      confirmLabel: 'Turn off',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed) await widget.controller.disableMpin();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Security',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Column(
                children: [
                  AppListRow(
                    leading: const Icon(Icons.pin_outlined),
                    title: 'MPIN',
                    subtitle: controller.mpinEnabled
                        ? 'On. Use it to unlock the app.'
                        : 'Not set. Create a 4 to 6 digit MPIN.',
                  ),
                  const Divider(height: 1),
                  AppListRow(
                    title:
                        controller.mpinEnabled ? 'Change MPIN' : 'Set up MPIN',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            UnlockSetupScreen(controller: controller),
                      ),
                    ),
                  ),
                  if (controller.mpinEnabled) ...[
                    const Divider(height: 1),
                    AppListRow(
                      title: 'Turn off MPIN',
                      onTap: _confirmTurnOffMpin,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: FutureBuilder<bool>(
                future: _fingerprintAvailable,
                builder: (context, snapshot) {
                  final available = snapshot.data ?? false;
                  return AppListRow(
                    leading: const Icon(Icons.fingerprint),
                    title: 'Fingerprint unlock',
                    subtitle: available
                        ? 'Unlock with your fingerprint or device biometric.'
                        : 'No fingerprint or device biometric is set up on this device.',
                    trailing: Switch(
                      value: controller.biometricEnabled,
                      onChanged: available ? _setFingerprint : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              'The app locks when you leave it. Turn on an MPIN or fingerprint to unlock it again.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
