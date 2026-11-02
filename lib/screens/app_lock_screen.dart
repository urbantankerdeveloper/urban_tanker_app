import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';
import '../app/pin_pad.dart';
import '../services/mpin_service.dart';

/// Covers the app after it is locked (on resume or launch). Unlocks with the
/// MPIN, the fingerprint, or either one.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _pin = '';
  bool _checking = false;
  bool _authenticating = false;
  String? _error;
  bool _attemptedAutomatically = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attemptedAutomatically) return;
    _attemptedAutomatically = true;
    if (widget.controller.biometricEnabled) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _unlockWithFingerprint());
    }
  }

  void _addDigit(String digit) {
    if (_checking || _pin.length >= MpinService.maxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == MpinService.maxLength) unawaited(_submit());
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_checking || _pin.length < MpinService.minLength) return;
    final pin = _pin;
    setState(() => _checking = true);
    final check = await widget.controller.unlockWithMpin(pin);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _pin = '';
      if (check.isAccepted) {
        _error = null;
      } else if (check.isLocked) {
        _error =
            'Too many wrong attempts. Sign in again with your phone number and OTP.';
      } else {
        final left = check.attemptsLeft;
        _error = 'Incorrect MPIN. $left ${left == 1 ? 'attempt' : 'attempts'} left.';
      }
    });
  }

  Future<void> _unlockWithFingerprint() async {
    if (_authenticating || !widget.controller.sessionLocked) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await widget.controller.biometricAuth.authenticate(
        'Unlock your Urban Tanker account',
      );
      if (!mounted) return;
      if (authenticated) {
        widget.controller.unlockSession();
      } else {
        setState(() => _error = 'Biometric verification was not completed.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.message ?? 'Biometric verification is unavailable.');
      }
    } on Exception {
      if (mounted) {
        setState(() => _error =
            'Biometric verification failed. Try again, or use your MPIN.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final mpinOn = controller.mpinEnabled;
    final fingerprintOn = controller.biometricEnabled;
    final busy = _checking || _authenticating;
    return Scaffold(
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
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock Urban Tanker',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mpinOn
                        ? fingerprintOn
                            ? 'Enter your MPIN or use your fingerprint.'
                            : 'Enter your MPIN to continue.'
                        : 'Verify your fingerprint to continue.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (mpinOn)
                    PinPad(
                      entered: _pin.length,
                      canSubmit: _pin.length >= MpinService.minLength && !busy,
                      onDigit: _addDigit,
                      onDelete: _deleteDigit,
                      onSubmit: () => unawaited(_submit()),
                    ),
                  if (fingerprintOn) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _unlockWithFingerprint,
                      icon: _authenticating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: const Text('Use fingerprint'),
                    ),
                  ],
                  TextButton(
                    onPressed: busy ? null : controller.usePhoneOtpRecovery,
                    child: Text(
                      mpinOn
                          ? 'Forgot MPIN? Sign out and use phone number and OTP'
                          : 'Sign out and use phone number and OTP',
                      textAlign: TextAlign.center,
                    ),
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
