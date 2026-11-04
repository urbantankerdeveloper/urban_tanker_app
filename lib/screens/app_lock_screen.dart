import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../core/design_system/design_system.dart';
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
  // Bumped on every rejected MPIN so the keypad shakes once per attempt.
  int _shakeSignal = 0;

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
      } else {
        _shakeSignal++;
        if (check.isLocked) {
          _error =
              'Too many wrong attempts. Sign in again with your phone number and OTP.';
        } else {
          final left = check.attemptsLeft;
          _error =
              'Incorrect MPIN. $left ${left == 1 ? 'attempt' : 'attempts'} left.';
        }
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
    final colors = context.colors;
    final theme = Theme.of(context);
    final mpinOn = controller.mpinEnabled;
    final fingerprintOn = controller.biometricEnabled;
    final busy = _checking || _authenticating;
    final onHero = colors.onHero;
    return Scaffold(
      // Transparent, so the blurred overlay shows the app underneath.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BlurredBrandOverlay(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(size: 72)),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        'Unlock Urban Tanker',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: onHero,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        mpinOn
                            ? fingerprintOn
                                ? 'Enter your MPIN or use your fingerprint.'
                                : 'Enter your MPIN to continue.'
                            : 'Verify your fingerprint to continue.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: onHero,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpace.lg),
                        _ErrorPill(message: _error!),
                      ],
                      const SizedBox(height: AppSpace.xl),
                      if (mpinOn)
                        PinPad(
                          entered: _pin.length,
                          canSubmit:
                              _pin.length >= MpinService.minLength && !busy,
                          onDigit: _addDigit,
                          onDelete: _deleteDigit,
                          onSubmit: () => unawaited(_submit()),
                          shakeSignal: _shakeSignal,
                          onDark: true,
                        ),
                      if (fingerprintOn) ...[
                        const SizedBox(height: AppSpace.lg),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: onHero,
                            side: BorderSide(
                              color: onHero.withValues(alpha: 0.5),
                            ),
                            minimumSize: const Size(64, AppSize.buttonHeight),
                          ),
                          onPressed: busy ? null : _unlockWithFingerprint,
                          icon: _authenticating
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: onHero,
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: const Text('Use fingerprint'),
                        ),
                      ],
                      const SizedBox(height: AppSpace.sm),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: onHero),
                        onPressed: busy ? null : controller.usePhoneOtpRecovery,
                        child: Text(
                          mpinOn
                              ? 'Forgot MPIN? Recover with phone OTP'
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
        ],
      ),
    );
  }
}

/// Error message in a tinted pill. Uses the danger tone, so it reads on the
/// dark lock overlay in both themes.
class _ErrorPill extends StatelessWidget {
  const _ErrorPill({required this.message});

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
          vertical: AppSpace.md,
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
