import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    if (!enable) {
      await widget.controller.setBiometricEnabled(false);
      return;
    }
    try {
      final authenticated = await widget.controller.biometricAuth.authenticate(
        'Confirm fingerprint unlock for Urban Tanker',
      );
      if (authenticated) {
        await widget.controller.setBiometricEnabled(true);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Fingerprint unlock was not enabled.')),
        );
      }
    } on PlatformException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Fingerprint unlock could not be enabled.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmTurnOffMpin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off MPIN?'),
        content: const Text(
          'The app will no longer ask for an MPIN when you reopen it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.disableMpin();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: AppPageInsets.standard,
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('MPIN'),
                    subtitle: Text(
                      controller.mpinEnabled
                          ? 'On. Use it to unlock the app.'
                          : 'Not set. Create a 4 to 6 digit MPIN.',
                    ),
                  ),
                  ListTile(
                    title: Text(
                      controller.mpinEnabled ? 'Change MPIN' : 'Set up MPIN',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UnlockSetupScreen(controller: controller),
                      ),
                    ),
                  ),
                  if (controller.mpinEnabled)
                    ListTile(
                      title: const Text('Turn off MPIN'),
                      onTap: _confirmTurnOffMpin,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: FutureBuilder<bool>(
                future: _fingerprintAvailable,
                builder: (context, snapshot) {
                  final available = snapshot.data ?? false;
                  return SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Fingerprint unlock'),
                    subtitle: Text(
                      available
                          ? 'Unlock with your fingerprint or device biometric.'
                          : 'No fingerprint or device biometric is set up on this device.',
                    ),
                    value: controller.biometricEnabled,
                    onChanged: available ? _setFingerprint : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The app locks when you leave it. Turn on an MPIN or fingerprint to unlock it again.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
