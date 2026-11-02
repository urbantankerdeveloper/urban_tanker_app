import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
import '../app/pin_pad.dart';
import '../services/mpin_service.dart';

/// Creates or changes the MPIN. The user enters it twice, then can also turn on
/// fingerprint unlock if the device supports it.
class UnlockSetupScreen extends StatefulWidget {
  const UnlockSetupScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<UnlockSetupScreen> createState() => _UnlockSetupScreenState();
}

class _UnlockSetupScreenState extends State<UnlockSetupScreen> {
  String _pin = '';
  String? _firstPin;
  String? _error;
  bool _saving = false;

  bool get _confirming => _firstPin != null;

  void _addDigit(String digit) {
    if (_saving || _pin.length >= MpinService.maxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _continue() async {
    if (_saving || _pin.length < MpinService.minLength) return;
    if (!_confirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _pin = '';
        _error = "The MPINs don't match. Start again.";
      });
      return;
    }
    setState(() => _saving = true);
    await widget.controller.setMpin(_pin);
    if (!mounted) return;
    await _offerFingerprint();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _offerFingerprint() async {
    final auth = widget.controller.biometricAuth;
    if (!await auth.canAuthenticate() || !mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.fingerprint),
        title: const Text('Also unlock with fingerprint?'),
        content: const Text(
          'You can still use your MPIN. You can change this later in Security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final authenticated = await auth.authenticate(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canContinue = _pin.length >= MpinService.minLength && !_saving;
    return Scaffold(
      appBar: AppBar(
        title: Text(_confirming ? 'Confirm your MPIN' : 'Create your MPIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppPageInsets.status,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _confirming
                        ? 'Enter the same MPIN again.'
                        : 'Choose a ${MpinService.minLength} to '
                            '${MpinService.maxLength} digit MPIN. You will use it to unlock the app.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PinPad(
                    entered: _pin.length,
                    canSubmit: canContinue,
                    onDigit: _addDigit,
                    onDelete: _deleteDigit,
                    onSubmit: _continue,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: canContinue ? _continue : null,
                    child: Text(_confirming ? 'Save MPIN' : 'Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
