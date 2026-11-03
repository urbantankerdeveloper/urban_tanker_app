import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
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
  int _shakeSignal = 0;

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
        _shakeSignal++;
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
    final enable = await showAppConfirmDialog(
      context,
      title: 'Also unlock with fingerprint?',
      message:
          'You can still use your MPIN. You can change this later in Security.',
      confirmLabel: 'Enable',
      cancelLabel: 'Not now',
    );
    if (!enable || !mounted) return;
    try {
      final authenticated = await auth.authenticate(
        'Confirm fingerprint unlock for Urban Tanker',
      );
      if (!mounted) return;
      if (authenticated) {
        await widget.controller.setBiometricEnabled(true);
      } else {
        showAppSnack(
          context,
          'Fingerprint unlock was not enabled.',
        );
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canContinue = _pin.length >= MpinService.minLength && !_saving;
    return AppScaffold(
      title: _confirming ? 'Confirm your MPIN' : 'Create your MPIN',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Center(
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
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.danger.fg),
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                PinPad(
                  entered: _pin.length,
                  canSubmit: canContinue,
                  onDigit: _addDigit,
                  onDelete: _deleteDigit,
                  onSubmit: _continue,
                  shakeSignal: _shakeSignal,
                ),
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: _confirming ? 'Save MPIN' : 'Continue',
                  loading: _saving,
                  onPressed: canContinue ? _continue : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
